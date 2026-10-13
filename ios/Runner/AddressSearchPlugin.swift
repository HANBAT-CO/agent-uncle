import Flutter
import UIKit
import WebKit

final class AddressSearchPlugin: NSObject {
  private let channel: FlutterMethodChannel
  private weak var activeController: AddressSearchViewController?
  private var pendingResult: FlutterResult?
  private var activeSessionID: Int = 0

  static func register(with registrar: FlutterPluginRegistrar) -> AddressSearchPlugin {
    AddressSearchPlugin(messenger: registrar.messenger())
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "agent_uncle/address_search",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "주소 검색을 사용할 수 없어요.", details: nil))
        return
      }
      self.handle(call, result: result)
    }
  }

  func dispose() {
    channel.setMethodCallHandler(nil)
    activeController?.cancelFromHost()
    if let result = pendingResult {
      pendingResult = nil
      activeController = nil
      result(nil)
    }
    activeSessionID += 1
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      switch call.method {
      case "searchKakaoPostcode":
        self.startSearch(result: result)
      case "cancelSearch":
        self.cancelSearch()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startSearch(result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(FlutterError(code: "busy", message: "주소 검색이 이미 진행 중이에요. 잠시 후 다시 시도해 주세요.", details: nil))
      return
    }
    guard let presenter = activePresenter() else {
      result(FlutterError(code: "unavailable", message: "주소 검색 화면을 열 수 없어요.", details: nil))
      return
    }

    activeSessionID += 1
    let sessionID = activeSessionID
    pendingResult = result

    let controller = AddressSearchViewController()
    controller.modalPresentationStyle = .pageSheet
    controller.onComplete = { [weak self] outcome in
      self?.finish(sessionID: sessionID, outcome: outcome)
    }
    activeController = controller
    presenter.present(controller, animated: true)
  }

  private func cancelSearch() {
    activeController?.cancelFromHost()
  }

  private func finish(sessionID: Int, outcome: AddressSearchOutcome) {
    guard sessionID == activeSessionID, let result = pendingResult else { return }
    pendingResult = nil
    activeController = nil

    switch outcome {
    case let .success(payload):
      result(payload)
    case .cancelled:
      result(nil)
    case let .failure(code, message):
      result(FlutterError(code: code, message: message, details: nil))
    }
  }

  private func activePresenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .sorted { score(for: $0.activationState) < score(for: $1.activationState) }

    for scene in scenes {
      let keyWindow = scene.windows.first(where: \.isKeyWindow)
      let candidateWindow = keyWindow ?? scene.windows.first(where: { !$0.isHidden })
      if let root = candidateWindow?.rootViewController {
        return topViewController(from: root)
      }
    }

    return nil
  }

  private func topViewController(from root: UIViewController) -> UIViewController {
    if let navigationController = root as? UINavigationController,
      let visibleViewController = navigationController.visibleViewController
    {
      return topViewController(from: visibleViewController)
    }
    if let tabBarController = root as? UITabBarController,
      let selectedViewController = tabBarController.selectedViewController
    {
      return topViewController(from: selectedViewController)
    }
    if let splitViewController = root as? UISplitViewController,
      let lastViewController = splitViewController.viewControllers.last
    {
      return topViewController(from: lastViewController)
    }
    if let presentedViewController = root.presentedViewController {
      return topViewController(from: presentedViewController)
    }
    return root
  }

  private func score(for activationState: UIScene.ActivationState) -> Int {
    switch activationState {
    case .foregroundActive:
      return 0
    case .foregroundInactive:
      return 1
    case .background:
      return 2
    case .unattached:
      return 3
    @unknown default:
      return 4
    }
  }
}

private enum AddressSearchOutcome {
  case success([String: Any])
  case cancelled
  case failure(code: String, message: String)
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  weak var delegate: WKScriptMessageHandler?

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    delegate?.userContentController(userContentController, didReceive: message)
  }
}

private final class AddressSearchViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler,
  UIAdaptivePresentationControllerDelegate
{
  private let bridgeName = "addressSearch"
  private let loadTimeoutInterval: TimeInterval = 15
  private let messageHandler = WeakScriptMessageHandler()
  private let contentController = WKUserContentController()
  private var loadTimeoutWorkItem: DispatchWorkItem?
  private var hasCompleted = false

  var onComplete: ((AddressSearchOutcome) -> Void)?

  private lazy var webView: WKWebView = {
    messageHandler.delegate = self
    contentController.add(messageHandler, name: bridgeName)

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController

    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = self
    view.allowsBackForwardNavigationGestures = false
    view.scrollView.contentInsetAdjustmentBehavior = .never
    return view
  }()

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    tearDownWebView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    view.addSubview(webView)
    webView.translatesAutoresizingMaskIntoConstraints = false

    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: guide.topAnchor),
      webView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
    ])

    scheduleLoadTimeout()

    guard let baseURL = URL(string: "https://postcode.map.kakao.com/") else {
      completeIfNeeded(.failure(code: "unavailable", message: "주소 검색 화면을 열지 못했어요. 다시 시도해 주세요."))
      return
    }

    webView.loadHTMLString(postcodeHTML, baseURL: baseURL)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    presentationController?.delegate = self
  }

  func cancelFromHost() {
    completeIfNeeded(.cancelled)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    completeIfNeeded(.cancelled)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    completeIfNeeded(.failure(code: "network_error", message: "네트워크 상태를 확인한 뒤 다시 시도해 주세요."))
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    completeIfNeeded(.failure(code: "network_error", message: "네트워크 상태를 확인한 뒤 다시 시도해 주세요."))
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    completeIfNeeded(.failure(code: "script_error", message: "주소 검색 화면을 다시 열어 주세요."))
  }

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    guard let url = navigationAction.request.url else {
      decisionHandler(.cancel)
      return
    }

    if isAllowed(url: url) {
      decisionHandler(.allow)
      return
    }

    decisionHandler(.cancel)

    let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
    if isMainFrame || navigationAction.navigationType == .linkActivated {
      completeIfNeeded(.failure(code: "external_navigation_blocked", message: "주소 검색 중 외부 페이지 이동은 지원하지 않아요."))
    }
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard message.name == bridgeName,
      let body = message.body as? [String: Any],
      let type = body["type"] as? String
    else {
      return
    }

    switch type {
    case "iframeLoaded":
      clearLoadTimeout()
    case "cancel":
      completeIfNeeded(.cancelled)
    case "scriptError":
      completeIfNeeded(.failure(code: "script_error", message: "주소 검색 화면을 불러오지 못했어요. 다시 시도해 주세요."))
    case "select":
      let postcode = stringValue(body["zonecode"])
      let roadAddress = stringValue(body["roadAddress"])
      let jibunAddress = stringValue(body["jibunAddress"])
      let buildingName = stringValue(body["buildingName"])

      completeIfNeeded(.success([
        "postcode": postcode,
        "roadAddress": roadAddress,
        "jibunAddress": jibunAddress,
        "buildingName": buildingName,
        "source": "kakao_postcode",
      ]))
    default:
      break
    }
  }

  private func completeIfNeeded(_ outcome: AddressSearchOutcome) {
    guard !hasCompleted else { return }
    hasCompleted = true
    clearLoadTimeout()
    tearDownWebView()

    let completion = onComplete
    onComplete = nil

    if presentingViewController != nil, !isBeingDismissed {
      dismiss(animated: true) {
        completion?(outcome)
      }
    } else {
      completion?(outcome)
    }
  }

  private func scheduleLoadTimeout() {
    clearLoadTimeout()

    let workItem = DispatchWorkItem { [weak self] in
      self?.completeIfNeeded(.failure(code: "load_timeout", message: "주소 검색 화면 응답이 지연되고 있어요. 다시 시도해 주세요."))
    }
    loadTimeoutWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + loadTimeoutInterval, execute: workItem)
  }

  private func clearLoadTimeout() {
    loadTimeoutWorkItem?.cancel()
    loadTimeoutWorkItem = nil
  }

  private func tearDownWebView() {
    messageHandler.delegate = nil
    webView.navigationDelegate = nil
    webView.stopLoading()
    contentController.removeScriptMessageHandler(forName: bridgeName)
    contentController.removeAllUserScripts()
  }

  private func isAllowed(url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    if scheme == "about" || scheme == "data" {
      return true
    }
    guard scheme == "https", let host = url.host?.lowercased() else {
      return false
    }

    let exactHosts: Set<String> = [
      "postcode.map.kakao.com",
      "postcode.map.daum.net",
    ]
    let suffixHosts = [
      ".daumcdn.net",
      ".kakaocdn.net",
    ]

    return exactHosts.contains(host) || suffixHosts.contains(where: { host.hasSuffix($0) })
  }

  private func stringValue(_ value: Any?) -> String {
    guard let string = value as? String else { return "" }
    return string
  }

  private var postcodeHTML: String {
    """
    <!DOCTYPE html>
    <html lang="ko">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
        <style>
          html, body, #wrap {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            background: #ffffff;
          }

          body {
            overflow: hidden;
          }
        </style>
      </head>
      <body>
        <div id="wrap"></div>
        <script>
          (function() {
            var wrap = document.getElementById('wrap');
            var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.addressSearch;

            function emit(type, data) {
              if (!bridge) {
                return;
              }
              bridge.postMessage(Object.assign({ type: type }, data || {}));
            }

            function observeIframeLoad() {
              var observer = new MutationObserver(function() {
                var iframe = wrap.querySelector('iframe');
                if (!iframe) {
                  return;
                }
                observer.disconnect();
                iframe.addEventListener('load', function handleLoad() {
                  emit('iframeLoaded');
                }, { once: true });
              });

              observer.observe(wrap, { childList: true, subtree: true });
            }

            function createPostcode() {
              var Postcode = window.kakao && window.kakao.Postcode;
              if (!Postcode && window.daum) {
                Postcode = window.daum.Postcode;
              }
              if (!Postcode) {
                emit('scriptError', { reason: 'postcode_unavailable' });
                return;
              }

              var postcode = new Postcode({
                oncomplete: function(data) {
                  emit('select', {
                    zonecode: data.zonecode || '',
                    roadAddress: data.roadAddress || '',
                    jibunAddress: data.jibunAddress || '',
                    buildingName: data.buildingName || ''
                  });
                },
                onclose: function(state) {
                  if (state === 'FORCE_CLOSE') {
                    emit('cancel');
                  }
                },
                width: '100%',
                height: '100%'
              });

              observeIframeLoad();
              postcode.embed(wrap);
            }

            function loadSdk() {
              var script = document.createElement('script');
              script.src = 'https://t1.kakaocdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js';
              script.async = true;
              script.onload = createPostcode;
              script.onerror = function() {
                emit('scriptError', { reason: 'sdk_load_failed' });
              };
              document.head.appendChild(script);
            }

            window.addEventListener('error', function() {
              emit('scriptError', { reason: 'window_error' });
            });

            window.addEventListener('unhandledrejection', function() {
              emit('scriptError', { reason: 'promise_rejection' });
            });

            loadSdk();
          })();
        </script>
      </body>
    </html>
    """
  }
}
