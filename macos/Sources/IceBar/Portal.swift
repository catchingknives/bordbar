import Foundation

// The ICE onboard portal API. Undocumented; field notes in ../../API.md.

struct Status: Decodable {
    let speed: Double
    let gpsStatus: String?
    let internet: String?
    let series: String?
    let tzn: String?
    let trainType: String?
    let wagonClass: String?
}

struct TripResponse: Decodable {
    let trip: Trip
}

struct Trip: Decodable {
    let tripDate: String?
    let trainType: String?
    let vzn: String?
    let totalDistance: Double
    let distanceFromLastStop: Double?
    let stopInfo: StopInfo
    let stops: [Stop]
}

struct StopInfo: Decodable {
    let actualNext: String?
    let actualLast: String?
    let finalStationName: String?
}

struct Stop: Decodable {
    struct Station: Decodable { let evaNr: String; let name: String }
    struct Timetable: Decodable {
        let scheduledArrivalTime: Double?
        let actualArrivalTime: Double?
        let scheduledDepartureTime: Double?
        let actualDepartureTime: Double?
        let arrivalDelay: String?
        let departureDelay: String?
    }
    struct Track: Decodable { let scheduled: String?; let actual: String? }
    struct Info: Decodable { let passed: Bool?; let distanceFromStart: Double }
    struct DelayReason: Decodable { let text: String? }

    let station: Station
    let timetable: Timetable
    let track: Track
    let info: Info
    let delayReasons: [DelayReason]?
}

/// Where portal JSON comes from: the train, or saved responses for working off the train.
enum PortalSource {
    case live
    case fixtures(URL)

    var isFixtures: Bool {
        switch self {
        case .live: return false
        case .fixtures: return true
        }
    }

    private static let base = URL(string: "https://iceportal.de/api1/rs/")!

    // Off ICE WiFi the host does not resolve or hangs; on it, a single request can take 4 s+.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    func status() async throws -> Status {
        try await load(Status.self, live: "status", fixture: "status.json")
    }

    func trip() async throws -> Trip {
        try await load(TripResponse.self, live: "tripInfo/trip", fixture: "trip.json").trip
    }

    private func load<T: Decodable>(_ type: T.Type, live path: String, fixture: String) async throws -> T {
        let data: Data
        switch self {
        case .live:
            let (body, response) = try await Self.session.data(from: Self.base.appendingPathComponent(path))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            data = body
        case .fixtures(let dir):
            data = try Data(contentsOf: dir.appendingPathComponent(fixture))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
