import Foundation
import DesktopPet

func runExternalStateServiceTests() {
    let socketPath = "/tmp/desktoppet-test-m11-service.sock"
    unlink(socketPath)

    func testDefaultServiceIsNotListening() {
        let service = ExternalStateService(socketPath: socketPath)
        expect(!service.isEnabled, "default service should not be listening")
        expect(service.socketPath == socketPath, "should expose socket path")
        expect(service.getActiveConnections().isEmpty, "should have no connections")
        expect(service.getActionMappings().isEmpty, "should have no mappings")
    }

    func testStartAndStopService() {
        let service = ExternalStateService(socketPath: socketPath)
        do {
            try service.startListening()
        } catch {
            fail("startListening should not throw: \(error)")
        }
        expect(service.isEnabled, "service should be listening after start")

        service.stopListening()
        expect(!service.isEnabled, "service should not be listening after stop")
    }

    func testRegisterAndRetrieveActionMapping() {
        let service = ExternalStateService(socketPath: socketPath)
        service.registerActionMapping(event: "build.success", actionId: "celebrate", bubbleText: "编译通过")

        let mappings = service.getActionMappings()
        expect(mappings.count == 1, "should have 1 mapping")
        expect(mappings[0].event == "build.success", "should retrieve correct mapping")
        expect(mappings[0].actionId == "celebrate", "should retrieve actionId")
        expect(mappings[0].bubbleText == "编译通过", "should retrieve bubbleText")
    }

    func testUnregisterActionMapping() {
        let service = ExternalStateService(socketPath: socketPath)
        service.registerActionMapping(event: "test.event", actionId: nil, bubbleText: nil)
        expect(service.getActionMappings().count == 1, "should have mapping before unregister")

        service.unregisterActionMapping(event: "test.event")
        expect(service.getActionMappings().isEmpty, "should have no mappings after unregister")
    }

    func testEventTriggersCallback() {
        let expectation = ExpectationHelper()
        let service = ExternalStateService(socketPath: socketPath)

        service.onEventTriggered = { event, mapping in
            expectation.fulfill()
        }

        service.registerActionMapping(event: "build.success", actionId: "celebrate", bubbleText: "成功")

        try! service.startListening()

        // Connect and send event
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        var pathBytes = Array(socketPath.utf8)
        pathBytes.append(0)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let count = min(pathBytes.count, buf.count)
            buf.copyBytes(from: pathBytes.prefix(count))
        }
        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        _ = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, addrSize)
            }
        }
        let json = "{\"event\":\"build.success\",\"data\":{}}\n"
        _ = json.utf8CString.withUnsafeBufferPointer { ptr in
            write(fd, ptr.baseAddress!, json.utf8.count)
        }
        usleep(100_000)

        close(fd)
        service.stopListening()

        expect(expectation.wasFulfilled, "event should trigger callback")
    }

    func testEventBlockedByQuietMode() {
        let expectation = ExpectationHelper()
        let service = ExternalStateService(
            socketPath: socketPath,
            quietModePolicyProvider: { QuietModePolicy() },
            companionPreferencesProvider: {
                var prefs = CompanionPreferences()
                prefs.quietUntil = Date().addingTimeInterval(3600)
                return prefs
            }
        )

        service.onEventTriggered = { _, _ in
            expectation.fulfill()
        }

        service.registerActionMapping(event: "test.event", actionId: nil, bubbleText: nil)

        try! service.startListening()

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        var pathBytes = Array(socketPath.utf8)
        pathBytes.append(0)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let count = min(pathBytes.count, buf.count)
            buf.copyBytes(from: pathBytes.prefix(count))
        }
        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        _ = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, addrSize)
            }
        }
        let json = "{\"event\":\"test.event\",\"data\":{}}\n"
        _ = json.utf8CString.withUnsafeBufferPointer { ptr in
            write(fd, ptr.baseAddress!, json.utf8.count)
        }
        usleep(100_000)

        close(fd)
        service.stopListening()

        expect(!expectation.wasFulfilled, "event should be blocked during quiet mode")
    }

    func testEventBlockedByBubbleScheduler() {
        let expectation = ExpectationHelper()
        let service = ExternalStateService(
            socketPath: socketPath,
            bubbleSchedulerCheck: { false }
        )

        service.onEventTriggered = { _, _ in
            expectation.fulfill()
        }

        service.registerActionMapping(event: "test.event", actionId: nil, bubbleText: nil)

        try! service.startListening()

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        var pathBytes = Array(socketPath.utf8)
        pathBytes.append(0)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let count = min(pathBytes.count, buf.count)
            buf.copyBytes(from: pathBytes.prefix(count))
        }
        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        _ = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, addrSize)
            }
        }
        let json = "{\"event\":\"test.event\",\"data\":{}}\n"
        _ = json.utf8CString.withUnsafeBufferPointer { ptr in
            write(fd, ptr.baseAddress!, json.utf8.count)
        }
        usleep(100_000)

        close(fd)
        service.stopListening()

        expect(!expectation.wasFulfilled, "event should be blocked by bubble scheduler")
    }

    func testExternalStateErrorDescriptions() {
        expect(!ExternalStateError.socketCreationFailed("test").localizedDescription.isEmpty, "should have description")
        expect(!ExternalStateError.alreadyListening.localizedDescription.isEmpty, "should have description")
        expect(!ExternalStateError.notListening.localizedDescription.isEmpty, "should have description")
    }

    testDefaultServiceIsNotListening()
    testStartAndStopService()
    testRegisterAndRetrieveActionMapping()
    testUnregisterActionMapping()
    testEventTriggersCallback()
    testEventBlockedByQuietMode()
    testEventBlockedByBubbleScheduler()
    testExternalStateErrorDescriptions()
}
