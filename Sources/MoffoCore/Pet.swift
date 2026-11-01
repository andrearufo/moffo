import Foundation

public enum Activity: String, Codable { case idle, sleeping, studying }

public enum Mood { case egg, dead, sleeping, studying, sick, sad, ok, happy }

/// The whole simulation. Time only moves through `advance(to:)`, one minute per step,
/// so the pet keeps living (and starving) while the Mac is off.
public struct Pet: Codable, Equatable {
    public var born: Date
    public var hatched = false
    public var fullness = 80.0, hygiene = 80.0, energy = 80.0, fun = 80.0, smarts = 20.0
    public var health = 100.0
    public var sick = false
    public var diedAt: Date?
    public var poops = 0
    public var activity = Activity.idle
    public var studyEnds: Date?
    public var lastFact: String?
    public var factUnread = false
    public var lastPoop: Date
    public var lastUpdate: Date

    public var dead: Bool { diedAt != nil }

    public init(now: Date = .now) {
        born = now; lastPoop = now; lastUpdate = now
    }

    // MARK: - Simulation

    public mutating func advance(to now: Date) {
        while !dead && lastUpdate.addingTimeInterval(60) <= now { step() }
    }

    private mutating func step() {
        lastUpdate += 60
        guard hatched else {
            hatched = lastUpdate.timeIntervalSince(born) >= 60
            return
        }
        let h = 1.0 / 60  // one minute, rates below are per hour
        fullness -= 4 * h
        hygiene -= (3 + Double(poops)) * h
        fun -= 3 * h
        smarts -= 1 * h

        switch activity {
        case .sleeping:
            energy += 25 * h
            if energy >= 100 { activity = .idle }
        case .studying:
            energy -= 6 * h
            if let end = studyEnds, lastUpdate >= end {
                activity = .idle; studyEnds = nil
                smarts += 30; fun += 10
                lastFact = facts.randomElement(); factUnread = true
            }
        case .idle:
            energy -= 3 * h
        }

        if lastUpdate.timeIntervalSince(lastPoop) >= 4 * 3600 {
            poops = min(poops + 1, 6); lastPoop = lastUpdate
        }
        clamp()

        let zeros = [fullness, hygiene, energy, fun].filter { $0 <= 0 }.count
        if zeros > 0 || poops >= 4 { sick = true }
        health += sick ? -(1.5 + 0.5 * Double(zeros)) * h : 2 * h
        clamp()
        if health <= 0 { diedAt = lastUpdate }
    }

    private mutating func clamp() {
        func c(_ v: inout Double) { v = min(100, max(0, v)) }
        c(&fullness); c(&hygiene); c(&energy); c(&fun); c(&smarts); c(&health)
    }

    // MARK: - Actions

    public var canAct: Bool { hatched && !dead && activity == .idle }

    public mutating func feed() { guard canAct else { return }; fullness += 25; clamp() }
    public mutating func play() { guard canAct, energy >= 10 else { return }; fun += 20; energy -= 5; clamp() }
    public mutating func clean() { guard hatched, !dead else { return }; poops = 0; hygiene = 100 }
    public mutating func heal() { guard hatched, !dead, sick else { return }; sick = false; health += 10; clamp() }

    public mutating func toggleSleep() {
        guard hatched, !dead else { return }
        if activity == .sleeping { activity = .idle } else if activity == .idle { activity = .sleeping }
    }

    public mutating func study(now: Date, minutes: Double = 3) {
        guard canAct, energy >= 15 else { return }
        activity = .studying
        studyEnds = now.addingTimeInterval(minutes * 60)
    }

    // MARK: - Derived

    /// 0...100. Smarts counts half, sickness halves it, each poop costs 5.
    public var happiness: Double {
        guard hatched, !dead else { return 0 }
        var v = (fullness + hygiene + energy + fun + smarts * 0.5) / 4.5
        if sick { v *= 0.5 }
        return max(0, v - Double(poops) * 5)
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
