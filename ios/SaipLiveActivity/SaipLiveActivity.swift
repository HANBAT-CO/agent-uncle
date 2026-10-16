import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SaipLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SaipActivityAttributes.self) { context in
      VStack(alignment: .leading) {
        Text("사입삼춘")
        Text(isStale(context) ? "최신 상태는 앱에서 확인해 주세요" : context.state.status)
        if context.state.total > 0 {
          ProgressView(value: Double(min(context.state.acquired, context.state.total)), total: Double(context.state.total))
          Text("확보 \(context.state.acquired) / \(context.state.total)장")
        }
      }
      .padding()
      .widgetURL(destination(context.attributes))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) { Text("사입삼춘") }
        DynamicIslandExpandedRegion(.trailing) {
          if context.state.total > 0 { Text("\(context.state.acquired)/\(context.state.total)") }
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(isStale(context) ? "앱에서 최신 상태 확인" : context.state.status)
        }
      } compactLeading: { Text("사입") }
        compactTrailing: { Text(isStale(context) ? "확인" : context.state.total > 0 ? "\(context.state.acquired)/\(context.state.total)" : "진행") }
        minimal: { Text("사입") }
        .widgetURL(destination(context.attributes))
    }
  }
  private func isStale(_ context: ActivityViewContext<SaipActivityAttributes>) -> Bool {
    if #available(iOS 16.2, *) { return context.isStale }
    return false
  }
  private func destination(_ attributes: SaipActivityAttributes) -> URL? {
    var url = URLComponents()
    url.scheme = "com.hanbatco.agentuncle"; url.host = "activity"
    url.queryItems = [URLQueryItem(name: "requestId", value: attributes.requestId),
      URLQueryItem(name: "ownerId", value: attributes.ownerId), URLQueryItem(name: "binding", value: attributes.binding)]
    return url.url
  }
}
