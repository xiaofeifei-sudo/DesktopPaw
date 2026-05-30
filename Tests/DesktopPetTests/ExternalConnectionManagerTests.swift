import Foundation
import Darwin
import DesktopPet

func runExternalConnectionManagerTests() {
    let socketPath = "/tmp/desktoppet-test-m11.sock"
    unlink(socketPath)

    func testStartAndStopListening() {
        let manager = ExternalConnectionManager(socketPath: socketPath)
        do {
            try manager.startListening()
        } catch {
            fail("startListening should not throw: \(error)")
        }
        expect(manager.activeConnectionCount == 0, "should have 0 connections initially")
        manager.stopListening()
    }

    func testDoubleStartThrows() {
        let manager = ExternalConnectionManager(socketPath: socketPath)
        try? manager.startListening()
        do {
            try manager.startListening()
            fail("double start should throw")
        } catch let error as ExternalStateError {
            expect(error == .alreadyListening, "should throw alreadyListening")
        } catch {
            fail("unexpected error: \(error)")
        }
        manager.stopListening()
    }

    func testStopWhenNotListeningIsNoop() {
        let manager = ExternalConnectionManager(socketPath: socketPath)
        manager.stopListening()
    }

    func testReceiveEventFromClient() {
        let manager = ExternalConnectionManager(socketPath: socketPath)
        let expectation = ExpectationHelper()

        manager.onEventReceived = { event in
            expectation.fulfill()
        }

        try! manager.startListening()

        // Connect a test client
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            manager.stopListening()
            fail("failed to create client socket")
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        var pathBytes = Array(socketPath.utf8)
        pathBytes.append(0)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let count = min(pathBytes.count, buf.count)
            buf.copyBytes(from: pathBytes.prefix(count))
        }

        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, addrSize)
            }
        }
        guard connectResult >= 0 else {
            close(fd)
            manager.stopListening()
            fail("connect() failed: \(errno)")
        }

        let json = "{\"event\":\"build.success\",\"data\":{\"message\":\"hello\"}}\n"
        let sent = json.utf8CString.withUnsafeBufferPointer { ptr in
            write(fd, ptr.baseAddress!, json.utf8.count)
        }

        // Allow time for the event to be processed
        usleep(100_000)

        close(fd)
        manager.stopListening()

        expect(expectation.wasFulfilled, "should receive event from client")
    }

    func testMalformedJSONIsIgnored() {
        let manager = ExternalConnectionManager(socketPath: socketPath)
        let expectation = ExpectationHelper()

        manager.onEventReceived = { _ in
            expectation.fulfill()
        }

        try! manager.startListening()

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            manager.stopListening()
            fail("failed to create client socket")
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        var pathBytes = Array(socketPath.utf8)
        pathBytes.append(0)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let count = min(pathBytes.count, buf.count)
            buf.copyBytes(from: pathBytes.prefix(count))
        }

        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, addrSize)
            }
        }
        guard connectResult >= 0 else {
            close(fd)
            manager.stopListening()
            fail("connect() failed: \(errno)")
        }

        let invalid = "not valid json\n"
        _ = invalid.utf8CString.withUnsafeBufferPointer { ptr in
            write(fd, ptr.baseAddress!, invalid.utf8.count)
        }
        usleep(100_000)

        close(fd)
        manager.stopListening()

        expect(!expectation.wasFulfilled, "malformed JSON should be ignored")
    }

    func testActiveConnectionCount() {
        let manager = ExternalConnectionManager(socketPath: socketPath)
        try! manager.startListening()

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
        usleep(50_000)

        expect(manager.activeConnectionCount >= 1, "should have at least 1 active connection")

        close(fd)
        manager.stopListening()
    }

    func testExternalEventCodable() {
        let event = ExternalEvent(event: "test.event", data: ["key": "value"])
        guard let data = try? JSONEncoder().encode(event),
              let decoded = try? JSONDecoder().decode(ExternalEvent.self, from: data) else {
            fail("event codable roundtrip failed")
        }
        expect(decoded.event == "test.event", "event name should survive roundtrip")
        expect(decoded.data["key"] == "value", "event data should survive roundtrip")
    }

    func testExternalEventJSONDecoding() {
        let json = "{\"event\":\"build.success\",\"data\":{\"project\":\"MyApp\"}}"
        guard let data = json.data(using: .utf8),
              let event = try? JSONDecoder().decode(ExternalEvent.self, from: data) else {
            fail("JSON decoding failed")
        }
        expect(event.event == "build.success", "should decode event name")
        expect(event.data["project"] == "MyApp", "should decode event data")
    }

    testStartAndStopListening()
    testDoubleStartThrows()
    testStopWhenNotListeningIsNoop()
    testReceiveEventFromClient()
    testMalformedJSONIsIgnored()
    testActiveConnectionCount()
    testExternalEventCodable()
    testExternalEventJSONDecoding()
}
