import Foundation

@MainActor
public protocol PetImageSelecting {
    func selectImage() -> URL?
}

@MainActor
public protocol PetPackageSelecting {
    func selectPackage() -> URL?
}
