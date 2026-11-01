import XCTest
@testable import MoffoCore

final class PetTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 0)
    func hours(_ h: Double) -> Date { t0.addingTimeInterval(h * 3600) }

    /// Starts an activity and lets it run to the end.
    func run(_ a: Activity, on pet: inout Pet) {
        pet.start(a, now: pet.lastUpdate)
        pet.advance(to: pet.lastUpdate.addingTimeInterval(((a.cost?.minutes ?? 0) + 1) * 60))
    }

    func testIgnoredPetDiesInAboutTwoDays() {
        var pet = Pet(now: t0)
        pet.advance(to: hours(24 * 10))
        let lived = pet.diedAt!.timeIntervalSince(t0) / 3600
        XCTAssert((36...72).contains(lived), "lived \(lived)h")
    }

    func testCaredPetSurvivesAWeek() {
        var pet = Pet(now: t0)
        for i in 1...(7 * 4) {  // every 6 hours
            pet.advance(to: hours(Double(i) * 6))
            if pet.activity == .sleeping { pet.toggleSleep() }
            for a: Activity in [.eating, .bathing, .playing, .healing] { run(a, on: &pet) }
            if pet.energy < 50 { pet.toggleSleep() }
        }
        XCTAssertFalse(pet.dead)
        XCTAssertFalse(pet.sick)
        XCTAssertGreaterThan(pet.happiness, 40)
    }

    func testActivitiesCostEnergyAndPayOffOnlyAtTheEnd() {
        var pet = Pet(now: t0)
        pet.advance(to: hours(0.1))
        let before = pet
        pet.start(.eating, now: pet.lastUpdate)
        XCTAssertEqual(pet.energy, before.energy - 2)
        XCTAssertEqual(pet.fullness, before.fullness)  // not fed yet
        XCTAssertFalse(pet.canStart(.playing))         // busy
        run(.idle, on: &pet)
        XCTAssertEqual(pet.activity, .idle)
        XCTAssertGreaterThan(pet.fullness, before.fullness + 20)
        XCTAssertLessThan(pet.fun, before.fun)         // other stats kept dropping
    }

    func testStudyGivesAFact() {
        var pet = Pet(now: t0)
        pet.advance(to: hours(0.1))
        pet.start(.studying, now: pet.lastUpdate)
        XCTAssertEqual(pet.activityProgress(now: pet.lastUpdate.addingTimeInterval(90))!, 0.5, accuracy: 0.01)
        pet.advance(to: hours(0.2))
        XCTAssertNil(pet.activityProgress(now: hours(0.2)))
        XCTAssertTrue(pet.factUnread)
        XCTAssertNotNil(pet.lastFact)
    }

    func testTooTiredToPlay() {
        var pet = Pet(now: t0)
        pet.advance(to: hours(0.1))
        pet.energy = 5
        XCTAssertFalse(pet.canStart(.playing))
        XCTAssertTrue(pet.canStart(.eating))
    }
}
