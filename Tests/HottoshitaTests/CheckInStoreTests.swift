import XCTest
@testable import Hottoshita

@MainActor
final class CheckInStoreTests: XCTestCase {

    var store: CheckInStore!
    var tempURL: URL!

    override func setUp() async throws {
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        store = CheckInStore(fileURL: tempURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Initial state

    func testInitiallyEmpty() {
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testSubmittedTodayFalseWhenEmpty() {
        XCTAssertFalse(store.submittedToday)
    }

    // MARK: - Saving

    func testSaveAddsEntry() {
        store.save(CheckInAnswers())
        XCTAssertEqual(store.entries.count, 1)
    }

    func testSaveMultipleEntries() {
        store.save(CheckInAnswers())
        store.save(CheckInAnswers())
        XCTAssertEqual(store.entries.count, 2)
    }

    func testSubmittedTodayTrueAfterSave() {
        store.save(CheckInAnswers())
        XCTAssertTrue(store.submittedToday)
    }

    func testSubmittedTodayFalseForYesterdayEntry() {
        var answers = CheckInAnswers()
        answers.date = Date().addingTimeInterval(-86_400)
        store.save(answers)
        XCTAssertFalse(store.submittedToday)
    }

    // MARK: - Persistence

    func testEntriesPersistedAcrossInstances() {
        store.save(CheckInAnswers())
        let reloaded = CheckInStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.entries.count, 1)
    }

    func testEntryDataPreservedAfterReload() {
        var answers = CheckInAnswers()
        answers.sleep = .deeply
        answers.feelings = ["Happy", "Calm"]
        answers.tookBloodPressure = true
        answers.bloodPressure = BloodPressure(systolic: "120", diastolic: "80")
        store.save(answers)

        let reloaded = CheckInStore(fileURL: tempURL)
        let entry = try! XCTUnwrap(reloaded.entries.first)
        XCTAssertEqual(entry.sleep, .deeply)
        XCTAssertEqual(entry.feelings, ["Happy", "Calm"])
        XCTAssertEqual(entry.tookBloodPressure, true)
        XCTAssertEqual(entry.bloodPressure.systolic, "120")
        XCTAssertEqual(entry.bloodPressure.diastolic, "80")
    }
}
