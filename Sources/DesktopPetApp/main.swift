import DesktopPet
import Foundation

if CommandLine.arguments.contains("--validate-launch") {
    do {
        try DesktopPetApplication.validateLaunchConfiguration()
        print("DesktopPet launch configuration valid")
    } catch {
        fputs("DesktopPet launch configuration invalid: \(error)\n", stderr)
        Foundation.exit(1)
    }
} else {
    DesktopPetApplication.run()
}
