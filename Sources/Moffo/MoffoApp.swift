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
    @State private var showDetails = false
    @State private var hovered: String?

    var body: some View {
        VStack(spacing: 12) {
            Jelly(mood: pet.mood, squish: store.squish, size: 120)
                .animation(.spring(duration: 0.5, bounce: 0.5), value: store.squish)

            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Text("Moffo").font(.title2.bold())
                    if pet.hatched && !pet.dead {
                        Label("\(Int(pet.happiness))%", systemImage: "heart.fill")
                            .font(.callout.bold().monospacedDigit()).foregroundStyle(.pink)
                            .help("Happiness")
                    }
                }
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

    private var statList: [(icon: String, name: String, value: Double, color: Color)] {
        [("fork.knife", "Fullness", pet.fullness, .orange),
         ("drop.fill", "Hygiene", pet.hygiene, .cyan),
         ("bolt.fill", "Energy", pet.energy, .yellow),
         ("gamecontroller.fill", "Fun", pet.fun, .purple),
         ("book.fill", "Smarts", pet.smarts, .blue),
         ("cross.case.fill", "Health", pet.health, .green)]
    }

    private var stats: some View {
        VStack(spacing: 8) {
            Button { withAnimation(.snappy) { showDetails.toggle() } } label: {
                HStack(spacing: 10) {
                    ForEach(statList, id: \.name) { s in
                        Ring(value: s.value / 100, color: s.value < 25 ? .red : s.color, lineWidth: 3)
                            .overlay(Image(systemName: s.icon).font(.system(size: 10))
                                .foregroundStyle(s.value < 25 ? .red : s.color))
                            .frame(width: 30, height: 30)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(showDetails ? "Hide details" : "Show details")
            .accessibilityLabel("Stats")

            if showDetails {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    ForEach(statList, id: \.name) { s in
                        GridRow {
                            Text(s.name).font(.caption)
                            ProgressView(value: s.value, total: 100).tint(s.value < 25 ? .red : s.color)
                            Text("\(Int(s.value))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if pet.poops > 0 {
                Text(String(repeating: "💩", count: pet.poops)).font(.title3)
            }
        }
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
        let sleeping = pet.activity == .sleeping
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                action("fork.knife", "Feed · +25 fullness", enabled: pet.canAct) { $0.feed() }
                action("gamecontroller.fill", "Play · +20 fun, −5 energy", enabled: pet.canAct && pet.energy >= 10) { $0.play() }
                action("bubbles.and.sparkles.fill", "Bath · cleans up, hygiene to 100", enabled: true) { $0.clean() }
                action(sleeping ? "sun.max.fill" : "moon.zzz.fill", sleeping ? "Wake up" : "Sleep · recharges energy",
                       enabled: pet.activity != .studying) { $0.toggleSleep() }
                action("book.fill", "Study · \(Int(Pet.studyMinutes)) min, learns a fact", enabled: pet.canAct && pet.energy >= 15) {
                    [now = store.now] in $0.study(now: now)
                }
                action("pills.fill", "Medicine · cures sickness", enabled: pet.sick) { $0.heal() }
            }
            Text(hovered ?? " ").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func action(_ icon: String, _ hint: String, enabled: Bool, _ run: @escaping (inout Pet) -> Void) -> some View {
        Button { store.act(run) } label: {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 34, height: 34)
                .background(Circle().fill(hovered == hint && enabled ? Color.pink.opacity(0.25) : Color.primary.opacity(0.07)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .onHover { inside in
            if inside { hovered = hint } else if hovered == hint { hovered = nil }
        }
        .accessibilityLabel(hint)
    }
}

/// Circular gauge, also drawn in the menu bar icon.
struct Ring: View {
    var value: Double
    var color: Color
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0.001, value))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}
