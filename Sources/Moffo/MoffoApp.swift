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
    @State private var showGraves = false
    @State private var hovered: String?
    @State private var wobble = 0.0

    var body: some View {
        VStack(spacing: 12) {
            Jelly(mood: pet.mood, stage: pet.stage, form: pet.form, activity: pet.activity, squish: store.squish,
                  crack: Double(pet.eggTaps) / Double(Pet.tapsToHatch), size: 120)
                .animation(.spring(duration: 0.5, bounce: 0.5), value: store.squish)
                .rotationEffect(.degrees(wobble), anchor: .bottom)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !pet.hatched else { return }
                    store.act { [now = store.now] in $0.tapEgg(now: now) }
                    wobble = pet.eggTaps.isMultiple(of: 2) ? 12 : -12
                    withAnimation(.spring(duration: 0.4, bounce: 0.7)) { wobble = 0 }
                }

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
                Text("Tap the egg to help it hatch! (\(pet.eggTaps)/\(Pet.tapsToHatch))").font(.callout)
            }

            if showGraves { graveyard }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Header

    private func ageText(_ seconds: TimeInterval) -> String {
        let h = Int(seconds / 3600)
        return h >= 24 ? String(localized: "\(h / 24)d \(h % 24)h") : String(localized: "\(h)h")
    }

    private func stageName(_ stage: Stage, _ form: AdultForm?) -> String {
        switch (stage, form) {
        case (.egg, _): String(localized: "Egg")
        case (.baby, _): String(localized: "Baby")
        case (.child, _): String(localized: "Child")
        case (_, .shiny): String(localized: "Shiny adult")
        case (_, .grumpy): String(localized: "Grumpy adult")
        default: String(localized: "Adult")
        }
    }

    private var subtitle: String {
        if pet.dead { return String(localized: "Lived \(ageText(pet.age))") }
        if !pet.hatched { return stageName(.egg, nil) }
        let status: String
        if let verb = verbs[pet.activity] {
            status = "\(verb)… \(max(0, Int(pet.activityEnds?.timeIntervalSince(store.now) ?? 0)))s"
        } else {
            status = switch pet.mood {
            case .sleeping: String(localized: "Sleeping")
            case .sick: String(localized: "Sick!")
            case .sad: String(localized: "Sad")
            case .ok: String(localized: "Okay")
            default: String(localized: "Happy")
            }
        }
        return [stageName(pet.stage, pet.form), ageText(pet.age), status].joined(separator: " · ")
    }

    // MARK: - Stats

    private var statList: [(icon: String, name: String, value: Double, color: Color)] {
        [("fork.knife", String(localized: "Fullness"), pet.fullness, .orange),
         ("drop.fill", String(localized: "Hygiene"), pet.hygiene, .cyan),
         ("bolt.fill", String(localized: "Energy"), pet.energy, .yellow),
         ("gamecontroller.fill", String(localized: "Fun"), pet.fun, .purple),
         ("book.fill", String(localized: "Smarts"), pet.smarts, .blue),
         ("cross.case.fill", String(localized: "Health"), pet.health, .green)]
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
            .help(showDetails ? String(localized: "Hide details") : String(localized: "Show details"))
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
            Text(NSLocalizedString(fact, comment: "")).font(.callout).fixedSize(horizontal: false, vertical: true)
            Button("Cool!") { store.act { $0.factUnread = false } }.controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private var actions: some View {
        let sleeping = pet.activity == .sleeping
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                timed("fork.knife", .eating, String(localized: "Feed"), String(localized: "+25 fullness"))
                timed("gamecontroller.fill", .playing, String(localized: "Play"), String(localized: "+20 fun"))
                timed("bubbles.and.sparkles.fill", .bathing, String(localized: "Bath"), String(localized: "cleans up, hygiene to 100"))
                action(sleeping ? "sun.max.fill" : "moon.zzz.fill",
                       sleeping ? String(localized: "Wake up") : String(localized: "Sleep · until energy is full"),
                       enabled: sleeping || pet.activity == .idle, active: sleeping) { $0.toggleSleep() }
                timed("book.fill", .studying, String(localized: "Study"), String(localized: "+30 smarts, learns a fact"))
                timed("pills.fill", .healing, String(localized: "Medicine"), String(localized: "cures sickness"))
            }
            Text(hovered ?? " ").font(.caption).foregroundStyle(.secondary)
        }
    }

    private let verbs: [Activity: String] = [
        .eating: String(localized: "Eating"), .playing: String(localized: "Playing"),
        .bathing: String(localized: "Bathing"), .healing: String(localized: "Taking medicine"),
        .studying: String(localized: "Studying"),
    ]

    private func timed(_ icon: String, _ a: Activity, _ title: String, _ effect: String) -> some View {
        let cost = a.cost!
        let hint = String(localized: "\(title) · \(Int(cost.minutes)) min, −\(Int(cost.energy)) energy → \(effect)")
        return action(icon, hint, enabled: pet.canStart(a), active: pet.activity == a) {
            [now = store.now] in $0.start(a, now: now)
        }
    }

    private func action(_ icon: String, _ hint: String, enabled: Bool, active: Bool = false,
                        _ run: @escaping (inout Pet) -> Void) -> some View {
        Button { store.act(run) } label: {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 34, height: 34)
                .background(Circle().fill(active || (hovered == hint && enabled) ? Color.pink.opacity(0.25) : Color.primary.opacity(0.07)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled || active ? 1 : 0.35)
        .onHover { inside in
            if inside { hovered = hint } else if hovered == hint { hovered = nil }
        }
        .accessibilityLabel(hint)
    }

    // MARK: - Footer

    private var graveyard: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(store.graves, id: \.self) { g in
                HStack {
                    Text("🪦")
                    Text("\(stageName(g.died.timeIntervalSince(g.born) < 3 * 86400 ? .child : .adult, g.form)) · \(ageText(g.died.timeIntervalSince(g.born)))")
                    Spacer()
                    Text(g.died, format: .dateTime.day().month()).foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack {
            Toggle("Open at login", isOn: Binding(get: { LoginItem.enabled }, set: { LoginItem.enabled = $0 }))
                .toggleStyle(.checkbox)
            Spacer()
            if !store.graves.isEmpty {
                Button("🪦 \(store.graves.count)") { withAnimation(.snappy) { showGraves.toggle() } }
                    .help("Past lives")
            }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(.secondary)
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
