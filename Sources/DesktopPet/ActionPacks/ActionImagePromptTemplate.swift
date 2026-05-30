import Foundation

public struct ActionImagePromptOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let imageSizeText: String
    public let detail: String
    public let isRecommended: Bool
    public let prompt: String

    public init(
        id: String,
        title: String,
        imageSizeText: String,
        detail: String,
        isRecommended: Bool,
        prompt: String
    ) {
        self.id = id
        self.title = title
        self.imageSizeText = imageSizeText
        self.detail = detail
        self.isRecommended = isRecommended
        self.prompt = prompt
    }
}

public enum ActionImagePromptTemplate {
    public static func options(
        frameSize: CGSizeCodable,
        petDisplayName: String?
    ) -> [ActionImagePromptOption] {
        let frameWidth = max(1, Int(frameSize.width))
        let frameHeight = max(1, Int(frameSize.height))
        let petName = normalizedPetName(petDisplayName)

        return [
            singleFrameOption(
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                petName: petName
            ),
            horizontalSheetOption(
                frameCount: 4,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                petName: petName,
                isRecommended: true
            ),
            horizontalSheetOption(
                frameCount: 8,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                petName: petName,
                isRecommended: false
            )
        ]
    }

    private static func singleFrameOption(
        frameWidth: Int,
        frameHeight: Int,
        petName: String
    ) -> ActionImagePromptOption {
        let imageSize = sizeText(width: frameWidth, height: frameHeight)
        return ActionImagePromptOption(
            id: "single",
            title: "单帧",
            imageSizeText: "\(imageSize) 像素",
            detail: "适合静态表情或姿势",
            isRecommended: false,
            prompt: """
            请为桌宠「\(petName)」生成一张单帧动作图片。画面尺寸必须为 \(imageSize) 像素。

            要求：保持当前桌宠的角色外观、配色、比例和画风一致；角色主体完整居中，不要裁切；透明背景；优先输出 PNG，若工具只能输出 JPG 也可生成 JPG；不要文字、不要水印、不要边框、不要分隔线、不要多角色、不要额外背景。

            动作内容：一个自然可爱的新增动作或表情（可替换成你想要的具体动作）。
            """
        )
    }

    private static func horizontalSheetOption(
        frameCount: Int,
        frameWidth: Int,
        frameHeight: Int,
        petName: String,
        isRecommended: Bool
    ) -> ActionImagePromptOption {
        let imageSize = sizeText(width: frameWidth * frameCount, height: frameHeight)
        let frameSize = sizeText(width: frameWidth, height: frameHeight)
        return ActionImagePromptOption(
            id: "horizontal-\(frameCount)",
            title: "\(frameCount)帧横图",
            imageSizeText: "\(imageSize) 像素",
            detail: isRecommended ? "推荐，动作清楚且更容易稳定生成" : "更顺滑，适合幅度较大的动作",
            isRecommended: isRecommended,
            prompt: """
            请为桌宠「\(petName)」生成一张 \(frameCount) 帧横向精灵图。整图尺寸必须为 \(imageSize) 像素，每帧尺寸必须为 \(frameSize) 像素。

            排版要求：从左到右排列 \(frameCount) 帧；每一帧等宽等高；不要留额外边距；不要画分隔线；不要把多帧做成九宫格或竖排。

            角色要求：保持当前桌宠的角色外观、配色、比例和画风一致；每一帧角色主体完整居中，不要裁切；动作需要连续自然，适合导入桌宠动作；透明背景；优先输出 PNG，若工具只能输出 JPG 也可生成 JPG；不要文字、不要水印、不要边框、不要多角色、不要额外背景。

            动作内容：一个自然可爱的新增动作（可替换成你想要的具体动作）。
            """
        )
    }

    private static func normalizedPetName(_ petDisplayName: String?) -> String {
        let trimmed = petDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "当前桌宠" : trimmed
    }

    private static func sizeText(width: Int, height: Int) -> String {
        "\(width) × \(height)"
    }
}
