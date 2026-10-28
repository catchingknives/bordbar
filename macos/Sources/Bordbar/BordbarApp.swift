import AppKit
import Observation
import SwiftUI

@main
enum Entry {
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--fixtures"), i + 1 < args.count {
            Store.source = .fixtures(URL(fileURLWithPath: args[i + 1]))
        }
        // Test paths, no menu bar: `--once` prints the menu contents,
        // `--render <dir>` writes the menu panel as light and dark PNGs.
        if args.contains("--once") || args.contains("--render") {
            Task { @MainActor in
                await Store.shared.refresh()
                // `--click <evaNr>`: the same toggle a click in the menu runs.
                if let i = args.firstIndex(of: "--click"), i + 1 < args.count {
                    Store.shared.toggleMark(args[i + 1])
                }
                if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
                    renderPanel(Store.shared.content, to: URL(fileURLWithPath: args[i + 1]))
                } else {
                    Store.shared.content.printed()
                }
                exit(0)
            }
            // ImageRenderer hangs without a running NSApplication; .prohibited keeps it invisible.
            NSApplication.shared.setActivationPolicy(.prohibited)
            NSApplication.shared.run()
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    @MainActor
    private static func renderPanel(_ content: MenuContent, to dir: URL) {
        for (name, scheme) in [("light", ColorScheme.light), ("dark", .dark)] {
            let view = MenuPanel(content: content, onStopClick: { _ in })
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            let url = dir.appendingPathComponent("bordbar-menu-\(name).png")
            try? png.write(to: url)
            print(url.path)
        }
    }
}

@MainActor
@Observable
final class Store {
    @ObservationIgnored static var source = PortalSource.live
    @ObservationIgnored static let shared = Store()

    private(set) var content = MenuContent.offline
    // Lives here rather than in SwiftUI @State: the @State macro needs Xcode's compiler
    // plugin, which Command Line Tools do not ship.
    var hoveredStop: String?
    @ObservationIgnored var onChange: (() -> Void)?
    /// Where you got on and where you get off, saved with the trip they belong to so they do
    /// not carry over to the next train. ("exitTrip" predates the start mark; it keys both.)
    @ObservationIgnored private var startStop = UserDefaults.standard.string(forKey: "startStop")
    @ObservationIgnored private var exitStop = UserDefaults.standard.string(forKey: "exitStop")
    @ObservationIgnored private var markTrip = UserDefaults.standard.string(forKey: "exitTrip")
    @ObservationIgnored private var status: Status?
    @ObservationIgnored private var trip: Trip?
    @ObservationIgnored private var statusAt = Date()
    @ObservationIgnored private var tripAt = Date.distantPast
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var polling = false

    var online: Bool { status != nil }

    func refresh() async {
        do {
            status = try await Self.source.status()
            statusAt = Date()
            failures = 0
        } catch {
            // Train WiFi drops single requests; keep the last reading through a few misses.
            failures += 1
            if failures >= 3 || Store.source.isFixtures { status = nil; trip = nil }
        }
        if online, trip == nil || Date().timeIntervalSince(tripAt) > 30 {
            trip = try? await Self.source.trip()
            tripAt = Date()
        }
        render()
    }

    func render() {
        let current = trip.map(Self.tripKey) == markTrip
        content = status.map {
            .make(status: $0, trip: trip, startStop: current ? startStop : nil,
                  exitStop: current ? exitStop : nil, now: Date(), updated: statusAt)
        } ?? .offline
        onChange?()
    }

    /// One click, no modes: a stop behind you marks where you got on, a stop ahead marks
    /// where you get off. Clicking a marked stop again clears it.
    func toggleMark(_ evaNr: String) {
        guard let trip, let stop = trip.stops.first(where: { $0.station.evaNr == evaNr }) else { return }
        if Self.tripKey(trip) != markTrip {
            startStop = nil
            exitStop = nil
            markTrip = Self.tripKey(trip)
        }
        // A marked stop clears whichever mark it holds; your exit, once passed, is behind you
        // but must not turn into a start mark.
        if startStop == evaNr {
            startStop = nil
        } else if exitStop == evaNr {
            exitStop = nil
        } else if stop.info.passed ?? false {
            startStop = evaNr
        } else {
            exitStop = evaNr
        }
        UserDefaults.standard.set(startStop, forKey: "startStop")
        UserDefaults.standard.set(exitStop, forKey: "exitStop")
        UserDefaults.standard.set(markTrip, forKey: "exitTrip")
        render()
    }

    private static func tripKey(_ trip: Trip) -> String {
        "\(trip.tripDate ?? "")/\(trip.trainType ?? "")\(trip.vzn ?? "")"
    }

    /// Speed every 3 s while on the train; a slow 15 s probe otherwise.
    func startPolling() {
        guard !polling else { return }
        polling = true
        Task {
            while true {
                await refresh()
                try? await Task.sleep(for: .seconds(online ? 3 : 15))
            }
        }
    }
}

/// Re-renders as the store changes, so an open menu keeps updating.
private struct LivePanel: View {
    let store: Store
    var body: some View {
        MenuPanel(content: store.content, hovered: store.hoveredStop,
                  onHover: { store.hoveredStop = $0 }, onStopClick: store.toggleMark)
    }
}

// AppKit status item rather than SwiftUI's MenuBarExtra: MenuBarExtra dropped both the
// menu bar symbol and the menu item images on macOS 27 (seen 2026-10-27).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let store = Store.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Template symbol, so the system tints it for light, dark and selected menu bars.
        let symbol = NSImage(systemSymbolName: "train.side.front.car", accessibilityDescription: "Bordbar")
        symbol?.isTemplate = true
        item.button?.image = symbol
        item.button?.imagePosition = .imageLeading
        // Fixed-width digits, so the item does not jiggle as the speed changes.
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)

        // A menu, not a popover: Apple's menu bar guideline (HIG, The menu bar, June 2025).
        // The rich content is a custom view inside a menu item; Quit stays a standard item.
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu

        store.onChange = { [weak self] in
            self?.item.button?.title = self?.store.content.title.map { " \($0)" } ?? ""
        }
        store.onChange?()
        store.startPolling()
    }

    // Rebuilt on every open, so the panel's height matches the current content.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let host = NSHostingView(rootView: LivePanel(store: store))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let panel = NSMenuItem()
        panel.view = host
        menu.addItem(panel)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Bordbar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }
}
