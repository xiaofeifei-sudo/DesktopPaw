import Foundation
import DesktopPet

@MainActor
func runAIMemoryFilterTests() {
    let tests = AIMemoryFilterTests()
    tests.safeContentPasses()
    tests.idNumberRejected()
    tests.passwordRejected()
    tests.exactAddressRejected()
    tests.medicalInfoRejected()
    tests.mixedCaseKeywords()
    tests.emptyContentIsSafe()
    tests.normalPreferenceIsAllowed()
    tests.nicknameIsAllowed()
    tests.filterResultEquality()
}

@MainActor
private struct AIMemoryFilterTests {
    private let filter = AIMemoryFilter()

    func safeContentPasses() {
        let safeContents = [
            "喜欢安静的氛围",
            "叫我小明",
            "今天一起玩了很久",
            "偏好暖色调",
        ]
        for content in safeContents {
            let result = filter.filter(content)
            expect(result.isAllowed, "'\(content)' should be allowed, got: \(result.reason ?? "nil")")
        }
    }

    func idNumberRejected() {
        let contents = [
            "身份证号是110101199001011234",
            "证件号32010219851212567X",
        ]
        for content in contents {
            let result = filter.filter(content)
            expect(!result.isAllowed, "'\(content)' should be rejected as ID number")
            expect(result.reason != nil, "should have rejection reason")
        }
    }

    func passwordRejected() {
        let contents = [
            "我的密码是abc123",
            "password is secret",
            "pwd要改一下",
            "验证码是123456",
        ]
        for content in contents {
            let result = filter.filter(content)
            expect(!result.isAllowed, "'\(content)' should be rejected as password")
        }
    }

    func exactAddressRejected() {
        let contents = [
            "住在幸福路12号3室",
            "地址是朝阳小区3栋5号",
        ]
        for content in contents {
            let result = filter.filter(content)
            expect(!result.isAllowed, "'\(content)' should be rejected as address")
        }
    }

    func medicalInfoRejected() {
        let contents = [
            "确诊了感冒",
            "今天的检查报告不太好",
            "血糖有点高",
        ]
        for content in contents {
            let result = filter.filter(content)
            expect(!result.isAllowed, "'\(content)' should be rejected as medical info")
        }
    }

    func mixedCaseKeywords() {
        let result = filter.filter("PASSWORD is here")
        expect(!result.isAllowed, "case-insensitive password match should reject")
    }

    func emptyContentIsSafe() {
        let result = filter.filter("")
        expect(result.isAllowed, "empty content should be allowed")
    }

    func normalPreferenceIsAllowed() {
        let result = filter.filter("喜欢吃苹果")
        expect(result.isAllowed, "normal preference should be allowed")
    }

    func nicknameIsAllowed() {
        let result = filter.filter("叫我小猫咪")
        expect(result.isAllowed, "nickname should be allowed")
    }

    func filterResultEquality() {
        let a = MemoryFilterResult.allowed
        let b = MemoryFilterResult(isAllowed: true)
        expect(a == b, "allowed results should be equal")

        let c = MemoryFilterResult(isAllowed: false, reason: "test")
        let d = MemoryFilterResult(isAllowed: false, reason: "test")
        expect(c == d, "rejected results with same reason should be equal")
    }
}
