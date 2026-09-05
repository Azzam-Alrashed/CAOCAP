//
//  caocapApp.swift
//  caocap
//
//  Created by Azzam Alrashed on 18/08/2026.
//

import AppKit
import SwiftUI

/// Keeps the process alive after the last window closes so the status item stays in the menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .showMainWindow, object: nil)
        }
        return true
    }
}

extension Notification.Name {
    static let showMainWindow = Notification.Name("caocap.showMainWindow")
}

@main
struct caocapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }

        // Status item on the right side of the menu bar. Separate from the Dock app icon.
        MenuBarExtra {
            StatusItemMenu()
        } label: {
            StatusItemLabel()
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Always-on label so Dock reopen can restore the window even when the menu is closed.
private struct StatusItemLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .accessibilityLabel("CAOCAP")
            .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
                openWindow(id: "main")
                NSApp.activate()
            }
    }
}

/// Menu shown when the status item is clicked.
private struct StatusItemMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open CAOCAP") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Divider()
        Button("Quit CAOCAP") {
            NSApp.terminate(nil)
        }
    }
}
