import SwiftUI
import WidgetKit

/// The iOS home-screen widgets: what NeoAgent is doing, and one tap into a
/// voice call. Like on Android, the app publishes its state while it runs
/// and the widgets read the agent's runs from the server while it is closed.
@main
struct NeoAgentWidgets: WidgetBundle {
  var body: some Widget {
    StatusWidget()
    CallWidget()
  }
}

/// Opens the app straight into a voice call (`AppLaunchBridge.startCallAction`).
private let startCallUrl = URL(string: "neoagent://call")!

struct StatusEntry: TimelineEntry {
  let date: Date
  let status: HomeWidgetStatus?
}

struct StatusProvider: TimelineProvider {
  /// How soon to look again while a run is under way, and otherwise.
  private static let underWay: TimeInterval = 60
  private static let idle: TimeInterval = 15 * 60
  private static let recentEnd: TimeInterval = 10 * 60

  func placeholder(in context: Context) -> StatusEntry {
    StatusEntry(date: Date(), status: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
    completion(StatusEntry(date: Date(), status: HomeWidgetStore.read()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
    Task {
      await refreshFromServer()
      let status = HomeWidgetStore.read()
      let next = Date().addingTimeInterval(status?.mood.changesSoon == true ? Self.underWay : Self.idle)
      completion(Timeline(entries: [StatusEntry(date: Date(), status: status)], policy: .after(next)))
    }
  }

  /// Android's `HomeWidgetRefreshWorker`: skipped while the app is live, its
  /// own state being newer than the server's run list.
  private func refreshFromServer() async {
    guard let session = HomeWidgetStore.session(), HomeWidgetStore.read()?.live != true else { return }
    var path = "/api/agents?limit=10"
    if !session.agentId.isEmpty,
       let agentId = session.agentId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      path += "&agentId=\(agentId)"
    }
    guard let response = try? await BackendHttp.request("GET", baseUrl: session.backendUrl, path: path, cookie: session.cookie)
    else { return }
    if response.code == 401 {
      // The sign-in expired; the app stores a fresh one when it next runs.
      HomeWidgetStore.saveSession(backendUrl: session.backendUrl, cookie: "", agentId: session.agentId)
      _ = HomeWidgetStore.refresh(mood: .asleep, detail: "Open NeoAgent to sign in")
      return
    }
    guard (200..<300).contains(response.code),
          let body = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any]
    else { return }
    let (mood, detail) = Self.mood(fromRuns: body["runs"] as? [[String: Any]] ?? [], now: Date())
    _ = HomeWidgetStore.refresh(mood: mood, detail: detail)
  }

  /// The mood the run list stands for, newest run first: someone waiting on
  /// you, then work in progress, then a run that ended in the last minutes.
  static func mood(fromRuns runs: [[String: Any]], now: Date) -> (HomeWidgetMood, String) {
    func title(_ run: [String: Any]) -> String {
      (run["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let run = runs.first(where: { $0["status"] as? String == "waiting_input" }) { return (.waiting, title(run)) }
    if let run = runs.first(where: { $0["status"] as? String == "running" }) { return (.working, title(run)) }
    guard let latest = runs.first,
          let endedAt = timestamp(latest["completed_at"] as? String),
          now.timeIntervalSince(endedAt) <= recentEnd
    else { return (.idle, "") }
    switch latest["status"] as? String {
    case "completed": return (.done, title(latest))
    case "failed", "error": return (.blocked, title(latest))
    default: return (.idle, "")
    }
  }

  /// SQLite writes `YYYY-MM-DD HH:MM:SS` in UTC.
  private static func timestamp(_ raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    let iso = raw.contains("T") ? raw : raw.replacingOccurrences(of: " ", with: "T") + "Z"
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
  }
}

// MARK: Widgets

struct StatusWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NeoAgentStatus", provider: StatusProvider()) { entry in
      StatusView(status: entry.status)
    }
    .configurationDisplayName("NeoAgent status")
    .description("What NeoAgent is doing right now.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct CallWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NeoAgentCall", provider: StatusProvider()) { entry in
      CallView(status: entry.status)
    }
    .configurationDisplayName("Call NeoAgent")
    .description("Start a voice call with one tap.")
    .supportedFamilies([.systemSmall])
  }
}

// MARK: Views

private enum Palette {
  static let surfaceTop = Color(light: 0xFDFCF8, dark: 0x1C261F)
  static let surfaceBottom = Color(light: 0xF1EDE1, dark: 0x0E1511)
  static let textPrimary = Color(light: 0x1C2117, dark: 0xECEFE5)
  static let textSecondary = Color(light: 0x49503F, dark: 0xAEB7A6)
  static let textMuted = Color(light: 0x7E8470, dark: 0x7E8877)
  static let accent = Color(light: 0xB07D2B, dark: 0xE1B052)
  static let onAccent = Color(light: 0xFDFCF8, dark: 0x0E1511)
  static let success = Color(light: 0x527C4F, dark: 0x74C07C)
  static let alert = Color(light: 0xAE473C, dark: 0xDE8A78)
}

private func face(_ status: HomeWidgetStatus?) -> Image {
  Image("neoagent_face_\((status?.mood ?? .asleep).rawValue)")
}

private func label(_ status: HomeWidgetStatus?) -> String {
  guard let status else { return "Not connected" }
  if status.mood == .idle, status.callStartedAt != nil { return "On a call" }
  return status.mood.label
}

struct StatusView: View {
  let status: HomeWidgetStatus?
  @Environment(\.widgetFamily) private var family

  var body: some View {
    Group {
      if family == .systemSmall {
        face(status).resizable().scaledToFit()
          .accessibilityLabel(label(status))
      } else {
        full
      }
    }
    .widgetBackground(family == .systemSmall ? AnyShapeStyle(.clear) : AnyShapeStyle(panel))
  }

  private var panel: LinearGradient {
    LinearGradient(colors: [Palette.surfaceTop, Palette.surfaceBottom], startPoint: .top, endPoint: .bottom)
  }

  private var full: some View {
    HStack(spacing: 14) {
      face(status).resizable().scaledToFit().frame(width: 88, height: 88)
      VStack(alignment: .leading, spacing: 4) {
        Text(label(status))
          .font(.headline)
          .foregroundStyle(status?.mood == .blocked ? Palette.alert : Palette.textPrimary)
        let detail = status?.detail ?? "Open NeoAgent to sign in"
        if !detail.isEmpty {
          Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary).lineLimit(2)
        }
        if let status { freshness(status) }
        Spacer(minLength: 0)
        Link(destination: startCallUrl) {
          HStack(spacing: 6) {
            Image(systemName: "phone.fill")
            if let startedAt = status?.callStartedAt {
              Text("Return to call")
              Text(startedAt, style: .timer).monospacedDigit()
            } else {
              Text("Talk to NeoAgent")
            }
          }
          .font(.footnote.weight(.semibold))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Capsule().fill(Palette.accent))
          .foregroundStyle(Palette.onAccent)
        }
      }
      Spacer(minLength: 0)
    }
  }

  /// "Live" while the app follows the agent, otherwise when it last did.
  private func freshness(_ status: HomeWidgetStatus) -> some View {
    HStack(spacing: 4) {
      Circle().fill(status.live ? Palette.success : Palette.textMuted).frame(width: 6, height: 6)
      if status.live {
        Text("Live")
      } else {
        Text("Seen \(status.updatedAt.formatted(date: .omitted, time: .shortened))")
      }
    }
    .font(.caption)
    .foregroundStyle(Palette.textMuted)
  }
}

struct CallView: View {
  let status: HomeWidgetStatus?

  var body: some View {
    face(status).resizable().scaledToFit()
      .overlay(alignment: .bottomTrailing) {
        Image(systemName: "phone.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Palette.onAccent)
          .padding(8)
          .background(Circle().fill(Palette.accent))
      }
      .accessibilityLabel("Talk to NeoAgent")
      .widgetURL(startCallUrl)
      .widgetBackground(AnyShapeStyle(.clear))
  }
}

private extension View {
  /// iOS 17 requires a container background; earlier versions draw it as one.
  @ViewBuilder
  func widgetBackground(_ style: AnyShapeStyle) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(style, for: .widget)
    } else {
      background(style)
    }
  }
}

private extension Color {
  init(light: UInt32, dark: UInt32) {
    self.init(UIColor { traits in
      let hex = traits.userInterfaceStyle == .dark ? dark : light
      return UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
      )
    })
  }
}
