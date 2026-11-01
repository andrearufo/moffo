import SwiftUI
import UserNotifications
import ServiceManagement
import MoffoCore

@Observable @MainActor
final class PetStore {
    var pet: Pet
    var squish = false
    var icon = NSImage()
    var graves: [Grave] = []

    /// MOFFO_SPEED=60 makes one real minute last an hour. For testing only.
    private let speed = Double(ProcessInfo.processInfo.environment["MOFFO_SPEED"] ?? "") ?? 1
    private let start = Date()
    private var alerted: Set<String> = []
    private var timer: Timer?
    private static let key = "pet"
    private static let gravesKey = "graves"

    var now: Date { start.addingTimeInterval(Date().timeIntervalSince(start) * speed) }
    private var canNotify: Bool { Bundle.main.bundleIdentifier != nil }  // `swift run` has no bundle

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Pet.self, from: data) {
            pet = saved
        } else {
            pet = Pet()
        }
        if let data = UserDefaults.standard.data(forKey: Self.gravesKey) {
            graves = (try? JSONDecoder().decode([Grave].self, from: data)) ?? []
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
        pet.catchUp(to: now)
        squish.toggle()
        icon = renderIcon()
        save()
        notifyIfNeeded()
    }

    func act(_ action: (inout Pet) -> Void) {
        pet.catchUp(to: now)
        action(&pet)
        save()
    }

    func newEgg() {
        if pet.dead, let died = pet.diedAt {
            graves.insert(Grave(born: pet.born, died: died, form: pet.form), at: 0)
            if let data = try? JSONEncoder().encode(graves) { UserDefaults.standard.set(data, forKey: Self.gravesKey) }
        }
        pet = Pet(now: now)
        alerted = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pet) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    private func renderIcon() -> NSImage {
        let progress = pet.activityProgress(now: now)
        let content = HStack(spacing: 3) {
            Jelly(mood: pet.mood, squish: squish, size: 18, detailed: false)
            if let progress {
                Ring(value: progress, color: pet.activity == .sleeping ? .indigo : .pink, lineWidth: 2.5)
                    .frame(width: 13, height: 13)
            }
        }
        let r = ImageRenderer(content: content)
        r.scale = 2
        return r.nsImage ?? NSImage()
    }

    private func notifyIfNeeded() {
        let p = pet
        let needs: [(String, Bool, String)] = [
            ("hungry", p.hatched && p.fullness < 25, String(localized: "Moffo is hungry 🍓")),
            ("dirty", p.hatched && (p.hygiene < 25 || p.poops >= 2), String(localized: "Moffo needs a bath 🫧")),
            ("tired", p.hatched && p.energy < 15, String(localized: "Moffo is exhausted 😴")),
            ("bored", p.hatched && p.fun < 20, String(localized: "Moffo is bored, play with it!")),
            ("sick", p.sick && !p.dead, String(localized: "Moffo is sick! Give it some medicine 💊")),
            ("dead", p.dead, String(localized: "Moffo has passed away… 🪦")),
            ("fact", p.factUnread, String(localized: "Moffo learned something new! 📚")),
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

struct Grave: Codable, Hashable {
    let born: Date
    let died: Date
    let form: AdultForm?
}

/// Thin wrapper so the view can bind a Toggle to the login item.
enum LoginItem {
    static var enabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do { try newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
            catch { NSLog("Moffo login item: \(error)") }
        }
    }
}
