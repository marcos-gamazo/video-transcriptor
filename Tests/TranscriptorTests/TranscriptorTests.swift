import Testing
@testable import Transcriptor

@Suite("AppEnvironment")
struct AppEnvironmentTests {
    @Test("Valores base de la aplicación")
    func baseValues() {
        #expect(AppEnvironment.appName == "Transcriptor")
        #expect(AppEnvironment.bundleIdentifier == "com.transcriptor.app")
        #expect(AppEnvironment.deploymentTarget == "macOS 11.0")
    }
}