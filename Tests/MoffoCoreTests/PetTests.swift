import XCTest
@testable import MoffoCore

final class PetTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 0)
    func hours(_ h: Double) -> Date { t0.addingTimeInterval(h * 3600) }

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
            pet.feed(); pet.clean(); pet.play(); pet.heal()
            if pet.energy < 50 { pet.toggleSleep() }
        }
        XCTAssertFalse(pet.dead)
        XCTAssertFalse(pet.sick)
        XCTAssertGreaterThan(pet.happiness, 40)
    }

    func testStudyGivesAFact() {
        var pet = Pet(now: t0)
        pet.advance(to: hours(0.1))
        pet.study(now: pet.lastUpdate)
        XCTAssertEqual(pet.activityProgress(now: pet.lastUpdate.addingTimeInterval(90))!, 0.5, accuracy: 0.01)
        pet.advance(to: hours(0.2))
        XCTAssertNil(pet.activityProgress(now: hours(0.2)))
        XCTAssertEqual(pet.activity, .idle)
        XCTAssertTrue(pet.factUnread)
        XCTAssertNotNil(pet.lastFact)
    }
}
