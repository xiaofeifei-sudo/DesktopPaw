import Foundation
import CoreGraphics
import AppKit

public final class InputSyncService: InputSyncServicing, @unchecked Sendable {
    private var config: InputSyncConfig
    private let mapper: InputEventMapper
    private let quietModePolicyProvider: (() -> (any QuietModeEvaluating)?)?
    private let companionPreferencesProvider: (() -> CompanionPreferences?)?
    private let analysisInterval: TimeInterval = 1.5

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var analysisTimer: Timer?
    private var keyboardEventCount: Int = 0
    private var mouseEventCount: Int = 0
    private var lastAnalysisNow: Date = Date()
    private var previousRhythm: InputEventMapper.RhythmResult = .idle
    private var isRunning = false

    public var isEnabled: Bool { isRunning }
    public var onInputEvent: (@Sendable (InputSyncEvent) -> Void)?

    public init(
        config: InputSyncConfig = .default,
        quietModePolicyProvider: (() -> (any QuietModeEvaluating)?)? = nil,
        companionPreferencesProvider: (() -> CompanionPreferences?)? = nil
    ) {
        self.config = config
        self.mapper = InputEventMapper()
        self.quietModePolicyProvider = quietModePolicyProvider
        self.companionPreferencesProvider = companionPreferencesProvider
    }

    deinit {
        stop()
    }

    public func start(config: InputSyncConfig) throws {
        stop()
        self.config = config

        guard config.isEnabled else { return }

        guard AXIsProcessTrusted() else {
            throw InputSyncError.accessibilityPermissionDenied
        }

        let eventMask = buildEventMask(config: config)
        guard eventMask != 0 else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<InputSyncService>.fromOpaque(refcon).takeUnretainedValue()
                service.handleEventTap(type: type)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            throw InputSyncError.eventTapCreationFailed
        }

        eventTap = tap

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        isRunning = true
        startAnalysisTimer()
    }

    public func stop() {
        isRunning = false

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        analysisTimer?.invalidate()
        analysisTimer = nil
        keyboardEventCount = 0
        mouseEventCount = 0
        previousRhythm = .idle
    }

    public func updateConfig(_ config: InputSyncConfig) {
        let wasEnabled = isRunning
        self.config = config

        if config.isEnabled, !wasEnabled {
            do {
                try start(config: config)
            } catch {
                self.config.isEnabled = false
            }
        } else if !config.isEnabled, wasEnabled {
            stop()
        } else if isRunning {
            restartTapIfNeeded()
        }
    }

    private func buildEventMask(config: InputSyncConfig) -> CGEventMask {
        var mask: CGEventMask = 0
        if config.trackKeyboard {
            mask |= (1 << CGEventType.keyDown.rawValue)
        }
        if config.trackMouse {
            mask |= (1 << CGEventType.mouseMoved.rawValue)
            mask |= (1 << CGEventType.leftMouseDragged.rawValue)
            mask |= (1 << CGEventType.rightMouseDragged.rawValue)
            mask |= (1 << CGEventType.otherMouseDragged.rawValue)
        }
        return mask
    }

    private func restartTapIfNeeded() {
        let wasRunning = isRunning
        if wasRunning {
            stop()
        }
        if config.isEnabled {
            try? start(config: config)
        }
    }

    private func startAnalysisTimer() {
        analysisTimer?.invalidate()
        lastAnalysisNow = Date()
        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            self?.performAnalysis()
        }
    }

    private func handleEventTap(type: CGEventType) {
        switch type {
        case .keyDown:
            keyboardEventCount += 1
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            mouseEventCount += 1
        default:
            break
        }
    }

    private func performAnalysis() {
        guard isRunning else { return }

        let now = Date()
        let kbdCount = keyboardEventCount
        let msCount = mouseEventCount
        keyboardEventCount = 0
        mouseEventCount = 0

        if let policyProvider = quietModePolicyProvider,
           let policy = policyProvider(),
           let preferences = companionPreferencesProvider?(),
           config.respectQuietMode {
            let state = policy.quietState(preferences: preferences, at: now)
            if state != .inactive {
                previousRhythm = .idle
                return
            }
        }

        let rhythm = mapper.classify(
            keyboardCount: kbdCount,
            mouseCount: msCount,
            intensity: config.syncIntensity,
            now: now
        )

        let edge = mapper.edgeChange(current: rhythm, previous: previousRhythm)
        previousRhythm = rhythm

        if edge.keyboardBecameActive {
            onInputEvent?(.keyboardActivity)
        } else if edge.mouseBecameActive {
            onInputEvent?(.mouseActivity)
        } else if edge.becameIdle {
            onInputEvent?(.idle)
        }
    }
}
