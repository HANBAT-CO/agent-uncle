import ActivityKit

@available(iOS 16.1, *)
struct SaipActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var status: String
    var acquired: Int
    var total: Int
    var ended: Bool
  }
  var requestId: String
  var ownerId: String
  var binding: String
}
