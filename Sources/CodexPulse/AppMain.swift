#if os(macOS)
import AppKit
import SwiftUI

@main
struct CodexWickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = MonitorModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(monitor)
        } label: {
            Label(
                monitor.menuTitle,
                systemImage: monitor.anomaly.severity.rawValue > 0
                    ? "exclamationmark.triangle.fill"
                    : "flame"
            )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let monitor = MonitorModel.shared
        monitor.start()
        HUDController.shared.show(monitor: monitor)
    }
}

private struct MenuBarView: View {
    @EnvironmentObject private var monitor: MonitorModel

    var body: some View {
        if let balance = monitor.current?.creditBalance {
            Text("Credits: \(NumberFormat.credits(balance))")
        } else {
            Text("Credits: —")
        }

        if let weekly = monitor.current?.weeklyUsedPercent {
            Text(String(format: "Weekly remaining: %.0f%%", max(0, 100 - weekly)))
        }

        Text("Status: \(monitor.anomaly.headline)")
        Divider()

        Button("Open Details") {
            HUDController.shared.openDashboard(monitor: monitor)
        }

        Button(monitor.hudVisible ? "Hide Floating Wick" : "Show Floating Wick") {
            monitor.hudVisible.toggle()
            monitor.saveSettings()
        }

        Button("Refresh Now") {
            Task { await monitor.refresh() }
        }

        Divider()

        Button("Quit Codex Wick") {
            NSApplication.shared.terminate(nil)
        }
    }
}
#else
import Foundation

@main
struct CodexWickApp {
    static func main() {
        print("Codex Wick is a macOS application. Core checks can run on this platform.")
    }
}
#endif
