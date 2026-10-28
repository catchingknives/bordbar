import SwiftUI

/// The rich part of the menu, hosted inside an NSMenuItem. Visual language follows
/// HeizBar: cards on the control background, headline type, tinted capsule badges.
struct MenuPanel: View {
    let content: MenuContent
    var hovered: String? = nil
    var onHover: (String?) -> Void = { _ in }
    let onStopClick: (String) -> Void

    var body: some View {
        Group {
            if content.speed == nil {
                OfflineView()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    TrainHeader(content: content)
                    if let next = content.next {
                        StopCardView(card: next, title: "Next stop", isExit: next.id == content.exit?.id)
                    }
                    if let exit = content.exit, exit.id != content.next?.id {
                        StopCardView(card: exit, title: "Your stop", isExit: true)
                    }
                    if !content.stops.isEmpty {
                        RouteBar(content: content)
                        StopTimeline(stops: content.stops, hovered: hovered, onHover: onHover, onClick: onStopClick)
                        if let hint = markHint {
                            Text(hint)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if let reasons = content.delayReasons { DelayNote(text: reasons) }
                    if let updated = content.updated {
                        Text("Updated \(updated, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 320, alignment: .leading)
    }

    /// Says how to set whichever mark is still missing; gone once both are set.
    private var markHint: String? {
        let start = content.stops.contains { $0.isStart }
        let exit = content.stops.contains { $0.isExit }
        switch (start, exit) {
        case (false, false): return "Click a stop behind you to mark where you got on, one ahead for where you get off."
        case (false, true): return "Click a stop behind you to mark where you got on."
        case (true, false): return "Click a stop ahead to mark where you get off."
        case (true, true): return nil
        }
    }
}

private struct TrainHeader: View {
    let content: MenuContent

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(content.train).font(.headline)
                    if let destination = content.destination {
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(destination).font(.headline).lineLimit(1)
                    }
                }
                HStack(spacing: 6) {
                    Text(content.detail)
                    if let wifi = content.wifi { WifiBadge(level: wifi) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(content.speed ?? 0)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/h").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct WifiBadge: View {
    let level: String

    var body: some View {
        let good = level == "high"
        Image(systemName: good ? "wifi" : level == "unstable" || level == "weak" ? "wifi.exclamationmark" : "wifi.slash")
            .foregroundStyle(good ? Color.secondary : .orange)
            .help("WiFi \(level)")
    }
}

private struct StopCardView: View {
    let card: MenuContent.StopCard
    let title: String
    let isExit: Bool

    var body: some View {
        let next = card
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if isExit {
                    Image(systemName: "figure.walk.departure").foregroundStyle(Color.accent)
                }
                Text(isExit && title == "Next stop" ? "Next stop · you get off here" : title)
                    .foregroundStyle(isExit ? Color.accent : .secondary)
                Spacer()
                if let eta = next.eta {
                    Text(eta).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            HStack(alignment: .firstTextBaseline) {
                Text(next.name).font(.title3.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 8)
                if let platform = next.platform {
                    Badge(text: "Gl. \(platform)", color: next.platformWas == nil ? .secondary : .orange)
                        .help(next.platformWas.map { "Changed from platform \($0)" } ?? "Platform")
                }
            }
            HStack(spacing: 6) {
                if let time = next.time {
                    Text(time).font(.body.weight(.medium)).monospacedDigit()
                }
                DelayBadge(delay: next.delay)
                Spacer()
                Text(next.distance).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isExit ? Color.accent.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }
}

/// The whole route as one line: travelled part in the accent color, a dot per stop, a larger
/// ring on your stop. The figures below count toward your stop when one is marked.
private struct RouteBar: View {
    let content: MenuContent

    var body: some View {
        let progress = content.progress
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 4)
                    // Travelled before you got on: faint. Your part so far: full accent.
                    Capsule().fill(Color.accent.opacity(content.hasStart ? 0.3 : 1))
                        .frame(width: max(4, w * progress), height: 4)
                    if content.hasStart {
                        Capsule().fill(Color.accent)
                            .frame(width: max(0, w * (progress - content.startFraction)), height: 4)
                            .offset(x: w * content.startFraction)
                    }
                    ForEach(content.stops) { stop in
                        // Kept inside the bar, so a ring on the first or last stop is not cut off.
                        let r: Double = stop.isStart || stop.isExit ? 7 : 4
                        StopDot(stop: stop, reached: stop.fraction <= progress)
                            .offset(x: min(max(0, w * stop.fraction - r), w - 2 * r))
                    }
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            HStack {
                Text(content.progressText ?? "")
                Spacer()
                Text([content.remainingText, "\(content.journeyPercent) %"].compactMap { $0 }.joined(separator: " · "))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
}

private struct StopDot: View {
    let stop: MenuContent.StopRow
    let reached: Bool

    var body: some View {
        if stop.isStart || stop.isExit {
            Circle()
                .fill(reached ? Color.accent : Color(nsColor: .controlBackgroundColor))
                .overlay(Circle().strokeBorder(Color.accent, lineWidth: 3))
                .frame(width: 14, height: 14)
        } else {
            Circle()
                .fill(reached ? Color.accent : Color(nsColor: .controlBackgroundColor))
                .overlay(Circle().strokeBorder(reached ? Color.accent : Color.secondary.opacity(0.5), lineWidth: 1.5))
                .frame(width: 8, height: 8)
        }
    }
}

/// Stop list as a vertical timeline: dots joined by a line, the next stop emphasised.
private struct StopTimeline: View {
    let stops: [MenuContent.StopRow]
    let hovered: String?
    let onHover: (String?) -> Void
    let onClick: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                StopRowView(
                    stop: stop, first: i == 0, last: i == stops.count - 1,
                    hovered: hovered == stop.id, onHover: onHover, onClick: onClick)
            }
        }
        .padding(.horizontal, -4)
    }

    static func marker(_ stop: MenuContent.StopRow, first: Bool, last: Bool) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(first ? .clear : lineColor(stop, upper: true)).frame(width: 2)
                Rectangle().fill(last ? .clear : lineColor(stop, upper: false)).frame(width: 2)
            }
            switch stop.state {
            case .passed:
                Circle().fill(Color.accent.opacity(0.55)).frame(width: 7, height: 7)
            case .next:
                Circle().fill(Color.accent).frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(.background, lineWidth: 2))
            case .upcoming:
                Circle().strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1.5)
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 12, height: 22)
    }

    // The line into a stop is "travelled" for passed and next stops; out of it only for passed ones.
    static func lineColor(_ stop: MenuContent.StopRow, upper: Bool) -> Color {
        let travelled = upper ? stop.state != .upcoming : stop.state == .passed
        return travelled ? Color.accent.opacity(0.55) : Color.secondary.opacity(0.25)
    }
}

/// One stop. Click a stop behind you to mark where you got on, one ahead for where you get off.
private struct StopRowView: View {
    let stop: MenuContent.StopRow
    let first: Bool
    let last: Bool
    let hovered: Bool
    let onHover: (String?) -> Void
    let onClick: (String) -> Void

    private var marked: Bool { stop.isStart || stop.isExit }

    private var nameColor: Color {
        if marked { return .accent }
        return stop.state == .passed ? .secondary : .primary
    }

    private var hint: String {
        if marked { return "Click to clear" }
        return stop.state == .passed ? "Click to mark where you got on" : "Click to mark where you get off"
    }

    var body: some View {
        HStack(spacing: 8) {
            StopTimeline.marker(stop, first: first, last: last)
            Text(stop.time)
                .monospacedDigit()
                .frame(width: 40, alignment: .leading)
            // ZStack keeps the column width when there is no delay to show.
            ZStack(alignment: .leading) {
                Color.clear
                DelayBadge(delay: stop.delay, compact: true)
            }
            .frame(width: 26)
            Text(stop.name).lineLimit(1).foregroundStyle(nameColor)
            if stop.isStart {
                Image(systemName: "figure.walk.arrival")
                    .foregroundStyle(Color.accent)
                    .accessibilityLabel("Where you got on")
            }
            if stop.isExit {
                Image(systemName: "figure.walk.departure")
                    .foregroundStyle(Color.accent)
                    .accessibilityLabel("Where you get off")
            }
            Spacer(minLength: 4)
            if let platform = stop.platform {
                Text("Gl. \(platform)").foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .font(stop.state == .next || marked ? .callout.weight(.semibold) : .callout)
        .foregroundStyle(stop.state == .passed ? Color.secondary : Color.primary)
        .frame(height: 22)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 5).fill(hovered ? Color.primary.opacity(0.07) : Color.clear))
        .contentShape(Rectangle())
        .onHover { inside in onHover(inside ? stop.id : nil) }
        .onTapGesture { onClick(stop.id) }
        .help(hint)
    }
}

private struct DelayBadge: View {
    let delay: String?
    var compact = false

    var body: some View {
        if let delay {
            let minutes = Int(delay.replacingOccurrences(of: "+", with: "")) ?? 0
            let color: Color = minutes >= 5 ? .red : minutes > 0 ? .orange : .green
            if compact {
                Text(delay).font(.caption.weight(.medium)).foregroundStyle(color).monospacedDigit()
            } else {
                Badge(text: delay, color: color)
            }
        } else if !compact {
            Badge(text: "on time", color: .green)
        }
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct DelayNote: View {
    let text: String

    var body: some View {
        Label {
            Text(text).lineLimit(2)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct OfflineView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Not on ICE WiFi").font(.headline)
            Text("Connect to WIFIonICE and the speed appears in the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

extension Color {
    /// Bordbar's accent instead of the system blue: a green with high contrast on both panel
    /// backgrounds (emerald 400 on dark, 8.7:1; emerald 700 on light, 5.5:1).
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0x34 / 255, green: 0xD3 / 255, blue: 0x99 / 255, alpha: 1)
            : NSColor(srgbRed: 0x04 / 255, green: 0x78 / 255, blue: 0x57 / 255, alpha: 1)
    })
}
