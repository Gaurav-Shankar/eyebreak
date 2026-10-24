import AppKit

enum Chime {
    /// Sounds that ship with macOS in /System/Library/Sounds.
    static let names = ["Glass", "Ping", "Tink", "Purr", "Pop", "Hero", "Submarine", "Bottle", "Blow", "Frog", "Funk", "Morse", "Sosumi", "Basso"]

    private static var current: NSSound?

    static func play(_ name: String) {
        guard !name.isEmpty, let sound = NSSound(named: NSSound.Name(name)) else { return }
        current?.stop()
        current = sound
        sound.play()
    }
}
