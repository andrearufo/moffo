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
    /// A newer release on GitHub, if any.
    var update: (version: String, url: URL)?

    /// MOFFO_SPEED=60 makes one real minute last an hour. For testing only.
    private let speed = Double(ProcessInfo.processInfo.environment["MOFFO_SPEED"] ?? "") ?? 1
    private let start = Date()
    private var alerted: Set<String> = []
    private var timer: Timer?
    private var updateTimer: Timer?
    private var lastStatsHour = -1
    private static let key = "pet"
    private static let gravesKey = "graves"

    var now: Date { start.addingTimeInterval(Date().timeIntervalSince(start) * speed) }
    private var canNotify: Bool { Bundle.main.bundleIdentifier != nil }  // `swift run` has no bundle

    init() {
        let info = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        Log.write("start", "Moffo \(info) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
                  + " · \(Locale.preferredLanguages.first ?? "?") · speed \(speed)")
        if let data = UserDefaults.standard.data(forKey: Self.key) {
            do { pet = try JSONDecoder().decode(Pet.self, from: data) } catch {
                Log.write("error", "saved pet unreadable, starting a new egg: \(error)")
                pet = Pet()
            }
        } else {
            Log.write("egg", "no saved pet, new egg")
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
        Task { await checkForUpdate() }
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { await self?.checkForUpdate() }
        }
    }

    func tick() {
        let old = pet
        let gap = now.timeIntervalSince(pet.lastUpdate)
        if gap > Pet.awayThreshold && !pet.dead {
            Log.write("away", "\(Self.duration(gap)) away → counted as \(Self.duration(gap / 4))")
        }
        pet.catchUp(to: now)
        logChanges(from: old)
        if old.activity != .idle && old.activity != .studying && pet.activity == .idle && !pet.dead {
            notify("done", Self.doneText[old.activity] ?? "")  // studying already notifies its fact
        }
        let hour = Int(now.timeIntervalSince1970 / 3600)
        if hour != lastStatsHour { lastStatsHour = hour; Log.write("stats", Self.stats(pet)) }
        squish.toggle()
        icon = renderIcon()
        save()
        notifyIfNeeded()
    }

    func act(_ action: (inout Pet) -> Void) {
        pet.catchUp(to: now)
        let old = pet
        action(&pet)
        logChanges(from: old)
        save()
    }

    func newEgg() {
        if pet.dead, let died = pet.diedAt {
            graves.insert(Grave(born: pet.born, died: died, form: pet.form), at: 0)
            if let data = try? JSONEncoder().encode(graves) { UserDefaults.standard.set(data, forKey: Self.gravesKey) }
        }
        pet = Pet(now: now)
        Log.write("egg", "new egg (\(graves.count) in the graveyard)")
        alerted = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pet) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    // MARK: - Updates

    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    func checkForUpdate() async {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let api = URL(string: "https://api.github.com/repos/andrearufo/moffo/releases/latest")!
        do {
            let (data, _) = try await URLSession.shared.data(from: api)
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            guard current.compare(latest, options: .numeric) == .orderedAscending else { update = nil; return }
            let dmg = release.assets.first { $0.name.hasSuffix(".dmg") }?.browser_download_url
            if update?.version != latest { Log.write("update", "\(latest) available (running \(current))") }
            update = (latest, dmg ?? release.html_url)
        } catch {
            Log.write("error", "update check: \(error.localizedDescription)")
        }
    }

    // MARK: - Log

    private func logChanges(from old: Pet) {
        let p = pet
        guard old != p else { return }
        if p.eggTaps != old.eggTaps && !p.hatched { Log.write("egg", "tap \(p.eggTaps)/\(Pet.tapsToHatch)") }
        if p.hatched && !old.hatched { Log.write("hatch", "Moffo hatched!") }
        if p.activity != old.activity {
            if old.activity != .idle { Log.write("done", "\(old.activity.rawValue) · \(Self.stats(p))") }
            if p.activity == .sleeping { Log.write("start", "sleeping") }
            else if p.activity != .idle { Log.write("start", "\(p.activity.rawValue) (−\(Int(old.energy - p.energy)) energy)") }
        }
        if p.hatched && p.stage != old.stage { Log.write("grow", "\(p.stage)") }
        if let form = p.form, old.form == nil { Log.write("grow", "adult form \(form.rawValue) (care \(Int(p.care)))") }
        if p.poops > old.poops { Log.write("poop", "\(p.poops) on the floor") }
        if p.sick != old.sick { Log.write("health", p.sick ? "got sick · \(Self.stats(p))" : "cured") }
        if p.factUnread && !old.factUnread, let fact = p.lastFact { Log.write("fact", fact) }
        if p.dead && !old.dead { Log.write("death", "died at \(Self.duration(p.age)) · \(Self.stats(p))") }
    }

    private static func stats(_ p: Pet) -> String {
        let v = [("full", p.fullness), ("hyg", p.hygiene), ("en", p.energy), ("fun", p.fun),
                 ("smart", p.smarts), ("hp", p.health)].map { "\($0) \(Int($1))" }
        return v.joined(separator: " ") + " · ♥ \(Int(p.happiness))" + (p.poops > 0 ? " · 💩\(p.poops)" : "")
    }

    private static func duration(_ s: TimeInterval) -> String {
        let m = Int(s / 60)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
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
            notify(id, text)
        }
    }

    private static let doneText: [Activity: String] = [
        .eating: String(localized: "Moffo finished eating 🍓"),
        .playing: String(localized: "Moffo finished playing ⚽️"),
        .bathing: String(localized: "Moffo is squeaky clean 🫧"),
        .healing: String(localized: "Moffo took its medicine 💊"),
        .sleeping: String(localized: "Moffo woke up full of energy ☀️"),
    ]

    private func notify(_ id: String, _ text: String) {
        Log.write("notify", id)
        guard canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = "Moffo"
        content.body = text
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
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
            catch { Log.write("error", "login item: \(error)") }
        }
    }
}
