import Foundation

/// Everything the menu bar shows, worked out from the two portal responses.
/// Pure, so `Bordbar --once` prints exactly what the menu renders.
struct MenuContent {
    /// A stop worth a card: the next one, and the one you marked to get off at.
    struct StopCard {
        let id: String
        let name: String
        let time: String?
        let delay: String?        // "+5", nil when on time or unknown
        let platform: String?
        let platformWas: String?  // set when the platform changed
        let eta: String?          // "in 25 min"
        let distance: String      // "87 km"
    }

    enum StopState { case passed, next, upcoming }

    struct StopRow: Identifiable {
        let id: String
        let time: String
        let delay: String?
        let name: String
        let platform: String?
        let state: StopState
        let fraction: Double      // position along the route, 0...1
        let isStart: Bool
        let isExit: Bool
    }

    var speed: Int?               // nil when not on ICE WiFi
    var train = ""
    var destination: String?
    var detail = ""
    var wifi: String?
    var next: StopCard?
    var exit: StopCard?           // nil when unmarked or already passed
    var progress = 0.0
    var startFraction = 0.0       // where your part of the route begins on the bar
    var hasStart = false
    var progressText: String?
    var remainingText: String?
    var journeyPercent = 0
    var stops: [StopRow] = []
    var delayReasons: String?
    var updated: Date?

    var title: String? { speed.map { "\($0) km/h" } }

    static let offline = MenuContent()

    static func make(status: Status, trip: Trip?, startStop: String? = nil, exitStop: String? = nil,
                     now: Date, updated: Date) -> MenuContent {
        var c = MenuContent()
        c.speed = Int(status.speed.rounded())
        c.updated = updated
        c.train = [trip?.trainType ?? status.trainType, trip?.vzn].compactMap { $0 }.joined(separator: " ")
        c.destination = trip?.stopInfo.finalStationName
        c.detail = [
            status.series.map { "BR \($0)" },
            status.wagonClass == "FIRST" ? "1st class" : "2nd class",
        ].compactMap { $0 }.joined(separator: " · ")
        c.wifi = status.internet?.lowercased()

        guard let trip, trip.totalDistance > 0 else { return c }
        let pos = position(in: trip)
        // The bar always draws the whole route; the numbers cover your part of it: from where
        // you got on (else the first stop) to where you get off (else the terminus). They stay
        // on your stop after the train passes it, at 100 %, instead of jumping to the terminus
        // while you step off.
        let total = trip.totalDistance
        let from = trip.stops.first { $0.station.evaNr == startStop }?.info.distanceFromStart ?? 0
        let exitEntry = trip.stops.first { $0.station.evaNr == exitStop && $0.info.distanceFromStart > from }
        let to = exitEntry?.info.distanceFromStart ?? total
        let journey = max(1, to - from)
        let travelled = min(journey, max(0, pos - from))
        c.progress = pos / total
        c.startFraction = from / total
        c.hasStart = startStop != nil && from > 0
        // Truncated, so 100 % means arrived, not 2 km out.
        c.journeyPercent = Int(travelled / journey * 100)
        c.progressText = "\(km(travelled)) of \(km(journey))"
        c.remainingText = "\(km(max(0, to - pos))) to go"

        func card(_ s: Stop) -> StopCard {
            let at = arrival(s)
            let (platform, was) = platforms(s)
            return StopCard(
                id: s.station.evaNr,
                name: s.station.name,
                time: at.map(hhmm),
                delay: nonEmpty(s.timetable.arrivalDelay),
                platform: platform,
                platformWas: was,
                eta: at.map { minutes(until: $0, now: now) },
                distance: km(max(0, s.info.distanceFromStart - pos)))
        }
        c.next = trip.stops.first { $0.station.evaNr == trip.stopInfo.actualNext }.map(card)
        // The card goes once the train has moved on past your stop. Decided by position, not the
        // portal's `passed` flag, which can flip while the train still stands at the platform.
        c.exit = exitEntry.flatMap { $0.info.distanceFromStart >= pos ? card($0) : nil }

        c.stops = trip.stops.map { s in
            let tt = s.timetable
            return StopRow(
                id: s.station.evaNr,
                time: (tt.scheduledArrivalTime ?? tt.scheduledDepartureTime).map { hhmm(date($0)) } ?? "–",
                delay: nonEmpty(tt.arrivalDelay) ?? nonEmpty(tt.departureDelay),
                name: s.station.name,
                platform: platforms(s).0,
                state: s.station.evaNr == trip.stopInfo.actualNext ? .next : (s.info.passed ?? false) ? .passed : .upcoming,
                fraction: s.info.distanceFromStart / total,
                isStart: s.station.evaNr == startStop,
                isExit: s.station.evaNr == exitStop)
        }

        let reasons = trip.stops.flatMap { $0.delayReasons ?? [] }.compactMap(\.text)
        if !reasons.isEmpty {
            c.delayReasons = NSOrderedSet(array: reasons).array.compactMap { $0 as? String }.joined(separator: "; ")
        }
        return c
    }

    // The portal's own actualPosition lags badly (API.md); the last stop's offset plus the
    // distance travelled since it does not.
    static func position(in trip: Trip) -> Double {
        let last = trip.stops.first { $0.station.evaNr == trip.stopInfo.actualLast }
        let next = trip.stops.first { $0.station.evaNr == trip.stopInfo.actualNext }
        var pos = (last?.info.distanceFromStart ?? 0) + (trip.distanceFromLastStop ?? 0)
        if let next { pos = min(pos, next.info.distanceFromStart) }
        return min(pos, trip.totalDistance)
    }

    private static func arrival(_ s: Stop) -> Date? {
        let tt = s.timetable
        return (tt.actualArrivalTime ?? tt.scheduledArrivalTime ?? tt.actualDepartureTime ?? tt.scheduledDepartureTime).map(date)
    }

    /// Current platform, plus the scheduled one when it changed.
    private static func platforms(_ s: Stop) -> (String?, String?) {
        let actual = nonEmpty(s.track.actual), scheduled = nonEmpty(s.track.scheduled)
        if let actual, let scheduled, actual != scheduled { return (actual, scheduled) }
        return (actual ?? scheduled, nil)
    }

    private static func minutes(until at: Date, now: Date) -> String {
        let mins = Int((at.timeIntervalSince(now) / 60).rounded())
        if mins <= 0 { return "arriving" }
        return mins < 60 ? "in \(mins) min" : "in \(mins / 60) h \(mins % 60) min"
    }

    private static func nonEmpty(_ s: String?) -> String? { (s?.isEmpty ?? true) ? nil : s }
    private static func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }
    private static func hhmm(_ d: Date) -> String { hourMinute.string(from: d) }
    static func km(_ m: Double) -> String { m < 10_000 ? String(format: "%.1f km", m / 1000) : "\(Int((m / 1000).rounded())) km" }

    private static let hourMinute: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
}

extension MenuContent {
    func printed() {
        print("MENU BAR: \(title ?? "(symbol only)")")
        guard speed != nil else { print("Not on ICE WiFi"); return }
        print("\(train) → \(destination ?? "?")  |  \(detail)  |  WiFi \(wifi ?? "?")")
        if let n = next {
            print("NEXT: \(n.name)  \(n.time ?? "–") \(n.delay ?? "")  Gl. \(n.platform ?? "–")\(n.platformWas.map { " (was \($0))" } ?? "")  \(n.eta ?? "")  \(n.distance)")
        }
        if let e = exit { print("EXIT: \(e.name)  \(e.time ?? "–") \(e.delay ?? "")  Gl. \(e.platform ?? "–")  \(e.eta ?? "")  \(e.distance)") }
        print("PROGRESS: bar \(Int((progress * 100).rounded()))%  journey \(journeyPercent)%  \(progressText ?? "")  \(remainingText ?? "")")
        for s in stops { print("  [\(s.state)\(s.isStart ? ",START" : "")\(s.isExit ? ",EXIT" : "")] \(s.time) \(s.delay ?? "  ") \(s.name)  Gl. \(s.platform ?? "–")  @\(String(format: "%.2f", s.fraction))") }
        if let delayReasons { print("DELAY: \(delayReasons)") }
    }
}
