import Foundation

enum TestsFixtures {
    static func meetingAudioURL() throws -> URL {
        guard let url = Bundle.module.url(forResource: "meeting", withExtension: "m4a", subdirectory: "Fixtures") else {
            throw FixtureError.missing
        }
        return url
    }

    enum FixtureError: Error, CustomStringConvertible {
        case missing

        var description: String {
            "No se encuentra el fixture en el bundle de tests."
        }
    }
}