import Foundation

public enum Activity: String, Codable, CaseIterable {
    case idle, sleeping, eating, playing, bathing, healing, studying

    /// Timed activities: how long they take and the energy they cost up front.
    /// Their benefit lands only when they finish. Sleep has no fixed length: it ends when energy is full.
    public var cost: (minutes: Double, energy: Double)? {
        switch self {
        case .idle, .sleeping: nil
        case .eating: (1, 2)
        case .bathing: (1, 4)
        case .healing: (1, 2)
        case .playing: (2, 8)
        case .studying: (3, 10)
        }
    }
}

public enum Mood { case egg, dead, sleeping, studying, sick, sad, ok, happy }

public enum Stage { case egg, baby, child, adult }

/// What an adult turns into, picked by how well it was cared for while growing up.
public enum AdultForm: String, Codable { case shiny, classic, grumpy }

/// The whole simulation. Time only moves through `advance(to:)`, one minute per step,
/// so the pet keeps living (and starving) while the Mac is off.
public struct Pet: Codable, Equatable {
    public var born: Date
    public var hatched = false
    public var eggTaps = 0
    public var fullness = 80.0, hygiene = 80.0, energy = 80.0, fun = 80.0, smarts = 20.0
    public var health = 100.0
    public var sick = false
    public var diedAt: Date?
    public var poops = 0
    public var activity = Activity.idle
    public var activityEnds: Date?
    public var lastFact: String?
    public var factUnread = false
    public var lastPoop: Date
    public var lastUpdate: Date
    public var careSum = 0.0, careSteps = 0
    public var form: AdultForm?

    public var dead: Bool { diedAt != nil }
    public var age: TimeInterval { (diedAt ?? lastUpdate).timeIntervalSince(born) }
    public var care: Double { careSteps > 0 ? careSum / Double(careSteps) : 0 }

    public var stage: Stage {
        if !hatched { return .egg }
        return age < 86400 ? .baby : age < 3 * 86400 ? .child : .adult
    }

    public init(now: Date = .now) {
        born = now; lastPoop = now; lastUpdate = now
    }

    // MARK: - Simulation

    /// Gaps longer than this mean the Mac was off/asleep or the app closed.
    public static let awayThreshold: TimeInterval = 10 * 60

    /// Like `advance`, but away time only counts for a quarter, so a weekend away doesn't kill Moffo.
    // ponytail: fixed 1/4 rate, add an explicit vacation pause if people leave for weeks
    public mutating func catchUp(to now: Date) {
        let gap = now.timeIntervalSince(lastUpdate)
        if gap > Self.awayThreshold && !dead {
            let skipped = gap * 0.75
            lastUpdate += skipped
            lastPoop += skipped
            activityEnds = activityEnds.map { $0 + skipped }
        }
        advance(to: now)
    }

    public mutating func advance(to now: Date) {
        while !dead && lastUpdate.addingTimeInterval(60) <= now { step() }
        // steps are a minute apart: don't leave a finished activity hanging until the next one
        if !dead, activity.cost != nil, let end = activityEnds, now >= end { finishActivity() }
    }

    private mutating func step() {
        lastUpdate += 60
        guard hatched else { return }  // an egg waits for you, see tapEgg
        let h = 1.0 / 60  // one minute, rates below are per hour
        fullness -= 4 * h
        hygiene -= (3 + Double(poops)) * h
        fun -= 3 * h
        smarts -= 1 * h

        if activity == .sleeping {
            energy += 25 * h
            if energy >= 100 { activity = .idle }
        } else {
            energy -= 3 * h
            // nil end: an activity saved by an older version, just finish it
            if activity != .idle, lastUpdate >= activityEnds ?? .distantPast { finishActivity() }
        }

        if lastUpdate.timeIntervalSince(lastPoop) >= 4 * 3600 {
            poops = min(poops + 1, 6); lastPoop = lastUpdate
        }
        clamp()

        let zeros = [fullness, hygiene, energy, fun].filter { $0 <= 0 }.count
        if !sickCauses.isEmpty { sick = true }
        health += sick ? -(1.5 + 0.5 * Double(zeros)) * h : 2 * h
        clamp()
        if health <= 0 { diedAt = lastUpdate }

        careSum += happiness; careSteps += 1
        if form == nil && stage == .adult {
            form = care >= 60 ? .shiny : care < 35 ? .grumpy : .classic
        }
    }

    private mutating func finishActivity() {
        switch activity {
        case .eating: fullness += gain(.eating)
        case .playing: fun += gain(.playing)
        case .bathing: hygiene += gain(.bathing); poops = 0
        case .healing: sick = false; health += 10
        case .studying:
            smarts += gain(.studying); fun += 10
            lastFact = facts.randomElement(); factUnread = true
        case .idle, .sleeping: break
        }
        activity = .idle
        activityEnds = nil
        clamp()
    }

    private mutating func clamp() {
        func c(_ v: inout Double) { v = min(100, max(0, v)) }
        c(&fullness); c(&hygiene); c(&energy); c(&fun); c(&smarts); c(&health)
    }

    // MARK: - Actions

    public func canStart(_ a: Activity) -> Bool {
        guard hatched, !dead, activity == .idle, let cost = a.cost, energy >= cost.energy else { return false }
        return a != .healing || sick
    }

    public mutating func start(_ a: Activity, now: Date) {
        guard canStart(a), let cost = a.cost else { return }
        energy -= cost.energy
        activity = a
        activityEnds = now.addingTimeInterval(cost.minutes * 60)
    }

    public static let tapsToHatch = 10

    /// Each tap cracks the egg a bit more. Age counts from hatching.
    public mutating func tapEgg(now: Date) {
        guard !hatched else { return }
        eggTaps += 1
        if eggTaps >= Self.tapsToHatch {
            hatched = true
            born = now; lastPoop = now; lastUpdate = now
        }
    }

    public mutating func toggleSleep() {
        guard hatched, !dead else { return }
        if activity == .sleeping { activity = .idle } else if activity == .idle { activity = .sleeping }
    }

    // MARK: - Derived

    /// 0...100. Smarts counts half, sickness halves it, each poop costs 5.
    public var happiness: Double {
        guard hatched, !dead else { return 0 }
        var v = (fullness + hygiene + energy + fun + smarts * 0.5) / 4.5
        if sick { v *= 0.5 }
        return max(0, v - Double(poops) * 5)
    }

    /// How much an activity raises its stat. A neglected stat recovers slowly: at 0 it gets 40%
    /// of the base amount, at 100 all of it, so hours of neglect take several actions to undo.
    public func gain(_ a: Activity) -> Double {
        func recover(_ base: Double, _ value: Double) -> Double { base * (0.4 + 0.6 * value / 100) }
        switch a {
        case .eating: return recover(25, fullness)
        case .playing: return recover(20, fun)
        case .bathing: return recover(45, hygiene)
        case .studying: return recover(30, smarts)
        case .healing: return 10
        case .idle, .sleeping: return 0
        }
    }

    /// What makes it sick: medicine won't stick while any of these is still true.
    public var sickCauses: [String] {
        [("poops", poops >= 4), ("fullness", fullness <= 0), ("hygiene", hygiene <= 0),
         ("energy", energy <= 0), ("fun", fun <= 0)].filter(\.1).map(\.0)
    }

    /// 0...1 for the running activity, nil when idle. Sleep progress is energy.
    public func activityProgress(now: Date) -> Double? {
        if activity == .sleeping { return energy / 100 }
        guard let cost = activity.cost, let end = activityEnds else { return nil }
        return min(1, max(0, 1 - end.timeIntervalSince(now) / (cost.minutes * 60)))
    }

    public var mood: Mood {
        if dead { return .dead }
        if !hatched { return .egg }
        if activity == .sleeping { return .sleeping }
        if activity == .studying { return .studying }
        if sick { return .sick }
        return happiness < 35 ? .sad : happiness < 70 ? .ok : .happy
    }
}
