import os

public enum DesktopPetLog {
    public static let subsystem = "DesktopPet"

    public static let windowCategory = "window"
    public static let engineCategory = "engine"
    public static let assetsCategory = "assets"
    public static let preferencesCategory = "preferences"
    public static let launchAtLoginCategory = "launchAtLogin"
    public static let petLibraryCategory = "petLibrary"
    public static let petdexCategory = "petdex"
    public static let bubbleCategory = "bubble"
    public static let aiCompanionCategory = "aiCompanion"

    public static let categoryNames: Set<String> = [
        windowCategory,
        engineCategory,
        assetsCategory,
        preferencesCategory,
        launchAtLoginCategory,
        petLibraryCategory,
        petdexCategory,
        bubbleCategory,
        aiCompanionCategory
    ]

    public static let window = Logger(subsystem: subsystem, category: windowCategory)
    public static let engine = Logger(subsystem: subsystem, category: engineCategory)
    public static let assets = Logger(subsystem: subsystem, category: assetsCategory)
    public static let preferences = Logger(subsystem: subsystem, category: preferencesCategory)
    public static let launchAtLogin = Logger(subsystem: subsystem, category: launchAtLoginCategory)
    public static let petLibrary = Logger(subsystem: subsystem, category: petLibraryCategory)
    public static let petdex = Logger(subsystem: subsystem, category: petdexCategory)
    public static let bubble = Logger(subsystem: subsystem, category: bubbleCategory)
    public static let aiCompanion = Logger(subsystem: subsystem, category: aiCompanionCategory)
}
