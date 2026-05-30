import Foundation

struct ForbiddenPattern {
    let label: String
    let pattern: String
    let allowedFileNames: Set<String>

    init(label: String, pattern: String, allowedFileNames: Set<String> = []) {
        self.label = label
        self.pattern = pattern
        self.allowedFileNames = allowedFileNames
    }
}

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceRoots = [
    rootURL.appendingPathComponent("Sources/DesktopPet"),
    rootURL.appendingPathComponent("Sources/DesktopPetApp")
]
let actionSourceRoot = rootURL.appendingPathComponent("Sources/DesktopPet/PetActions")
let actionPackSourceRoot = rootURL.appendingPathComponent("Sources/DesktopPet/ActionPacks")
let petCoreSourceRoot = rootURL.appendingPathComponent("Sources/DesktopPet/PetCore")
let packagingInfoPlist = rootURL.appendingPathComponent("Packaging/Info.plist")
let actionModelURL = rootURL.appendingPathComponent("Sources/DesktopPet/PetActions/Action.swift")
let actionTagURL = rootURL.appendingPathComponent("Sources/DesktopPet/PetActions/ActionTag.swift")
let actionEditorViewModelURL = rootURL.appendingPathComponent("Sources/DesktopPet/UI/ActionEditorViewModel.swift")
let importWizardViewModelURL = rootURL.appendingPathComponent("Sources/DesktopPet/UI/ImportWizardViewModel.swift")
let actionOverrideStoreURL = rootURL.appendingPathComponent("Sources/DesktopPet/PetLibrary/PetActionOverrideStore.swift")
let actionFeatureSourceURLs = [
    rootURL.appendingPathComponent("Sources/DesktopPet/App/ActionTriggerService.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/App/ActionsMenuBuilder.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/App/MenuBarController.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/App/PetContextMenuBuilder.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/AfterTagState.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/IdleScheduleContext.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/MoodSnapshotProvider.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/PetEngine.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/TagConditionEvaluator.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/WeightedActionSampler.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetLibrary/ManifestRewriter.swift"),
    actionOverrideStoreURL,
    rootURL.appendingPathComponent("Sources/DesktopPet/PetWindow/PetWindowController.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/UI/ActionEditorViewModel.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/UI/ActionLibraryViewModel.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/UI/ImportWizardViewModel.swift")
] + swiftFiles(under: actionSourceRoot)
let phase3TagDeclarativeSourceURLs = [
    actionModelURL,
    actionTagURL,
    rootURL.appendingPathComponent("Sources/DesktopPet/PetActions/PetActionCatalogBuilder.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetActions/PetActionOverride.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/AfterTagState.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/IdleScheduleContext.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/MoodSnapshotProvider.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/PetEngine.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/TagConditionEvaluator.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/WeightedActionSampler.swift")
]
let phase3ConditionSourceURLs = [
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/AfterTagState.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/IdleScheduleContext.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/MoodLevelClassifier.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/MoodSnapshotProvider.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/PetEngine.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/TagConditionEvaluator.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/TimeOfDayClassifier.swift"),
    rootURL.appendingPathComponent("Sources/DesktopPet/PetCore/WeightedActionSampler.swift")
] + swiftFiles(under: actionSourceRoot)

let aiCompanionSourceRoot = rootURL.appendingPathComponent("Sources/DesktopPet/AICompanion")
let aiVisualSourceRoot = rootURL.appendingPathComponent("Sources/DesktopPet/AIVisualAction")
let aiVisualGenSourceRoot = rootURL.appendingPathComponent("Sources/DesktopPet/AIVisualGeneration")
let aiVisualAssetsSourceRoot = rootURL.appendingPathComponent("Sources/DesktopPet/AIVisualAssets")
let phase3AIIntegrationSourcePaths: Set<String> = [
    "Sources/DesktopPet/App/AppCommand.swift",
    "Sources/DesktopPet/App/AppCoordinator.swift",
    "Sources/DesktopPet/App/AppDelegate.swift",
    "Sources/DesktopPet/App/MenuBarController.swift",
    "Sources/DesktopPet/App/SettingsWindowController.swift",
    "Sources/DesktopPet/PetWindow/PetWindowController.swift",
    "Sources/DesktopPet/UI/AIChatInputView.swift",
    "Sources/DesktopPet/UI/AIChatPanelView.swift",
    "Sources/DesktopPet/UI/AIMemoryView.swift",
    "Sources/DesktopPet/UI/AISettingsView.swift",
    "Sources/DesktopPet/UI/AISettingsViewModel.swift",
    "Sources/DesktopPet/UI/AIVisualConfirmationView.swift",
    "Sources/DesktopPet/UI/AIVisualSettingsView.swift",
    "Sources/DesktopPet/UI/AIVisualSettingsViewModel.swift",
    "Sources/DesktopPet/UI/InteractiveBubbleSettingsView.swift",
    "Sources/DesktopPet/UI/MemoryAddView.swift",
    "Sources/DesktopPet/UI/MemoryListView.swift",
    "Sources/DesktopPet/UI/MemoryManagementView.swift",
    "Sources/DesktopPet/UI/SettingsView.swift"
]

let forbiddenImports = [
    ForbiddenPattern(label: "CloudKit cloud sync", pattern: #"import\s+CloudKit"#),
    ForbiddenPattern(label: "UserNotifications reminders", pattern: #"import\s+UserNotifications"#),
    ForbiddenPattern(label: "EventKit reminders", pattern: #"import\s+EventKit"#),
    ForbiddenPattern(label: "AVFoundation camera or microphone", pattern: #"import\s+AVFoundation"#),
    ForbiddenPattern(label: "Speech microphone", pattern: #"import\s+Speech"#),
    ForbiddenPattern(label: "ScriptingBridge or Apple Events", pattern: #"import\s+ScriptingBridge"#)
]

let forbiddenSourcePatterns = [
    ForbiddenPattern(label: "natural language chat", pattern: #"\b(chat|conversation|LLM|OpenAI)\b"#),
    ForbiddenPattern(label: "AI generation", pattern: #"\b(AI|MLModel|CoreML)\b"#),
    ForbiddenPattern(
        label: "cloud sync networking",
        pattern: #"\b(URLSession|URLRequest|HTTPURLResponse|NWConnection|CloudKit|NSUbiquitousKeyValueStore)\b"#,
        allowedFileNames: ["PetdexDownloader.swift"]
    ),
    ForbiddenPattern(label: "Petdex resource marketplace", pattern: #"\b(Marketplace|marketplace|PetdexBrowser|ResourceBrowser|Storefront)\b"#),
    ForbiddenPattern(label: "Petdex account or OAuth", pattern: #"\b(PetdexAccount|PetdexLogin|OAuth|ASWebAuthenticationSession)\b"#),
    ForbiddenPattern(label: "local file upload", pattern: #"\b(upload|Upload|multipart/form-data)\b"#),
    ForbiddenPattern(label: "background update checks", pattern: #"\b(BGTaskScheduler|automatic update|auto update|Sparkle)\b"#),
    ForbiddenPattern(label: "notification reminders", pattern: #"\b(UNUserNotificationCenter|NSUserNotification|Reminder|reminder)\b"#),
    ForbiddenPattern(
        label: "file picker outside dedicated wrappers",
        pattern: #"\b(NSOpenPanel|fileImporter|allowedContentTypes)\b"#,
        allowedFileNames: ["PetImageOpenPanel.swift", "PetPackageOpenPanel.swift", "PetdexPackageOpenPanel.swift", "AIMemoryExporter.swift", "ContentPackOpenPanel.swift", "ActionPackImageOpenPanel.swift"]
    ),
    ForbiddenPattern(label: "plugin execution", pattern: #"\b(plugin|Plugin|Process\.run|NSTask)\b"#, allowedFileNames: ["MiniMaxCLIClient.swift"]),
    ForbiddenPattern(label: "developer workflow status", pattern: #"\b(git status|CI|pull request|terminal|Terminal)\b"#),
    ForbiddenPattern(label: "accessibility permission", pattern: #"\b(AXIsProcessTrusted|kAXTrustedCheckOptionPrompt)\b"#),
    ForbiddenPattern(label: "screen capture permission", pattern: #"\b(SCGDisplay|CGDisplayStream|ScreenCaptureKit)\b"#),
    ForbiddenPattern(label: "camera or microphone permission", pattern: #"\b(AVCaptureDevice|AVAudioRecorder|NSSpeechRecognizer)\b"#),
    ForbiddenPattern(label: "Apple Events permission", pattern: #"\b(NSAppleEventDescriptor|NSAppleScript)\b"#)
]

let forbiddenPlistKeys = [
    "NSAppleEventsUsageDescription",
    "NSCameraUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSScreenCaptureDescription",
    "NSCalendarsUsageDescription",
    "NSRemindersUsageDescription"
]

let forbiddenActionModulePatterns = [
    ForbiddenPattern(label: "actions module networking", pattern: #"\b(URLSession|URLRequest|HTTPURLResponse|NWConnection|Network\.|import\s+Network)\b"#),
    ForbiddenPattern(label: "actions module executable field parsing", pattern: #"\b(script|command|executable|interpreter|shell|Process\.run|NSTask|NSAppleScript|ScriptingBridge)\b"#),
    ForbiddenPattern(label: "actions module permission request", pattern: #"\b(AXIsProcessTrusted|kAXTrustedCheckOptionPrompt|AVCaptureDevice|SCGDisplay|CGDisplayStream|UNUserNotificationCenter|EKEventStore)\b"#)
]

let forbiddenActionPackPatterns = [
    ForbiddenPattern(label: "action pack networking", pattern: #"\b(URLSession|URLRequest|HTTPURLResponse|NWConnection|NWListener|NWPathMonitor|Network\.|import\s+Network)\b"#),
    ForbiddenPattern(label: "action pack script execution", pattern: #"\b(script|command|executable|interpreter|shell|Process\.run|NSTask|NSAppleScript|ScriptingBridge|evaluateScript|eval\s*\()\b"#),
    ForbiddenPattern(label: "action pack permission request", pattern: #"\b(AXIsProcessTrusted|kAXTrustedCheckOptionPrompt|AVCaptureDevice|AVAudioRecorder|SCGDisplay|CGDisplayStream|ScreenCaptureKit|UNUserNotificationCenter|EKEventStore|NSAppleEventDescriptor|NSAppleScript)\b"#),
    ForbiddenPattern(label: "action pack dynamic code", pattern: #"\b(JavaScriptCore|JSContext|NSExpression|NSPredicate|dlopen|dlsym)\b"#)
]

let forbiddenTagExpressionPatterns = [
    ForbiddenPattern(label: "tag expression evaluator", pattern: #"\b(NSExpression|NSPredicate|JavaScriptCore|JSContext|evaluateScript|eval\s*\(|TagExpression|TriggerExpression|TriggerDSL|ActionDSL|DSL)\b"#),
    ForbiddenPattern(label: "tag executable hook", pattern: #"\b(script|scripts|executable|interpreter|shell|Process\.run|NSTask|NSAppleScript|ScriptingBridge)\b"#)
]

let forbiddenConditionIntegrationPatterns = [
    ForbiddenPattern(label: "weather condition integration", pattern: #"\b(WeatherKit|CLLocationManager|CLGeocoder|weather|Weather|天气)\b"#),
    ForbiddenPattern(label: "focus application condition integration", pattern: #"\b(NSWorkspace|frontmostApplication|activeApplication|FocusStatus|焦点)\b"#),
    ForbiddenPattern(label: "do-not-disturb condition integration", pattern: #"\b(DoNotDisturb|do\s*not\s*disturb|DND|FocusFilter|勿扰)\b"#),
    ForbiddenPattern(label: "battery condition integration", pattern: #"\b(IOPS|IOPower|Battery|battery|isLowPowerModeEnabled|电量)\b"#),
    ForbiddenPattern(label: "network listener condition integration", pattern: #"\b(NWPathMonitor|SCNetworkReachability|NWConnection|NWListener|import\s+Network|Network\.)\b"#)
]

let releaseActionScopePatterns = [
    ForbiddenPattern(label: "release actions networking", pattern: #"\b(URLSession|URLRequest|HTTPURLResponse|NWConnection|NWListener|NWPathMonitor|Network\.|import\s+Network)\b"#),
    ForbiddenPattern(label: "release actions permission request", pattern: #"\b(AXIsProcessTrusted|kAXTrustedCheckOptionPrompt|AVCaptureDevice|AVAudioRecorder|SCGDisplay|CGDisplayStream|ScreenCaptureKit|UNUserNotificationCenter|EKEventStore|NSAppleEventDescriptor|NSAppleScript)\b"#),
    ForbiddenPattern(label: "release actions trigger DSL", pattern: #"\b(NSExpression|NSPredicate|JavaScriptCore|JSContext|evaluateScript|eval\s*\(|TriggerExpression|TriggerDSL|ActionDSL|DSL)\b"#),
    ForbiddenPattern(label: "release actions executable field parsing", pattern: #"\b(scripts?|executable|interpreter|shell|Process\.run|NSTask|ScriptingBridge)\b"#)
]

let sourceFileURLs = sourceRoots.flatMap { swiftFiles(under: $0) }
expect(!sourceFileURLs.isEmpty, "scope validation should find Swift source files")

let requiredCustomPetFiles: Set<String> = [
    "PetLibraryStore.swift",
    "PetImageImporter.swift",
    "PetLibraryManifestWriter.swift",
    "PetImageOpenPanel.swift",
    "PetPackageImporter.swift",
    "PetPackageOpenPanel.swift",
    "SingleImageRenderer.swift",
    "PetMotionProvider.swift",
    "BubbleEngine.swift",
    "PetBubbleView.swift"
]
let sourceFileNames = Set(sourceFileURLs.map(\.lastPathComponent))
expect(
    requiredCustomPetFiles.isSubset(of: sourceFileNames),
    "custom pet capabilities should remain in their dedicated local modules"
)

let requiredPetdexPhase1Files: Set<String> = [
    "PetdexArchiveReader.swift",
    "PetdexManifestParser.swift",
    "PetdexSpriteSheetProcessor.swift",
    "PetdexAnimationMappingProvider.swift",
    "PetdexPackageConverter.swift",
    "PetdexPackageImporter.swift",
    "PetdexPackageOpenPanel.swift"
]
expect(
    requiredPetdexPhase1Files.isSubset(of: sourceFileNames),
    "Petdex Phase 1 capabilities should remain in dedicated local modules"
)

let requiredPetdexPhase2Files: Set<String> = [
    "PetdexDownloader.swift",
    "PetdexURLResolver.swift"
]
expect(
    requiredPetdexPhase2Files.isSubset(of: sourceFileNames),
    "Petdex Phase 2 URL download boundary should remain in dedicated modules"
)

for fileURL in sourceFileURLs {
    let contents = read(fileURL)
    let fileName = fileURL.lastPathComponent
    let filePath = relativePath(fileURL)
    let isInAICompanion = filePath.hasPrefix("Sources/DesktopPet/AICompanion/")
    let isAIVisual = filePath.hasPrefix("Sources/DesktopPet/AIVisualAction/")
        || filePath.hasPrefix("Sources/DesktopPet/AIVisualGeneration/")
        || filePath.hasPrefix("Sources/DesktopPet/AIVisualAssets/")
        || filePath.hasPrefix("Sources/DesktopPet/InteractiveBubble/")
        || fileName.hasPrefix("AIVisual")
        || fileName.hasPrefix("PetVisual")
        || fileName == "VisualImageGenerating.swift"
        || fileName.hasPrefix("VisualGeneration")
        || fileName.hasPrefix("MiniMaxCLI")
        || fileName.hasPrefix("MockImage")
        || fileName.hasPrefix("PetReference")
    let isPhase3AIIntegration = phase3AIIntegrationSourcePaths.contains(filePath)
    let isInInputSync = filePath.hasPrefix("Sources/DesktopPet/AdvancedFeatures/InputSync/")
    let isAIVisualHTTPProvider = filePath.hasPrefix("Sources/DesktopPet/AIVisualGeneration/Providers/")
    for rule in forbiddenImports + forbiddenSourcePatterns {
        if rule.allowedFileNames.contains(fileName) {
            continue
        }
        if (isInAICompanion || isPhase3AIIntegration || isAIVisual) && rule.label == "natural language chat" {
            continue
        }
        if (isInAICompanion || isPhase3AIIntegration || isAIVisual) && rule.label == "AI generation" {
            continue
        }
        if isInAICompanion && fileName == "AIProvider.swift" && rule.label == "cloud sync networking" {
            continue
        }
        if isAIVisualHTTPProvider && rule.label == "cloud sync networking" {
            continue
        }
        if isInInputSync && rule.label == "accessibility permission" {
            continue
        }
        expect(
            !matches(rule.pattern, in: contents),
            "\(rule.label) should stay outside MVP scope: \(relativePath(fileURL))"
        )
    }
}

let actionSourceFileURLs = swiftFiles(under: actionSourceRoot)
expect(!actionSourceFileURLs.isEmpty, "scope validation should find action module source files")
for fileURL in actionSourceFileURLs {
    let contents = read(fileURL)
    for rule in forbiddenActionModulePatterns {
        expect(
            !matches(rule.pattern, in: contents),
            "\(rule.label) should stay outside PetActions: \(relativePath(fileURL))"
        )
    }
}

let plist = read(packagingInfoPlist)
for key in forbiddenPlistKeys {
    expect(!plist.contains(key), "Info.plist should not contain intrusive permission key \(key)")
}

validateActionEditorPersistenceBoundary()
validateActionOverrideStoreLocation()
validateTagsRemainDeclarativeStrings()
validateNoExternalConditionIntegrations()
validateReleaseActionScopeClosure()
validateEditorDoesNotMutateAnimationPayload()
validateActionPackScopeClosure()

print("DesktopPetScopeValidation passed")

private func swiftFiles(under root: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return enumerator.compactMap { item in
        guard let url = item as? URL, url.pathExtension == "swift" else {
            return nil
        }
        return url
    }
}

private func read(_ url: URL) -> String {
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fail("Unable to read \(relativePath(url)): \(error)")
    }
}

private func matches(_ pattern: String, in contents: String) -> Bool {
    contents.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

private func validateActionEditorPersistenceBoundary() {
    let editorFiles = [actionEditorViewModelURL, importWizardViewModelURL]
    let forbiddenEditorWritePatterns = [
        ForbiddenPattern(label: "direct manifest model dependency", pattern: #"\bPetPackageManifest\b"#),
        ForbiddenPattern(label: "direct manifest rewrite", pattern: #"\b(ManifestRewriter|ManifestRewriting|rewriteV1ManifestToV2|manifestFileURL)\b"#),
        ForbiddenPattern(label: "direct file manager write", pattern: #"\bFileManager\b"#),
        ForbiddenPattern(label: "direct file data read", pattern: #"\bData\s*\(\s*contentsOf\s*:"#),
        ForbiddenPattern(label: "direct file data write", pattern: #"\.write\s*\(\s*to\s*:"#),
        ForbiddenPattern(label: "manifest writer dependency", pattern: #"\bPetLibraryManifestWriter\b"#)
    ]

    for fileURL in editorFiles {
        let contents = read(fileURL)
        expect(
            contents.contains("PetActionOverrideStoring"),
            "\(relativePath(fileURL)) should depend on PetActionOverrideStoring for action metadata persistence"
        )
        expect(
            matches(#"\boverrideStore\.save\s*\("#, in: contents),
            "\(relativePath(fileURL)) should persist edits through overrideStore.save"
        )

        for rule in forbiddenEditorWritePatterns {
            expect(
                !matches(rule.pattern, in: contents),
                "\(rule.label) should stay out of action editor UI: \(relativePath(fileURL))"
            )
        }
    }
}

private func validateActionOverrideStoreLocation() {
    let contents = read(actionOverrideStoreURL)
    expect(
        contents.contains(#"public static let fileName = "action-overrides.json""#),
        "PetActionOverrideStore should keep action overrides in action-overrides.json"
    )
    expect(
        matches(#"petDirectoryURL\(for:\s*petId\)\.appendingPathComponent\(Self\.fileName"#, in: contents),
        "PetActionOverrideStore should write overrides under Pets/<petId>/action-overrides.json"
    )
    expect(
        contents.contains(".applicationSupportDirectory") &&
            contents.contains(#"appendingPathComponent("DesktopPet""#) &&
            contents.contains("PetLibraryStore.petsDirectoryName"),
        "PetActionOverrideStore default path should stay under the app-owned Application Support/DesktopPet/Pets directory"
    )
}

private func validateTagsRemainDeclarativeStrings() {
    let actionTagContents = read(actionTagURL)
    expect(
        actionTagContents.contains("public let rawValue: String") &&
            actionTagContents.contains("RawRepresentable") &&
            actionTagContents.contains("Codable"),
        "ActionTag should remain a plain string value type"
    )

    let actionContents = read(actionModelURL)
    expect(
        actionContents.contains("public let tags: [ActionTag]"),
        "Action should keep tags as string-backed ActionTag metadata"
    )

    for fileURL in phase3TagDeclarativeSourceURLs {
        let contents = read(fileURL)
        for rule in forbiddenTagExpressionPatterns {
            expect(
                !matches(rule.pattern, in: contents),
                "\(rule.label) should stay out of tag handling: \(relativePath(fileURL))"
            )
        }
    }
}

private func validateNoExternalConditionIntegrations() {
    for fileURL in phase3ConditionSourceURLs {
        let contents = read(fileURL)
        for rule in forbiddenConditionIntegrationPatterns {
            expect(
                !matches(rule.pattern, in: contents),
                "\(rule.label) should not be introduced for Phase 3 tag scheduling: \(relativePath(fileURL))"
            )
        }
    }
}

private func validateReleaseActionScopeClosure() {
    for fileURL in actionFeatureSourceURLs {
        let contents = read(fileURL)
        for rule in releaseActionScopePatterns {
            expect(
                !matches(rule.pattern, in: contents),
                "\(rule.label) should stay outside extensible actions release scope: \(relativePath(fileURL))"
            )
        }
    }
}

private func validateEditorDoesNotMutateAnimationPayload() {
    let editorMutationRules = [
        ForbiddenPattern(label: "action editor frame rewrite", pattern: #"\b(frames|SpriteFrame|frameDurationMs|loop)\b"#),
        ForbiddenPattern(label: "action editor resource rewrite", pattern: #"(CGImageDestination|NSBitmapImageRep|Data\s*\(\s*contentsOf\s*:|\.write\s*\(\s*to\s*:)"#)
    ]
    for rule in editorMutationRules {
        let contents = read(actionEditorViewModelURL)
        expect(
            !matches(rule.pattern, in: contents),
            "\(rule.label) should stay out of action editor metadata saves"
        )
    }

    let importWizardMutationRules = [
        ForbiddenPattern(label: "import wizard timing rewrite", pattern: #"\b(frameDurationMs|loop)\b"#),
        ForbiddenPattern(label: "import wizard action/frame construction", pattern: #"\b(Action|SpriteFrame)\s*\("#),
        ForbiddenPattern(label: "import wizard frame mutation", pattern: #"\.frames\s*=|\.frames\.(append|remove|insert)|frames\s*:"#),
        ForbiddenPattern(label: "import wizard resource rewrite", pattern: #"(CGImageDestination|NSBitmapImageRep|spritesheetPNGData|previewPNGData|Data\s*\(\s*contentsOf\s*:|\.write\s*\(\s*to\s*:)"#)
    ]
    let importWizardContents = read(importWizardViewModelURL)
    for rule in importWizardMutationRules {
        expect(
            !matches(rule.pattern, in: importWizardContents),
            "\(rule.label) should stay out of import wizard metadata commits"
        )
    }
}

private func validateActionPackScopeClosure() {
    let actionPackFiles = swiftFiles(under: actionPackSourceRoot)
    expect(!actionPackFiles.isEmpty, "scope validation should find action pack source files")
    for fileURL in actionPackFiles {
        let contents = read(fileURL)
        for rule in forbiddenActionPackPatterns {
            expect(
                !matches(rule.pattern, in: contents),
                "\(rule.label) should stay outside action packs: \(relativePath(fileURL))"
            )
        }
    }
}

private func relativePath(_ url: URL) -> String {
    let path = url.path
    let root = rootURL.path + "/"
    return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fail(message)
    }
}

private func fail(_ message: String) -> Never {
    fputs("DesktopPetScopeValidation failed: \(message)\n", stderr)
    Foundation.exit(1)
}
