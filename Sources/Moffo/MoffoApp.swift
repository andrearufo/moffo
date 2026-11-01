import SwiftUI
import MoffoCore

@main
struct MoffoApp: App {
    @State private var store = PetStore()

    var body: some Scene {
        MenuBarExtra {
            PetView(store: store)
        } label: {
            Image(nsImage: store.icon)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PetView: View {
    let store: PetStore
    private var pet: Pet { store.pet }

    var body: some View {
        VStack(spacing: 12) {
            Jelly(mood: pet.mood, squish: store.squish, size: 120)
                .animation(.spring(duration: 0.5, bounce: 0.5), value: store.squish)

            VStack(spacing: 2) {
                Text("Moffo").font(.title2.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            if pet.dead {
                Button("Hatch a new egg 🥚") { store.newEgg() }.controlSize(.large)
            } else if pet.hatched {
                stats
                if pet.factUnread, let fact = pet.lastFact { factCard(fact) }
                actions
            } else {
                Text("Something is moving inside the egg…").font(.callout)
            }

            Divider()
            Button("Quit Moffo") { NSApp.terminate(nil) }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var subtitle: String {
        let end = pet.diedAt ?? store.now
        let h = Int(end.timeIntervalSince(pet.born) / 3600)
        let age = h >= 24 ? "\(h / 24)d \(h % 24)h" : "\(h)h"
        if pet.dead { return "Lived \(age)" }
        if !pet.hatched { return "Egg" }
        let status: String = switch pet.mood {
        case .sleeping: "Sleeping"
        case .studying: "Studying… \(max(0, Int(pet.studyEnds?.timeIntervalSince(store.now) ?? 0)))s left"
        case .sick: "Sick!"
        case .sad: "Sad"
        case .ok: "Okay"
        default: "Happy"
        }
        return "Age \(age) · \(status)"
    }

    private var stats: some View {
        VStack(spacing: 6) {
            stat("heart.fill", "Happiness", pet.happiness, .pink)
            Divider()
            stat("fork.knife", "Fullness", pet.fullness, .orange)
            stat("drop.fill", "Hygiene", pet.hygiene, .cyan)
            stat("bolt.fill", "Energy", pet.energy, .yellow)
            stat("gamecontroller.fill", "Fun", pet.fun, .purple)
            stat("book.fill", "Smarts", pet.smarts, .blue)
            stat("cross.case.fill", "Health", pet.health, .green)
            if pet.poops > 0 {
                Text(String(repeating: "💩", count: pet.poops)).font(.title3)
            }
        }
    }

    private func stat(_ icon: String, _ name: String, _ value: Double, _ color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 18)
            Text(name).font(.caption).frame(width: 64, alignment: .leading)
            ProgressView(value: value, total: 100).tint(value < 25 ? .red : color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(Int(value)) percent")
    }

    private func factCard(_ fact: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("📚 Moffo learned:").font(.caption.bold())
            Text(fact).font(.callout).fixedSize(horizontal: false, vertical: true)
            Button("Cool!") { store.act { $0.factUnread = false } }.controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var actions: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                action("Feed", "fork.knife", enabled: pet.canAct) { $0.feed() }
                action("Play", "gamecontroller", enabled: pet.canAct && pet.energy >= 10) { $0.play() }
                action("Bath", "bubbles.and.sparkles", enabled: true) { $0.clean() }
            }
            GridRow {
                action(pet.activity == .sleeping ? "Wake" : "Sleep", pet.activity == .sleeping ? "sun.max" : "moon.zzz",
                       enabled: pet.activity != .studying) { $0.toggleSleep() }
                action("Study", "book", enabled: pet.canAct && pet.energy >= 15) { [now = store.now] in $0.study(now: now) }
                action("Medicine", "pills", enabled: pet.sick) { $0.heal() }
            }
        }
    }

    private func action(_ title: String, _ icon: String, enabled: Bool, _ run: @escaping (inout Pet) -> Void) -> some View {
        Button { store.act(run) } label: {
            Label(title, systemImage: icon).labelStyle(.titleAndIcon).frame(maxWidth: .infinity)
        }
        .controlSize(.regular)
        .disabled(!enabled)
    }
}
