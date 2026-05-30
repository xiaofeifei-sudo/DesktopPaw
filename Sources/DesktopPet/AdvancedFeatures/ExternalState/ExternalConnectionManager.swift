import Foundation
import Darwin

public final class ExternalConnectionManager: @unchecked Sendable {
    private let socketPath: String
    private let eventQueue: DispatchQueue
    private var listenSocket: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private var clientSources: [String: (DispatchSourceRead, Int32)] = [:]
    private var connections: [String: ExternalConnection] = [:]
    private var isListening = false

    public var onEventReceived: (@Sendable (ExternalEvent) -> Void)?

    public var activeConnectionCount: Int {
        connections.values.filter(\.isActive).count
    }

    public var activeConnections: [ExternalConnection] {
        Array(connections.values)
    }

    public init(socketPath: String, eventQueue: DispatchQueue = DispatchQueue(label: "com.desktoppet.externalstate")) {
        self.socketPath = socketPath
        self.eventQueue = eventQueue
    }

    deinit {
        stopListening()
    }

    public func startListening() throws {
        guard !isListening else {
            throw ExternalStateError.alreadyListening
        }

        unlink(socketPath)

        listenSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenSocket >= 0 else {
            throw ExternalStateError.socketCreationFailed("socket() failed: \(errno)")
        }

        // Set non-blocking
        var flags = fcntl(listenSocket, F_GETFL, 0)
        _ = fcntl(listenSocket, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        var pathBytes = Array(socketPath.utf8)
        pathBytes.append(0)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let count = min(pathBytes.count, buf.count)
            buf.copyBytes(from: pathBytes.prefix(count))
        }

        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(listenSocket, sockPtr, addrSize)
            }
        }
        guard bindResult >= 0 else {
            close(listenSocket)
            listenSocket = -1
            throw ExternalStateError.socketCreationFailed("bind() failed: \(errno)")
        }

        guard listen(listenSocket, 5) >= 0 else {
            close(listenSocket)
            unlink(socketPath)
            listenSocket = -1
            throw ExternalStateError.socketCreationFailed("listen() failed: \(errno)")
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: listenSocket, queue: eventQueue)
        source.setEventHandler { [weak self] in
            self?.handleNewConnection()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            close(self.listenSocket)
            unlink(self.socketPath)
        }
        source.resume()
        listenSource = source
        isListening = true
    }

    public func stopListening() {
        guard isListening else { return }
        isListening = false

        for (_, (source, fd)) in clientSources {
            source.cancel()
            close(fd)
        }
        clientSources.removeAll()
        connections.removeAll()

        listenSource?.cancel()
        listenSource = nil
        listenSocket = -1
    }

    public func disconnect(_ connectionId: String) {
        guard let (source, fd) = clientSources[connectionId] else { return }
        source.cancel()
        close(fd)
        clientSources.removeValue(forKey: connectionId)
        connections[connectionId]?.isActive = false
    }

    private func handleNewConnection() {
        var clientAddr = sockaddr_un()
        var addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                accept(listenSocket, sockPtr, &addrLen)
            }
        }

        guard clientFD >= 0 else { return }

        let connectionId = UUID().uuidString
        let connection = ExternalConnection(id: connectionId, connectedAt: Date())
        connections[connectionId] = connection

        var lineBuffer = Data()
        let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: eventQueue)
        source.setEventHandler { [weak self] in
            self?.handleClientData(fd: clientFD, connectionId: connectionId, buffer: &lineBuffer)
        }
        source.setCancelHandler { [weak self] in
            _ = close(clientFD)
            self?.connections[connectionId]?.isActive = false
        }
        source.resume()
        clientSources[connectionId] = (source, clientFD)
    }

    private func handleClientData(fd: Int32, connectionId: String, buffer: inout Data) {
        var temp = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &temp, temp.count)

        if bytesRead <= 0 {
            if bytesRead == 0 || errno != EAGAIN {
                disconnect(connectionId)
            }
            return
        }

        buffer.append(contentsOf: temp.prefix(bytesRead))
        processLines(in: &buffer)
    }

    private func processLines(in buffer: inout Data) {
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.prefix(upTo: newlineIndex)
            buffer.removeSubrange(0...newlineIndex)

            let trimmed = lineData.filter { $0 != 0x0D }
            guard !trimmed.isEmpty else { continue }

            if let event = try? JSONDecoder().decode(ExternalEvent.self, from: trimmed) {
                onEventReceived?(event)
            }
        }
    }
}
