import Foundation

/// SPM 资源包定位器
///
/// 在 SPM 项目中，资源被打包进 .bundle 文件。
/// 此类负责在运行时的多个候选位置中找到正确的资源包，
/// 兼容 Debug（命令行 swift run）和 Release（.app bundle）两种运行模式。
public enum DesktopPetResources {
    /// SPM 自动生成的资源包名称
    public static let swiftPMResourceBundleName = "MofuPaw_DesktopPet.bundle"

    /// 当前可用的资源 Bundle
    ///
    /// 查找顺序：
    /// 1. main bundle 的 Resources 目录
    /// 2. main bundle 根目录
    /// 3. Bundle.module（SPM 默认）
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

    /// 从资源包中获取文件 URL
    /// - Parameters:
    ///   - name: 文件名（不含扩展名）
    ///   - fileExtension: 文件扩展名，默认 "png"
    /// - Returns: 文件 URL，未找到则返回 nil
    public static func url(named name: String, extension fileExtension: String = "png") -> URL? {
        bundle.url(forResource: name, withExtension: fileExtension)
    }
}
