import Foundation
import os
import ServiceManagement

public enum LaunchAtLoginStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

public protocol LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus { get }

    func register() throws
    func unregister() throws
}

public final class ServiceManagementLaunchAtLoginService: LaunchAtLoginServicing {
    public init() {}

    public var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .disabled
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    public func register() throws {
        try SMAppService.mainApp.register()
    }

    public func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
public final class LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: LaunchAtLoginServicing
    private let logger: Logger

    public init(
        service: LaunchAtLoginServicing = ServiceManagementLaunchAtLoginService(),
        logger: Logger = DesktopPetLog.launchAtLogin
    ) {
        self.service = service
        self.logger = logger
    }

    public var isLaunchAtLoginEnabled: Bool {
        service.status == .enabled
    }

    public func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            if enabled {
                guard service.status != .enabled else {
                    return
                }

                try service.register()
                logger.info("Launch at login registration requested.")
            } else {
                guard service.status != .disabled else {
                    return
                }

                try service.unregister()
                logger.info("Launch at login unregistration requested.")
            }
        } catch {
            logger.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
