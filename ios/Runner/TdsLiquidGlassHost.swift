import CoreText
import Flutter
import UIKit

/// Host-side implementation of the opt-in TDS adapter. Uses public UIKit APIs
/// so the installed OS owns the material, lens, press/drag feedback and a11y.
final class TdsLiquidGlassHost {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "tds/liquid_glass/capabilities", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "available" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 26.0, *) { result(true) } else { result(false) }
    }
    registrar.register(GlassFactory(registrar: registrar), withId: "tds/liquid_glass")
  }
}

private final class GlassFactory: NSObject, FlutterPlatformViewFactory {
  let registrar: FlutterPluginRegistrar
  init(registrar: FlutterPluginRegistrar) { self.registrar = registrar }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    if #available(iOS 26.0, *) {
      return GlassControl(
        frame: frame, id: viewId,
        data: args as? [String: Any] ?? [:], registrar: registrar)
    }
    return UnavailableGlassView()
  }
}

private final class UnavailableGlassView: NSObject, FlutterPlatformView {
  func view() -> UIView { UIView() }
}

@available(iOS 26.0, *)
private final class GlassControl: NSObject, FlutterPlatformView, UITabBarControllerDelegate {
  private let container: GlassContainer
  private let channel: FlutterMethodChannel
  private let registrar: FlutterPluginRegistrar
  private var controller: UITabBarController?
  private var button: UIButton?
  private let dot = UIView()
  private var selected = 0
  private var selectionPending = false
  private var labels: [String] = []

  init(frame: CGRect, id: Int64, data: [String: Any], registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    container = GlassContainer(frame: frame)
    channel = FlutterMethodChannel(
      name: "tds/liquid_glass/\(id)", binaryMessenger: registrar.messenger())
    super.init()
    container.backgroundColor = .clear
    container.overrideUserInterfaceStyle = .light
    if data["kind"] as? String == "tabs" {
      let tabs = UITabBarController()
      tabs.mode = .tabBar
      tabs.tabBarMinimizeBehavior = .never
      tabs.delegate = self
      tabs.view.backgroundColor = .clear
      tabs.view.isOpaque = false
      controller = tabs
      container.embeddedController = tabs
      container.addSubview(tabs.view)
    } else {
      let control = UIButton(configuration: .glass())
      control.configuration?.cornerStyle = .capsule
      control.accessibilityIdentifier = "tds-glass-notifications"
      control.addTarget(self, action: #selector(pressed), for: .touchUpInside)
      button = control
      container.content = control
      container.addSubview(control)
      dot.backgroundColor = .systemRed
      dot.layer.cornerRadius = 4
      dot.isUserInteractionEnabled = false
      dot.isAccessibilityElement = false
      control.addSubview(dot)
      dot.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        dot.widthAnchor.constraint(equalToConstant: 8),
        dot.heightAnchor.constraint(equalToConstant: 8),
        dot.topAnchor.constraint(equalTo: control.topAnchor, constant: 7),
        dot.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -7),
      ])
    }
    update(data)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      guard call.method == "update", let data = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.update(data)
      result(nil)
    }
  }

  func view() -> UIView { container }

  private func update(_ data: [String: Any]) {
    let tint = color(data["tint"])
    if let button {
      button.configuration?.image = UIImage(systemName: data["symbol"] as? String ?? "bell")
      button.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
        pointSize: 21, weight: .regular)
      button.configuration?.baseForegroundColor = tint
      button.accessibilityLabel = data["label"] as? String
      dot.isHidden = (data["unread"] as? Int ?? 0) == 0
    }
    guard let controller, let items = data["items"] as? [[String: Any]], !items.isEmpty else {
      return
    }
    let nextLabels = items.map { $0["label"] as? String ?? "" }
    if labels != nextLabels {
      labels = nextLabels
      controller.tabs = items.enumerated().map { index, item in
        UITab(
          title: labels[index], image: UIImage(systemName: item["symbol"] as? String ?? "circle"),
          identifier: "tds-tab-\(index)"
        ) { _ in
          let content = UIViewController()
          content.view.backgroundColor = .clear
          return content
        }
      }
      if let asset = data["fontAsset"] as? String,
        let path = Bundle.main.path(forResource: registrar.lookupKey(forAsset: asset), ofType: nil)
      {
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: path) as CFURL, .process, nil)
        if let font = UIFont(name: "Paperlogy-5Medium", size: 10) {
          // Change typography only; leave the system material/selection intact.
          for tab in controller.tabs {
            tab.viewController?.tabBarItem.setTitleTextAttributes([.font: font], for: .normal)
            tab.viewController?.tabBarItem.setTitleTextAttributes([.font: font], for: .selected)
          }
        }
      }
    }
    for (index, item) in items.enumerated() {
      let count = item["badge"] as? Int ?? 0
      controller.tabs[index].badgeValue = count > 0 ? String(count) : nil
    }
    controller.tabBar.tintColor = tint
    selected = min(max(data["selected"] as? Int ?? 0, 0), items.count - 1)
    controller.selectedTab = controller.tabs[selected]
    container.setNeedsLayout()
  }

  func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool
  {
    guard let index = tabBarController.tabs.firstIndex(of: tab) else { return false }
    if index == selected { return true }
    guard !selectionPending else { return false }
    selectionPending = true
    channel.invokeMethod("select", arguments: index) { [weak self] accepted in
      guard let self else { return }
      self.selectionPending = false
      if accepted as? Bool == true {
        self.selected = index
        self.controller?.selectedTab = tab
      }
    }
    // The Flutter draft-save guard must complete before UIKit commits a tab.
    return false
  }

  @objc private func pressed() { channel.invokeMethod("press", arguments: nil) }

  private func color(_ value: Any?) -> UIColor {
    let argb = (value as? NSNumber)?.uint32Value ?? 0xff10_1010
    return UIColor(
      red: CGFloat((argb >> 16) & 255) / 255,
      green: CGFloat((argb >> 8) & 255) / 255,
      blue: CGFloat(argb & 255) / 255,
      alpha: CGFloat((argb >> 24) & 255) / 255)
  }

  deinit { channel.setMethodCallHandler(nil) }
}

private final class GlassContainer: UIView {
  var content: UIView?
  var embeddedController: UIViewController?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard let controller = embeddedController else { return }
    if window == nil {
      controller.willMove(toParent: nil)
      controller.removeFromParent()
    } else if controller.parent == nil {
      var responder: UIResponder? = superview
      while let next = responder {
        if let parent = next as? UIViewController {
          parent.addChild(controller)
          controller.didMove(toParent: parent)
          break
        }
        responder = next.next
      }
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    content?.frame = bounds.insetBy(dx: 2, dy: 2)
    embeddedController?.view.frame = bounds
  }
}
