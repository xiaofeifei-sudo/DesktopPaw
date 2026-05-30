// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MofuPaw",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MofuPaw", targets: ["DesktopPetApp"])
    ],
    targets: [
        .target(
            name: "DesktopPet",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "DesktopPetApp",
            dependencies: ["DesktopPet"]
        ),
        .executableTarget(
            name: "DesktopPetValidation",
            dependencies: ["DesktopPet"]
        ),
        .executableTarget(
            name: "DesktopPetUnitTests",
            dependencies: ["DesktopPet"],
            path: "Tests/DesktopPetTests"
        ),
        .executableTarget(
            name: "DesktopPetModule1Validation",
            dependencies: ["DesktopPet"],
            path: "Tests/DesktopPetModule1Validation"
        ),
        .executableTarget(
            name: "DesktopPetReleaseValidation",
            dependencies: ["DesktopPet"]
        ),
        .executableTarget(
            name: "DesktopPetCustomPetValidation",
            dependencies: ["DesktopPet"]
        ),
        .executableTarget(
            name: "DesktopPetActionValidation",
            dependencies: ["DesktopPet"]
        ),
        .executableTarget(
            name: "DesktopPetPetdexValidation",
            dependencies: ["DesktopPet"]
        ),
        .executableTarget(
            name: "DesktopPetScopeValidation",
            dependencies: []
        ),
        .executableTarget(
            name: "DesktopPetInteractiveValidation",
            dependencies: ["DesktopPet"]
        ),
        .executableTarget(
            name: "DesktopPetModule5Validation",
            dependencies: ["DesktopPet"],
            path: "Tests/DesktopPetModule5Validation"
        )
    ]
)
