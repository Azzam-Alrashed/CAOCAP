import AppKit
import Observation

/// Owns the companion panel for the process lifetime: wake, tuck, drag, and persistence.
@MainActor
@Observable
final class CompanionController {
    private(set) var isAwake: Bool
    private(set) var origin: NSPoint
    private(set) var persona: CompanionPersona
    private(set) var isDragging = false
    private(set) var mood: CompanionMood = .idle

    @ObservationIgnored
    private var panel: CompanionPanel?
    @ObservationIgnored
    private var screenObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        if defaults.object(forKey: CompanionDefaults.isAwake) == nil {
            isAwake = true
        } else {
            isAwake = defaults.bool(forKey: CompanionDefaults.isAwake)
        }

        if defaults.object(forKey: CompanionDefaults.originX) != nil {
            origin = NSPoint(
                x: defaults.double(forKey: CompanionDefaults.originX),
                y: defaults.double(forKey: CompanionDefaults.originY)
            )
        } else {
            origin = Self.defaultOrigin()
        }

        if let raw = defaults.string(forKey: CompanionDefaults.persona),
           let stored = CompanionPersona(rawValue: raw) {
            persona = stored
        } else {
            persona = .cocaptain
        }
    }

    func install() {
        guard panel == nil else { return }
        let panel = CompanionPanel(
            rootView: CompanionView(controller: self),
            onDragBegan: { [weak self] in
                self?.beginDrag()
            },
            onDragEnded: { [weak self] didMove in
                self?.endDrag(didMove: didMove)
            }
        )
        self.panel = panel
        origin = clamp(origin)
        panel.setFrameOrigin(origin)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reclampToScreens()
            }
        }

        if isAwake {
            panel.orderFrontRegardless()
        }
    }

    func setAwake(_ awake: Bool) {
        isAwake = awake
        UserDefaults.standard.set(awake, forKey: CompanionDefaults.isAwake)
        guard let panel else { return }
        if awake {
            origin = clamp(origin)
            panel.setFrameOrigin(origin)
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func toggleAwake() {
        setAwake(!isAwake)
    }

    func setPersona(_ persona: CompanionPersona) {
        self.persona = persona
        UserDefaults.standard.set(persona.rawValue, forKey: CompanionDefaults.persona)
        if !isAwake {
            setAwake(true)
        }
    }

    func beginDrag() {
        isDragging = true
    }

    func endDrag(didMove: Bool) {
        isDragging = false
        if didMove {
            let current = panel?.frame.origin ?? origin
            let clamped = clamp(current)
            origin = clamped
            if let panel, clamped != current {
                panel.setFrame(NSRect(origin: clamped, size: CompanionLayout.panelSize), display: true, animate: true)
            } else {
                panel?.setFrameOrigin(clamped)
            }
            persistOrigin()
        } else {
            origin = panel?.frame.origin ?? origin
            openMainWindow()
        }
    }

    func persistOrigin() {
        let stored = clamp(origin)
        origin = stored
        UserDefaults.standard.set(stored.x, forKey: CompanionDefaults.originX)
        UserDefaults.standard.set(stored.y, forKey: CompanionDefaults.originY)
    }

    func openMainWindow() {
        if MainWindowFocus.focusExisting() { return }
        NotificationCenter.default.post(name: .showMainWindow, object: nil)
        NSApp.activate()
    }

    private func reclampToScreens() {
        origin = clamp(origin)
        panel?.setFrameOrigin(origin)
        persistOrigin()
    }

    private func clamp(_ point: NSPoint) -> NSPoint {
        let size = CompanionLayout.panelSize
        let screen = Self.screen(containing: NSRect(origin: point, size: size))
        let visible = screen.visibleFrame
        let inset = CompanionLayout.screenInset
        let minX = visible.minX + inset
        let minY = visible.minY + inset
        let maxX = max(minX, visible.maxX - size.width - inset)
        let maxY = max(minY, visible.maxY - size.height - inset)
        return NSPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    private static func defaultOrigin() -> NSPoint {
        let size = CompanionLayout.panelSize
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        return NSPoint(
            x: visible.maxX - size.width - CompanionLayout.screenInset,
            y: visible.minY + CompanionLayout.screenInset
        )
    }

    private static func screen(containing rect: NSRect) -> NSScreen {
        if let hit = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) {
            return hit
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
