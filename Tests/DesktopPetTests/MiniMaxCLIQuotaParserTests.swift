import Foundation
import DesktopPet

@MainActor
func runMiniMaxCLIQuotaParserTests() {
    let tests = MiniMaxCLIQuotaParserTests()
    tests.parseAuthStatusWithValidJSON()
    tests.parseAuthStatusWithNoKey()
    tests.parseAuthStatusWithInvalidJSON()
    tests.parseAuthStatusWithEmptyInput()
    tests.parseQuotaWithValidJSON()
    tests.parseQuotaExtractsImageModel()
    tests.parseQuotaWithInvalidJSON()
    tests.parseQuotaWithEmptyRemains()
    tests.parseImageQuotaReturnsFirstImageModel()
    tests.parseImageQuotaInterpretsCurrentIntervalCountAsRemaining()
    tests.parseImageQuotaReturnsNilWhenNoImage()
}

@MainActor
private struct MiniMaxCLIQuotaParserTests {

    func parseAuthStatusWithValidJSON() {
        let json = """
        {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
        """
        let status = MiniMaxCLIQuotaParser.parseAuthStatus(from: json)
        expect(status.isAuthenticated, "should detect authenticated status")
        expect(status.method == "api-key", "should extract method")
    }

    func parseAuthStatusWithNoKey() {
        let json = """
        {"method": "api-key", "source": "config.json"}
        """
        let status = MiniMaxCLIQuotaParser.parseAuthStatus(from: json)
        expect(!status.isAuthenticated, "should detect unauthenticated when no key")
    }

    func parseAuthStatusWithInvalidJSON() {
        let status = MiniMaxCLIQuotaParser.parseAuthStatus(from: "not json")
        expect(!status.isAuthenticated, "should return false for invalid JSON")
    }

    func parseAuthStatusWithEmptyInput() {
        let status = MiniMaxCLIQuotaParser.parseAuthStatus(from: "")
        expect(!status.isAuthenticated, "should return false for empty input")
    }

    func parseQuotaWithValidJSON() {
        let json = """
        {
          "model_remains": [
            {
              "model_name": "image-01",
              "current_interval_total_count": 120,
              "current_interval_usage_count": 119,
              "current_weekly_total_count": 840,
              "current_weekly_usage_count": 839,
              "start_time": 1000,
              "end_time": 2000,
              "remains_time": 500
            },
            {
              "model_name": "MiniMax-M*",
              "current_interval_total_count": 4500,
              "current_interval_usage_count": 4495,
              "current_weekly_total_count": 45000,
              "current_weekly_usage_count": 44915,
              "start_time": 1000,
              "end_time": 2000,
              "remains_time": 500
            }
          ]
        }
        """
        let quotas = MiniMaxCLIQuotaParser.parseQuota(from: json)
        expect(quotas.count == 2, "should parse 2 model quotas")
        expect(quotas[0].modelName == "image-01", "first should be image-01")
        expect(quotas[0].intervalTotal == 120, "should extract interval total")
        expect(quotas[0].intervalUsed == 1, "should derive interval used")
        expect(quotas[0].intervalRemaining == 119, "should expose interval remaining")
        expect(quotas[0].weeklyTotal == 840, "should extract weekly total")
        expect(quotas[0].weeklyUsed == 1, "should derive weekly used")
    }

    func parseQuotaExtractsImageModel() {
        let json = """
        {
          "model_remains": [
            {
              "model_name": "image-01",
              "current_interval_total_count": 120,
              "current_interval_usage_count": 100,
              "current_weekly_total_count": 840,
              "current_weekly_usage_count": 700
            }
          ]
        }
        """
        let imageQuota = MiniMaxCLIQuotaParser.parseImageQuota(from: json)
        expect(imageQuota != nil, "should find image-01 model")
        expect(imageQuota?.modelName == "image-01", "should be image-01")
        expect(imageQuota?.intervalTotal == 120, "should have correct total")
        expect(imageQuota?.intervalUsed == 20, "should derive used from reported remaining")
        expect(imageQuota?.intervalRemaining == 100, "should expose reported remaining")
    }

    func parseQuotaWithInvalidJSON() {
        let quotas = MiniMaxCLIQuotaParser.parseQuota(from: "invalid")
        expect(quotas.isEmpty, "should return empty for invalid JSON")
    }

    func parseQuotaWithEmptyRemains() {
        let json = """
        {"model_remains": []}
        """
        let quotas = MiniMaxCLIQuotaParser.parseQuota(from: json)
        expect(quotas.isEmpty, "should return empty for no remains")
    }

    func parseImageQuotaReturnsFirstImageModel() {
        let json = """
        {
          "model_remains": [
            {
              "model_name": "image-01",
              "current_interval_total_count": 120,
              "current_interval_usage_count": 115,
              "current_weekly_total_count": 840,
              "current_weekly_usage_count": 820
            }
          ]
        }
        """
        let q = MiniMaxCLIQuotaParser.parseImageQuota(from: json)
        expect(q?.intervalUsed == 5, "should compute used correctly")
        expect(q?.intervalRemaining == 115, "should expose remaining correctly")
        expect(q?.weeklyUsed == 20, "should compute weekly used correctly")
        expect(q?.weeklyRemaining == 820, "should expose weekly remaining correctly")
    }

    func parseImageQuotaInterpretsCurrentIntervalCountAsRemaining() {
        let json = """
        {
          "model_remains": [
            {
              "model_name": "image-01",
              "current_interval_total_count": 120,
              "current_interval_usage_count": 119,
              "current_weekly_total_count": 840,
              "current_weekly_usage_count": 839
            }
          ]
        }
        """
        let q = MiniMaxCLIQuotaParser.parseImageQuota(from: json)
        expect(q?.intervalUsed == 1, "should derive used count from reported remaining count")
        expect(q?.intervalRemaining == 119, "should expose current image-01 remaining count")
        expect(q?.weeklyUsed == 1, "should derive weekly used count from reported weekly remaining count")
        expect(q?.weeklyRemaining == 839, "should expose weekly remaining count")
    }

    func parseImageQuotaReturnsNilWhenNoImage() {
        let json = """
        {
          "model_remains": [
            {
              "model_name": "MiniMax-M*",
              "current_interval_total_count": 4500,
              "current_interval_usage_count": 0,
              "current_weekly_total_count": 45000,
              "current_weekly_usage_count": 0
            }
          ]
        }
        """
        let q = MiniMaxCLIQuotaParser.parseImageQuota(from: json)
        expect(q == nil, "should return nil when no image-01 model")
    }
}
