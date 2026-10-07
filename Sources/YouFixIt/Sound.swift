import AudioToolbox
import Foundation

/// Three soft system sounds. AudioServices follows the Mac's own "Play user interface sound effects" switch and mute.
@MainActor
enum Sound {
    enum Cue: String, CaseIterable {
        case nudge = "Purr", done = "Glass", undo = "Pop"
    }

    nonisolated static let enabledKey = "softSounds"
    private static var ids: [Cue: SystemSoundID] = [:]

    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) == nil || UserDefaults.standard.bool(forKey: enabledKey) }

    static func play(_ cue: Cue, force: Bool = false) {
        guard enabled || force else { return }
        if ids[cue] == nil {
            var id: SystemSoundID = 0
            let url = URL(fileURLWithPath: "/System/Library/Sounds/\(cue.rawValue).aiff") as CFURL
            guard AudioServicesCreateSystemSoundID(url, &id) == noErr else { return }
            ids[cue] = id
        }
        if let id = ids[cue] { AudioServicesPlaySystemSound(id) }
    }
}
