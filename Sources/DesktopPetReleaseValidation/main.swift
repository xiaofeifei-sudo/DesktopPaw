import AppKit
import DesktopPet
import Foundation

@MainActor
func runReleaseValidation() {
    guard CommandLine.arguments.count == 2 else {
        fail("Usage: DesktopPetReleaseValidation /path/to/DesktopPet.app")
    }

    let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
    validateAppBundle(at: appURL)
    validateInfoPlist(in: appURL)
    validateBundledResources(in: appURL)
    validateUserPetDirectoryCanBeCreated()
    validateDefaultPosition()
    validateCrashFreeFallbacks()
    print("DesktopPetReleaseValidation passed")
}

@MainActor
private func validateAppBundle(at appURL: URL) {
    expect(appURL.pathExtension == "app", "release artifact should be an .app bundle")

    var isDirectory: ObjCBool = false
    expect(
        FileManager.default.fileExists(atPath: appURL.path, isDirectory: &isDirectory) && isDirectory.boolValue,
        "app bundle should exist"
    )

    let executableURL = appURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("MacOS")
        .appendingPathComponent("DesktopPet")
    expect(FileManager.default.isExecutableFile(atPath: executableURL.path), "app executable should exist and be executable")

    let iconURL = appURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("Resources")
        .appendingPathComponent("AppIcon.icns")
    expect(FileManager.default.fileExists(atPath: iconURL.path), "app icon should be packaged")
}

private func validateInfoPlist(in appURL: URL) {
    let plistURL = appURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("Info.plist")
    guard let data = try? Data(contentsOf: plistURL),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        fail("Info.plist should be readable")
    }

    expect(plist["CFBundleExecutable"] as? String == "DesktopPet", "Info.plist should point to DesktopPet executable")
    expect(plist["CFBundleIdentifier"] as? String == "com.codex.DesktopPet", "Info.plist should define stable bundle identifier")
    expect(plist["CFBundlePackageType"] as? String == "APPL", "Info.plist should define an app package")
    expect(plist["LSMinimumSystemVersion"] as? String == "13.0", "minimum deployment target should be macOS 13")
    expect(plist["LSUIElement"] as? Bool == true, "app should run as menu bar UI element without Dock presence")

    let intrusivePermissionKeys = [
        "NSAppleEventsUsageDescription",
        "NSCameraUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSScreenCaptureDescription",
        "NSSystemAdministrationUsageDescription"
    ]
    for key in intrusivePermissionKeys {
        expect(plist[key] == nil, "Info.plist should not request intrusive permission key \(key)")
    }
}

private func validateBundledResources(in appURL: URL) {
    let resourceBundleURL = appURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("Resources")
        .appendingPathComponent("DesktopPet_DesktopPet.bundle")
    var isDirectory: ObjCBool = false
    expect(
        FileManager.default.fileExists(atPath: resourceBundleURL.path, isDirectory: &isDirectory) && isDirectory.boolValue,
        "SwiftPM resource bundle should be packaged in Contents/Resources"
    )

    let resources: [(name: String, size: CGSize)] = [
        ("starter-pet-spritesheet.png", CGSize(width: 896, height: 128)),
        ("starter-pet-preview.png", CGSize(width: 128, height: 128)),
        ("placeholder-pet.png", CGSize(width: 128, height: 128))
    ]

    for resource in resources {
        let url = resourceBundleURL.appendingPathComponent(resource.name)
        expect(FileManager.default.fileExists(atPath: url.path), "resource \(resource.name) should be packaged")

        guard let image = NSImage(contentsOf: url),
              let representation = image.representations.first else {
            fail("resource \(resource.name) should be a readable image")
        }

        expect(
            representation.pixelsWide == Int(resource.size.width)
                && representation.pixelsHigh == Int(resource.size.height),
            "resource \(resource.name) should have expected pixel size"
        )
    }
}

private func validateUserPetDirectoryCanBeCreated() {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DesktopPetReleaseValidation-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let store = PetLibraryStore(rootDirectory: rootURL)
    let items = tryOrFail(try store.listPets(), "pet library should initialize release user pet directory")

    var isDirectory: ObjCBool = false
    expect(
        FileManager.default.fileExists(atPath: store.importedPetsDirectoryURL.path, isDirectory: &isDirectory)
            && isDirectory.boolValue,
        "release user pet directory should be creatable"
    )
    expect(
        items.contains(where: { $0.id == store.builtInPetId && $0.source == .builtIn }),
        "built-in pet should still load while user pet directory is empty"
    )
}

private func validateDefaultPosition() {
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1_440, height: 900)
    ])
    let frame = geometry.defaultPetFrame(frameSize: CGSize(width: 128, height: 128))
    expect(frame == CGRect(x: 1_288, y: 24, width: 128, height: 128), "first launch default position should be visible")
}

@MainActor
private func validateCrashFreeFallbacks() {
    let definition = tryOrFail(try BuiltInPetDefinitionProvider().loadBuiltInPet(), "built-in pet definition should load")
    expect(definition.animation(for: .idle) != nil, "idle animation should be available")
    expect(definition.animation(for: .sleeping) != nil, "sleeping animation should be available")

    let renderer = SpriteSheetRenderer(definition: definition) { _ in nil }
    expect(renderer.image(for: .idle) == nil, "missing image resources should fail silently")
}

private func tryOrFail<T>(_ expression: @autoclosure () throws -> T, _ message: String) -> T {
    do {
        return try expression()
    } catch {
        fail("\(message): \(error)")
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fail(message)
    }
}

private func fail(_ message: String) -> Never {
    fputs("DesktopPetReleaseValidation failed: \(message)\n", stderr)
    Foundation.exit(1)
}

runReleaseValidation()
