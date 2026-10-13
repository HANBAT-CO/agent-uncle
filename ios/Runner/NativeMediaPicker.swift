import AVFoundation
import Flutter
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class NativeMediaPicker: NSObject {
  private let channel: FlutterMethodChannel
  private weak var activeController: UIViewController?
  private var pendingResult: FlutterResult?
  private var activeSessionID: Int = 0
  private let maxPayloadBytes = 10 * 1024 * 1024
  private let thumbnailMaxPixelSize = 2_560
  private let jpegQualities: [CGFloat] = [0.92, 0.82, 0.72, 0.62, 0.52, 0.42]

  static func register(with registrar: FlutterPluginRegistrar) -> NativeMediaPicker {
    NativeMediaPicker(messenger: registrar.messenger())
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "agent_uncle/native_media_picker", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "사진 선택을 사용할 수 없어요.", details: nil))
        return
      }
      self.handle(call, result: result)
    }
  }

  func dispose() {
    channel.setMethodCallHandler(nil)
    activeController?.dismiss(animated: false)
    if let result = pendingResult {
      pendingResult = nil
      activeController = nil
      result(nil)
    }
    activeSessionID += 1
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard self.pendingResult == nil else {
        result(FlutterError(code: "busy", message: "사진 선택이 이미 진행 중이에요. 잠시 후 다시 시도해 주세요.", details: nil))
        return
      }

      self.activeSessionID += 1
      let sessionID = self.activeSessionID
      self.pendingResult = result

      switch call.method {
      case "pickCameraImage":
        self.presentCamera(sessionID: sessionID)
      case "pickGalleryImage":
        self.presentGallery(sessionID: sessionID)
      default:
        self.pendingResult = nil
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presentCamera(sessionID: Int) {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      finishError(sessionID: sessionID, code: "unavailable", message: "이 기기에서는 카메라를 사용할 수 없어요.")
      return
    }

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      showCameraPicker(sessionID: sessionID)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          guard let self else { return }
          if granted {
            self.showCameraPicker(sessionID: sessionID)
          } else {
            self.finishError(sessionID: sessionID, code: "permission_denied", message: "카메라 권한이 필요해요. 설정에서 허용해 주세요.")
          }
        }
      }
    case .denied, .restricted:
      finishError(sessionID: sessionID, code: "permission_denied", message: "카메라 권한이 필요해요. 설정에서 허용해 주세요.")
    @unknown default:
      finishError(sessionID: sessionID, code: "unavailable", message: "카메라 권한 상태를 확인하지 못했어요.")
    }
  }

  private func showCameraPicker(sessionID: Int) {
    guard sessionID == activeSessionID, pendingResult != nil else { return }
    guard let presenter = activePresenter() else {
      finishError(sessionID: sessionID, code: "unavailable", message: "사진 화면을 열 수 없어요. 다시 시도해 주세요.")
      return
    }

    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.mediaTypes = [UTType.image.identifier]
    picker.allowsEditing = false
    picker.delegate = self
    activeController = picker
    presenter.present(picker, animated: true)
  }

  private func presentGallery(sessionID: Int) {
    guard let presenter = activePresenter() else {
      finishError(sessionID: sessionID, code: "unavailable", message: "사진 화면을 열 수 없어요. 다시 시도해 주세요.")
      return
    }

    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .compatible

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    activeController = picker
    presenter.present(picker, animated: true)
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

  private func finish(sessionID: Int, payload: [String: Any]?) {
    guard sessionID == activeSessionID, let result = pendingResult else { return }
    activeController = nil
    pendingResult = nil
    result(payload)
  }

  private func finishError(sessionID: Int, code: String, message: String) {
    guard sessionID == activeSessionID, let result = pendingResult else { return }
    activeController = nil
    pendingResult = nil
    result(FlutterError(code: code, message: message, details: nil))
  }

  private func finishSelection(sessionID: Int, data: Data, suggestedName: String?, fallbackMime: String? = nil) {
    let mime = detectMime(data) ?? fallbackMime
    guard let mime, ["image/jpeg", "image/png"].contains(mime) else {
      finishError(sessionID: sessionID, code: "unsupported_type", message: "지원하는 사진 형식을 선택해 주세요.")
      return
    }
    guard !data.isEmpty, data.count <= maxPayloadBytes else {
      finishError(sessionID: sessionID, code: "invalid_size", message: "10MB 이하 사진을 선택해 주세요.")
      return
    }

    let name = normalizedFilename(from: suggestedName, mime: mime)
    finish(sessionID: sessionID, payload: [
      "name": name,
      "mime": mime,
      "bytes": FlutterStandardTypedData(bytes: data),
    ])
  }

  private func normalizedFilename(from suggestedName: String?, mime: String) -> String {
    let ext = mime == "image/png" ? "png" : "jpg"
    let trimmedName = (suggestedName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let baseName = ((trimmedName as NSString).deletingPathExtension).trimmingCharacters(in: .whitespacesAndNewlines)
    let finalBaseName = baseName.isEmpty ? "photo" : baseName
    return finalBaseName + "." + ext
  }

  private func detectMime(_ data: Data) -> String? {
    let bytes = [UInt8](data.prefix(12))
    if bytes.count >= 8,
      bytes[0] == 0x89,
      bytes[1] == 0x50,
      bytes[2] == 0x4E,
      bytes[3] == 0x47
    {
      return "image/png"
    }
    if bytes.count >= 3,
      bytes[0] == 0xFF,
      bytes[1] == 0xD8,
      bytes[2] == 0xFF
    {
      return "image/jpeg"
    }
    return nil
  }

  private func processFileSelection(url: URL, suggestedName: String?, sessionID: Int, removeAfterProcessing: Bool = false) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      defer {
        if removeAfterProcessing {
          try? FileManager.default.removeItem(at: url)
        }
      }
      let selection = self.makeSelection(fromFileAt: url, suggestedName: suggestedName)
      DispatchQueue.main.async {
        switch selection {
        case let .success(data, name, mime):
          self.finishSelection(sessionID: sessionID, data: data, suggestedName: name, fallbackMime: mime)
        case let .failure(code, message):
          self.finishError(sessionID: sessionID, code: code, message: message)
        }
      }
    }
  }

  private func processImageSelection(image: UIImage, suggestedName: String?, sessionID: Int) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      guard let data = self.encodedJPEGData(from: image) else {
        DispatchQueue.main.async {
          self.finishError(sessionID: sessionID, code: "invalid_size", message: "10MB 이하 사진을 선택해 주세요.")
        }
        return
      }

      DispatchQueue.main.async {
        self.finishSelection(sessionID: sessionID, data: data, suggestedName: suggestedName, fallbackMime: "image/jpeg")
      }
    }
  }

  private func makeSelection(fromFileAt url: URL, suggestedName: String?) -> SelectionResult {
    let fileSize = ((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize) ?? 0
    let directMime = mimeForFileExtension(url.pathExtension)

    if fileSize > 0,
      fileSize <= maxPayloadBytes,
      let directMime,
      ["image/jpeg", "image/png"].contains(directMime),
      let data = try? Data(contentsOf: url)
    {
      if let actualMime = detectMime(data) {
        return .success(data: data, suggestedName: suggestedName ?? url.lastPathComponent, mime: actualMime)
      }
    }

    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      return .failure(code: "read_failed", message: "사진을 불러오지 못했어요. 다시 시도해 주세요.")
    }

    guard let image = thumbnailImage(from: source) else {
      return .failure(code: "read_failed", message: "사진을 불러오지 못했어요. 다시 시도해 주세요.")
    }

    guard let data = encodedJPEGData(from: image) else {
      return .failure(code: "invalid_size", message: "10MB 이하 사진을 선택해 주세요.")
    }

    return .success(data: data, suggestedName: suggestedName ?? url.lastPathComponent, mime: "image/jpeg")
  }

  private func mimeForFileExtension(_ pathExtension: String) -> String? {
    let normalizedExtension = pathExtension.lowercased()
    guard let type = UTType(filenameExtension: normalizedExtension) else { return nil }
    if type.conforms(to: .png) {
      return "image/png"
    }
    if type.conforms(to: .jpeg) {
      return "image/jpeg"
    }
    if type.conforms(to: .heic) || type.conforms(to: .heif) {
      return "image/heic"
    }
    return nil
  }

  private func thumbnailImage(from source: CGImageSource) -> UIImage? {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCache: false,
      kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixelSize,
    ]

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      return nil
    }

    return UIImage(cgImage: cgImage)
  }

  private func encodedJPEGData(from image: UIImage) -> Data? {
    for quality in jpegQualities {
      if let data = image.jpegData(compressionQuality: quality), data.count <= maxPayloadBytes {
        return data
      }
    }

    var candidateImage = image
    var maxDimension = max(image.size.width, image.size.height)

    while maxDimension > 640 {
      maxDimension *= 0.75
      guard let resizedImage = resizedImage(from: candidateImage, maxPixelSize: maxDimension) else {
        break
      }
      candidateImage = resizedImage
      for quality in jpegQualities {
        if let data = candidateImage.jpegData(compressionQuality: quality), data.count <= maxPayloadBytes {
          return data
        }
      }
    }

    return nil
  }

  private func resizedImage(from image: UIImage, maxPixelSize: CGFloat) -> UIImage? {
    let longestSide = max(image.size.width, image.size.height)
    guard longestSide > 0 else { return nil }

    let scale = min(1, maxPixelSize / longestSide)
    let targetSize = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
    guard targetSize.width > 0, targetSize.height > 0 else { return nil }

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  private func persistTemporaryCopy(of url: URL) -> URL? {
    let fileManager = FileManager.default
    let destination = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(url.pathExtension)

    do {
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }
      try fileManager.copyItem(at: url, to: destination)
      return destination
    } catch {
      return nil
    }
  }
}

private enum SelectionResult {
  case success(data: Data, suggestedName: String, mime: String)
  case failure(code: String, message: String)
}

extension NativeMediaPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    let sessionID = activeSessionID
    picker.dismiss(animated: true) { [weak self] in
      self?.finish(sessionID: sessionID, payload: nil)
    }
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    let sessionID = activeSessionID
    let image = info[.originalImage] as? UIImage
    let imageURL = info[.imageURL] as? URL
    let suggestedName = imageURL?.lastPathComponent

    picker.dismiss(animated: true) { [weak self] in
      guard let self else { return }
      if let imageURL {
        self.processFileSelection(url: imageURL, suggestedName: suggestedName, sessionID: sessionID)
        return
      }
      guard let image else {
        self.finishError(sessionID: sessionID, code: "read_failed", message: "사진을 불러오지 못했어요. 다시 시도해 주세요.")
        return
      }
      self.processImageSelection(image: image, suggestedName: suggestedName, sessionID: sessionID)
    }
  }
}

@available(iOS 14.0, *)
extension NativeMediaPicker: PHPickerViewControllerDelegate {
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    let sessionID = activeSessionID
    picker.dismiss(animated: true) { [weak self] in
      guard let self else { return }
      guard let item = results.first else {
        self.finish(sessionID: sessionID, payload: nil)
        return
      }
      guard item.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
        self.finishError(sessionID: sessionID, code: "unsupported_type", message: "지원하는 사진 형식을 선택해 주세요.")
        return
      }

      item.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
        guard let self else { return }

        if error != nil || url == nil {
          DispatchQueue.main.async {
            self.finishError(sessionID: sessionID, code: "read_failed", message: "사진을 불러오지 못했어요. 다시 시도해 주세요.")
          }
          return
        }

        guard let sourceURL = url, let temporaryCopyURL = self.persistTemporaryCopy(of: sourceURL) else {
          DispatchQueue.main.async {
            self.finishError(sessionID: sessionID, code: "read_failed", message: "사진을 안전하게 읽지 못했어요. 다시 시도해 주세요.")
          }
          return
        }

        let suggestedName = item.itemProvider.suggestedName ?? sourceURL.lastPathComponent
        self.processFileSelection(url: temporaryCopyURL, suggestedName: suggestedName, sessionID: sessionID, removeAfterProcessing: true)
      }
    }
  }
}
