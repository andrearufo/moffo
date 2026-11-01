import SwiftUI
import UserNotifications
import MoffoCore

@Observable @MainActor
final class PetStore {
    var pet: Pet
    var squish = false
    var icon = NSImage()

    /// MOFFO_SPEED=60 makes one real minute last an hour. For testing only.
    private let speed = Double(ProcessInfo.processInfo.environment["MOFFO_SPEED"] ?? "") ?? 1
    private let start = Date()
    private var alerted: Set<String> = []
    private var timer: Timer?
    private static let key = "pet"

    var now: Date { start.addingTimeInterval(Date().timeIntervalSince(start) * speed) }
    private var canNotify: Bool { Bundle.main.bundleIdentifier != nil }  // `swift run` has no bundle

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Pet.self, from: data) {
            pet = saved
        } else {
            pet = Pet()
        }
        if canNotify {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func tick() {
        pet.advance(to: now)
        squish.toggle()
        icon = renderIcon()
        save()
        notifyIfNeeded()
    }

    func act(_ action: (inout Pet) -> Void) {
        pet.advance(to: now)
        action(&pet)
        save()
    }

    func newEgg() {
        pet = Pet(now: now)
        alerted = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pet) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    private func renderIcon() -> NSImage {
        let r = ImageRenderer(content: Jelly(mood: pet.mood, squish: squish, size: 18, detailed: false))
        r.scale = 2
        return r.nsImage ?? NSImage()
    }

    private func notifyIfNeeded() {
        let p = pet
        let needs: [(String, Bool, String)] = [
            ("hungry", p.hatched && p.fullness < 25, "Moffo is hungry 🍓"),
            ("dirty", p.hatched && (p.hygiene < 25 || p.poops >= 2), "Moffo needs a bath 🫧"),
            ("tired", p.hatched && p.energy < 15, "Moffo is exhausted 😴"),
            ("bored", p.hatched && p.fun < 20, "Moffo is bored, play with it!"),
            ("sick", p.sick && !p.dead, "Moffo is sick! Give it some medicine 💊"),
            ("dead", p.dead, "Moffo has passed away… 🪦"),
            ("fact", p.factUnread, "Moffo learned something new! 📚"),
        ]
        for (id, active, text) in needs {
            if !active { alerted.remove(id); continue }
            guard !alerted.contains(id) else { continue }
            alerted.insert(id)
            guard canNotify else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Moffo"
            content.body = text
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
        }
    }
}
