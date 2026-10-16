import ActivityKit
import Flutter
import Security
import UIKit
import UserNotifications

@MainActor
final class PushNotifications: NSObject {
  static let shared = PushNotifications()
  private let defaults = UserDefaults.standard
  private var channel: FlutterMethodChannel?
  private var watchers: [String: Task<Void, Never>] = [:]
  private var uploads: Set<String> = []
  private var observer: Task<Void, Never>?
  private var registrationFailed = false
  private var bindingGeneration = 0
  private func key(_ name: String) -> String { "saip.push.\(name)" }
  private func string(_ name: String) -> String { defaults.string(forKey: key(name)) ?? "" }
  private func set(_ name: String, _ value: Any?) { defaults.set(value, forKey: key(name)) }
  private var liveEnabled: Bool { defaults.bool(forKey: key("liveEnabled")) }
  private var secretQuery: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "saip.activity-registration", kSecAttrAccount as String: "installation"]
  }
  private func secret() -> String {
    var query = secretQuery
    query[kSecReturnData as String] = true
    var result: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
       let data = result as? Data, let value = String(data: data, encoding: .utf8) { return value }
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return "" }
    let value = bytes.map { String(format: "%02x", $0) }.joined()
    query = secretQuery
    query[kSecValueData as String] = Data(value.utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { return "" }
    return value
  }

  func install() {
    if string("id").isEmpty { set("id", UUID().uuidString.lowercased()) }
    if #available(iOS 16.1, *) {
      for activity in Activity<SaipActivityAttributes>.activities { watch(activity) }
      observer = Task { [weak self] in
        for await activity in Activity<SaipActivityAttributes>.activityUpdates { self?.watch(activity) }
      }
    }
  }

  func attach(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "agent_uncle/notifications", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      Task { @MainActor in
        guard let self else { result(nil); return }
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "bind":
          let owner = args["ownerId"] as? String ?? ""
          if owner != self.string("owner") {
            self.bindingGeneration += 1
            let generation = self.bindingGeneration
            await self.clear()
            guard generation == self.bindingGeneration else { result(await self.state()); return }
            self.set("owner", owner)
          }
          let generation = self.bindingGeneration
          self.set("url", args["url"]); self.set("key", args["key"])
          if !owner.isEmpty {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard generation == self.bindingGeneration else { result(await self.state()); return }
            if settings.authorizationStatus == .notDetermined && !self.defaults.bool(forKey: self.key("permissionAsked")) {
              self.set("permissionAsked", true)
              _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            }
            guard generation == self.bindingGeneration else { result(await self.state()); return }
            UIApplication.shared.registerForRemoteNotifications()
          }
          result(await self.state())
        case "state": result(await self.state())
        case "requestPermission":
          do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            UIApplication.shared.registerForRemoteNotifications()
            self.changed(); result(nil)
          } catch { result(FlutterError(code: "permission", message: "알림 권한을 확인하지 못했어요.", details: nil)) }
        case "openSettings":
          if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
          result(nil)
        case "clear": self.bindingGeneration += 1; await self.clear(); result(nil)
        case "takeTap":
          let tap = self.defaults.dictionary(forKey: self.key("tap"))
          self.set("tap", nil); result(tap)
        case "setLiveEnabled":
          self.set("liveEnabled", args["enabled"] as? Bool ?? false)
          if !self.liveEnabled { await self.endActivities() }
          self.changed(); result(nil)
        case "startActivity":
          if #available(iOS 16.1, *), let request = args["requestId"] as? String {
            do { try self.startActivity(request); result(nil) }
            catch { result(FlutterError(code: "live_activity", message: "진행 알림을 시작하지 못했어요. iPhone 설정의 실시간 현황 허용 여부를 확인해 주세요.", details: nil)) }
          } else { result(FlutterError(code: "unsupported", message: "iOS 16.1 이상에서 사용할 수 있어요.", details: nil)) }
        case "syncActivities":
          if #available(iOS 16.1, *) { for activity in Activity<SaipActivityAttributes>.activities { self.watch(activity) } }
          self.retryUploads(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  func registered(_ token: Data) {
    let value = token.map { String(format: "%02x", $0) }.joined()
    let shouldNotify = registrationFailed || value != string("token")
    registrationFailed = false
    set("token", value)
    if shouldNotify { changed() }
  }
  func registrationError() {
    if !registrationFailed { registrationFailed = true; changed() }
  }
  func changed() { channel?.invokeMethod("changed", arguments: nil) }
  private func state() async -> [String: Any] {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    var supported = false, allowed = false
    if #available(iOS 16.1, *) { supported = true; allowed = ActivityAuthorizationInfo().areActivitiesEnabled }
    return ["id": string("id"), "binding": string("binding"), "token": string("token"), "platform": "ios",
      "environment": Bundle.main.object(forInfoDictionaryKey: "SaipPushEnvironment") as? String ?? "production",
      "enabled": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
      "configured": !registrationFailed, "liveSupported": supported, "liveEnabled": liveEnabled && allowed,
      "activitySecret": secret()]
  }

  func capture(_ data: [AnyHashable: Any]) {
    guard !string("owner").isEmpty, data["ownerId"] as? String == string("owner"), data["binding"] as? String == string("binding") else { return }
    let fields = ["id", "ownerId", "binding", "noticeId", "kind", "targetId", "requestId"]
    set("tap", Dictionary(uniqueKeysWithValues: fields.map { ($0, data[$0] as? String ?? "") }))
    changed()
  }
  func capture(_ url: URL) -> Bool {
    guard url.scheme == "com.hanbatco.agentuncle", url.host == "activity",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
    var data: [String: String] = [:]
    for item in components.queryItems ?? [] { data[item.name] = item.value }
    data["kind"] = "request"; data["targetId"] = data["requestId"]
    capture(data); return true
  }

  private func clear() async {
    set("owner", ""); set("binding", UUID().uuidString.lowercased()); set("tap", nil)
    set("pending", nil); set("uploaded", nil); set("liveEnabled", false)
    SecItemDelete(secretQuery as CFDictionary)
    UIApplication.shared.unregisterForRemoteNotifications()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    await endActivities()
  }
  private func endActivities() async {
    if #available(iOS 16.1, *) {
      for activity in Activity<SaipActivityAttributes>.activities { await activity.end(using: nil, dismissalPolicy: .immediate) }
    }
  }
  @available(iOS 16.1, *)
  private func startActivity(_ request: String) throws {
    guard !string("owner").isEmpty, liveEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw NSError(domain: "saip.live", code: 1)
    }
    if let existing = Activity<SaipActivityAttributes>.activities.first(where: {
      $0.attributes.requestId == request && $0.attributes.binding == string("binding") && $0.activityState == .active
    }) { watch(existing); return }
    let attributes = SaipActivityAttributes(requestId: request, ownerId: string("owner"), binding: string("binding"))
    let activity = try Activity.request(attributes: attributes,
      contentState: SaipActivityAttributes.ContentState(status: "진행 상황을 불러오고 있어요", acquired: 0, total: 0, ended: false), pushType: .token)
    watch(activity)
  }
  @available(iOS 16.1, *)
  private func watch(_ activity: Activity<SaipActivityAttributes>) {
    guard activity.attributes.ownerId == string("owner"), activity.attributes.binding == string("binding"), liveEnabled else {
      Task { await activity.end(using: nil, dismissalPolicy: .immediate) }; return
    }
    let ended = activity.activityState == .ended || activity.activityState == .dismissed
    if let token = activity.pushToken { queue(activity, token: token, ended: ended) }
    if ended { return }
    guard watchers[activity.id] == nil else { return }
    watchers[activity.id] = Task { [weak self] in
      for await token in activity.pushTokenUpdates { self?.queue(activity, token: token, ended: false) }
    }
    watchers[activity.id + ".state"] = Task { [weak self] in
      for await state in activity.activityStateUpdates {
        if state == .ended || state == .dismissed {
          if let token = activity.pushToken { self?.queue(activity, token: token, ended: true) }
          self?.watchers.removeValue(forKey: activity.id)?.cancel()
          self?.watchers.removeValue(forKey: activity.id + ".state")?.cancel()
          break
        }
      }
    }
  }
  @available(iOS 16.1, *)
  private func queue(_ activity: Activity<SaipActivityAttributes>, token: Data, ended: Bool) {
    guard activity.attributes.binding == string("binding"), activity.attributes.ownerId == string("owner") else { return }
    var pending = defaults.dictionary(forKey: key("pending")) as? [String: [String: Any]] ?? [:]
    let entry: [String: Any] = ["device_id": string("id"), "binding_id": string("binding"), "request_id": activity.attributes.requestId,
      "token": token.map { String(format: "%02x", $0) }.joined(), "ended": ended]
    let uploaded = defaults.dictionary(forKey: key("uploaded")) as? [String: [String: Any]] ?? [:]
    if NSDictionary(dictionary: uploaded[activity.id] ?? [:]).isEqual(to: entry) { return }
    pending[activity.id] = entry
    set("pending", pending); retryUploads()
  }
  private func retryUploads() {
    guard !string("owner").isEmpty, let base = URL(string: string("url")), !string("key").isEmpty else { return }
    // HTTPS만 허용한다. 개발 시 로컬 Supabase는 시뮬레이터/실기기 HTTPS 터널을 사용한다.
    guard base.scheme == "https" else { return }
    let pending = defaults.dictionary(forKey: key("pending")) as? [String: [String: Any]] ?? [:]
    for (id, entry) in pending where !uploads.contains(id) {
      uploads.insert(id)
      let capability = secret(), apiKey = string("key"), binding = string("binding")
      let background = UIApplication.shared.beginBackgroundTask(withName: "사입 진행 알림 등록")
      Task { [weak self] in
        var retryNewer = false
        defer {
          self?.uploads.remove(id)
          if background != .invalid { UIApplication.shared.endBackgroundTask(background) }
          if retryNewer { self?.retryUploads() }
        }
        var body = entry; body["capability"] = capability
        for delay in [0, 1, 2, 4] {
          if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000) }
          guard let self, self.string("binding") == binding else { return }
          var request = URLRequest(url: base.appendingPathComponent("rest/v1/rpc/saip_activity_token"))
          request.httpMethod = "POST"; request.timeoutInterval = 5
          request.setValue(apiKey, forHTTPHeaderField: "apikey")
          if apiKey.hasPrefix("eyJ") { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.httpBody = try? JSONSerialization.data(withJSONObject: body)
          if let (_, response) = try? await URLSession.shared.data(for: request),
             let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
            guard self.string("binding") == binding else { return }
            var current = self.defaults.dictionary(forKey: self.key("pending")) as? [String: [String: Any]] ?? [:]
            if NSDictionary(dictionary: current[id] ?? [:]).isEqual(to: entry) { current.removeValue(forKey: id) }
            else { retryNewer = current[id] != nil }
            self.set("pending", current)
            var uploaded = self.defaults.dictionary(forKey: self.key("uploaded")) as? [String: [String: Any]] ?? [:]
            uploaded[id] = entry; self.set("uploaded", uploaded)
            return
          }
        }
      }
    }
  }
}
