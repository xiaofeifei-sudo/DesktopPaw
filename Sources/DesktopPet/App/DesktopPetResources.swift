import Foundation

public enum DesktopPetResources {
    public static let swiftPMResourceBundleName = "DesktopPet_DesktopPet.bundle"

    public static var bundle: Bundle {
        let candidateURLs = [
            Bundle.main.resourceURL?.appendingPathComponent(swiftPMResourceBundleName),
            Bundle.main.bundleURL.appendingPathComponent(swiftPMResourceBundleName),
            Bundle.module.bundleURL
        ].compactMap { $0 }

        for url in candidateURLs {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }

        return Bundle.module
    }

    public static func url(named name: String, extension fileExtension: String = "png") -> URL? {
        bundle.url(forResource: name, withExtension: fileExtension)
    }
}
