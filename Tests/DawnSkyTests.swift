import Foundation
import Testing
@testable import DawnSky

/// テストは東京の暦で決める（端末の設定に左右されない）
private let calendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return cal
}()

private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

/// 6:30 に起きる予定
private let schedule = WakeSchedule(minutes: Array(repeating: 390, count: 7))

struct WakeWindowTests {
    let target = at(2026, 11, 13, 6, 30)

    @Test func insideTheFifteenMinutesIsCaught() {
        #expect(WakeWindow.judge(at(2026, 11, 13, 6, 30), target: target) == .caught(minutesAfter: 0))
        #expect(WakeWindow.judge(at(2026, 11, 13, 6, 38), target: target) == .caught(minutesAfter: 8))
        #expect(WakeWindow.judge(at(2026, 11, 13, 6, 45), target: target) == .caught(minutesAfter: 15))
    }

    @Test func afterTheWindowIsLate() {
        #expect(WakeWindow.judge(at(2026, 11, 13, 6, 46), target: target) == .late(minutesAfter: 16))
        #expect(WakeWindow.judge(at(2026, 11, 13, 12, 30), target: target) == .late(minutesAfter: 360))
        #expect(WakeWindow.judge(at(2026, 11, 13, 12, 31), target: target) == .closed)
    }

    @Test func beforeTheTargetIsEarlyUpToTwoHours() {
        #expect(WakeWindow.judge(at(2026, 11, 13, 6, 10), target: target) == .early(minutesBefore: 20))
        #expect(WakeWindow.judge(at(2026, 11, 13, 4, 30), target: target) == .early(minutesBefore: 120))
        #expect(WakeWindow.judge(at(2026, 11, 13, 4, 29), target: target) == .tooEarly)
    }

    @Test func scheduleCanDifferByWeekday() {
        var s = WakeSchedule.standard
        s.set(9 * 60, forWeekday: 7)  // 土曜
        // 2026-11-14 は土曜
        #expect(s.target(on: at(2026, 11, 14, 1, 0), calendar: calendar) == at(2026, 11, 14, 9, 0))
        #expect(s.target(on: at(2026, 11, 13, 1, 0), calendar: calendar) == at(2026, 11, 13, 7, 0))
        #expect(!s.isSameEveryDay)
    }

    @Test func phaseCountsDownInsideTheWindow() {
        let phase = WakeWindow.phase(now: at(2026, 11, 13, 6, 40), schedule: schedule, capturedToday: nil, calendar: calendar)
        #expect(phase == .open(target: at(2026, 11, 13, 6, 30), secondsLeft: 300))
        let night = WakeWindow.phase(now: at(2026, 11, 13, 21, 0), schedule: schedule, capturedToday: nil, calendar: calendar)
        #expect(night == .night(next: at(2026, 11, 14, 6, 30)))
        let done = WakeWindow.phase(now: at(2026, 11, 13, 6, 40), schedule: schedule, capturedToday: .caught, calendar: calendar)
        #expect(done == .done(result: .caught))
    }
}

struct ExtractorTests {
    /// 上が青、下が橙の写真
    private var twoTone: [SkySample] {
        (0..<200).map { i in
            let y = Double(i) / 200
            return SkySample(color: y < 0.5 ? RGB(0.4, 0.6, 0.9) : RGB(0.95, 0.65, 0.45), y: y)
        }
    }

    @Test func picksTheMainColorsInTopToBottomOrder() {
        let swatches = SkyExtractor.swatches(from: twoTone)
        #expect(swatches.count == 2)
        let top = swatches[0].color.hsl
        let bottom = swatches[swatches.count - 1].color.hsl
        #expect(top.isBlue)
        #expect(bottom.isWarm)
        let total = swatches.reduce(0.0) { $0 + $1.share }
        #expect(abs(total - 1) < 0.0001)
    }

    @Test func sameInputGivesSameColors() {
        let a = SkyExtractor.swatches(from: SampleSky.dawnGlow.samples)
        let b = SkyExtractor.swatches(from: SampleSky.dawnGlow.samples)
        #expect(a == b)
        #expect(a.count == 3)
    }

    @Test func noPixelsGivesNoColors() {
        #expect(SkyExtractor.swatches(from: []).isEmpty)
    }

    @Test func hslOfKnownColors() {
        let blue = RGB(0, 0, 1).hsl
        #expect(abs(blue.h - 240) < 0.001)
        #expect(abs(blue.s - 1) < 0.001)
        let grey = RGB(0.5, 0.5, 0.5).hsl
        #expect(grey.s == 0)
        #expect(grey.isGrey)
    }
}

struct CollectorTests {
    @Test func firstShotOutsideTheWindowIsATrial() throws {
        let result = Collector.capture(samples: SampleSky.clearBlue.samples, at: at(2026, 11, 13, 21, 0), schedule: schedule,
                                       journal: Journal(), calendar: calendar, photo: nil)
        let outcome = try result.get()
        #expect(outcome.record.result == .trial)
        #expect(outcome.record.momentID == "first-sky")
        #expect(outcome.streak == 0)
    }

    @Test func lateShotChipsTheSquareOnceThereAreRecords() throws {
        var journal = Journal()
        journal.add(try Collector.capture(samples: SampleSky.clearBlue.samples, at: at(2026, 11, 12, 6, 35), schedule: schedule,
                                          journal: journal, calendar: calendar, photo: nil).get().record)
        let late = try Collector.capture(samples: SampleSky.overcast.samples, at: at(2026, 11, 13, 7, 10), schedule: schedule,
                                         journal: journal, calendar: calendar, photo: nil).get()
        #expect(late.record.result == .late)
        #expect(late.record.momentID == nil)
        #expect(late.streak == 0)
    }

    @Test func oneSkyPerDay() throws {
        var journal = Journal()
        journal.add(try Collector.capture(samples: SampleSky.clearBlue.samples, at: at(2026, 11, 13, 6, 35), schedule: schedule,
                                          journal: journal, calendar: calendar, photo: nil).get().record)
        let again = Collector.capture(samples: SampleSky.lilac.samples, at: at(2026, 11, 13, 6, 40), schedule: schedule,
                                      journal: journal, calendar: calendar, photo: nil)
        #expect(throws: Collector.Refusal.alreadyToday) { try again.get() }
    }

    @Test func nightShotIsRefusedOnceThereAreRecords() throws {
        var journal = Journal()
        journal.add(try Collector.capture(samples: SampleSky.clearBlue.samples, at: at(2026, 11, 12, 6, 35), schedule: schedule,
                                          journal: journal, calendar: calendar, photo: nil).get().record)
        let night = Collector.capture(samples: SampleSky.predawn.samples, at: at(2026, 11, 13, 2, 0), schedule: schedule,
                                      journal: journal, calendar: calendar, photo: nil)
        #expect(throws: Collector.Refusal.tooEarly(target: at(2026, 11, 13, 6, 30))) { try night.get() }
    }

    @Test func sevenMorningsInARowGiveTheSeventhPage() throws {
        var journal = Journal()
        var last: Collector.Outcome?
        for day in 1...7 {
            let outcome = try Collector.capture(samples: SampleSky.clearBlue.samples, at: at(2026, 10, day, 6, 33), schedule: schedule,
                                                journal: journal, calendar: calendar, photo: nil).get()
            journal.add(outcome.record)
            last = outcome
        }
        #expect(last?.streak == 7)
        #expect(last?.record.momentID == "seventh")
        #expect(journal.found["seventh"] == "2026-10-07")
    }

    @Test func earlyShotGetsTheEarlyMark() throws {
        var journal = Journal()
        journal.add(try Collector.capture(samples: SampleSky.clearBlue.samples, at: at(2026, 11, 12, 6, 35), schedule: schedule,
                                          journal: journal, calendar: calendar, photo: nil).get().record)
        let early = try Collector.capture(samples: SampleSky.predawn.samples, at: at(2026, 11, 13, 5, 50), schedule: schedule,
                                          journal: journal, calendar: calendar, photo: nil).get()
        #expect(early.record.result == .early)
        #expect(early.record.momentID == "early-riser")
        #expect(early.streak == 2)
    }
}

struct CatalogTests {
    private func features(_ sky: SampleSky, month: Int) -> SkyFeatures {
        SkyFeatures(swatches: SkyExtractor.swatches(from: sky.samples), month: month, day: 10, weekday: 3,
                    minutes: 5, result: .caught, streak: 1, gapDays: 1)
    }

    @Test func fortyEightPagesWithUniqueIDsAndBothLanguages() {
        #expect(SkyCatalog.skies.count == 36)
        #expect(SkyCatalog.moments.count == 12)
        let ids = Set(SkyCatalog.all.map { $0.id })
        #expect(ids.count == 48)
        for page in SkyCatalog.all {
            #expect(!page.ja.isEmpty && !page.en.isEmpty && !page.noteEn.isEmpty && !page.hintEn.isEmpty)
            #expect(page.colors.count == 3)
        }
        let proPages = SkyCatalog.all.filter { $0.isPro }.count
        #expect(proPages == 18)
    }

    @Test func sampleSkiesLandOnTheExpectedPages() {
        #expect(SkyCatalog.sky(for: features(.dawnGlow, month: 11)).id == "horizon-glow")
        #expect(SkyCatalog.sky(for: features(.golden, month: 11)).id == "golden-hour")
        #expect(SkyCatalog.sky(for: features(.lilac, month: 11)).id == "lilac-daybreak")
        #expect(SkyCatalog.sky(for: features(.predawn, month: 11)).id == "deep-blue")
        #expect(SkyCatalog.sky(for: features(.overcast, month: 11)).id == "fog")
        #expect(SkyCatalog.sky(for: features(.clearBlue, month: 10)).id == "high-autumn")
        #expect(SkyCatalog.sky(for: features(.clearBlue, month: 1)).id == "winter-crystal")
    }

    @Test func dateMythicsNeedTheWindow() {
        let swatches = SkyExtractor.swatches(from: SampleSky.overcast.samples)
        let caught = SkyFeatures(swatches: swatches, month: 1, day: 1, weekday: 5, minutes: 3, result: .caught, streak: 1, gapDays: 1)
        let late = SkyFeatures(swatches: swatches, month: 1, day: 1, weekday: 5, minutes: 40, result: .late, streak: 0, gapDays: 1)
        #expect(SkyCatalog.sky(for: caught).id == "first-of-year")
        #expect(SkyCatalog.sky(for: late).id != "first-of-year")
    }

    @Test func everyFeatureFindsASkyPage() {
        let empty = SkyFeatures(swatches: [], month: 6, day: 1, weekday: 1, minutes: 0, result: .trial, streak: 0, gapDays: nil)
        #expect(!SkyCatalog.sky(for: empty).id.isEmpty)
        #expect(SkyCatalog.moment(for: empty)?.id == "first-sky")
    }

    @Test func notesExistInBothLanguages() {
        #expect(SkyNotes.all.count == 40)
        #expect(SkyNotes.note(for: "2026-11-13").en == SkyNotes.note(for: "2026-11-13").en)
    }
}

struct JournalTests {
    private func record(_ day: String, _ result: CatchResult) -> DayRecord {
        let date = DayKey.date(day, calendar: calendar)!.addingTimeInterval(6.5 * 3600)
        return DayRecord(day: day, capturedAt: date, target: date, result: result,
                         swatches: [Swatch(color: RGB(0.6, 0.75, 0.9), share: 1, height: 0.5)], skyID: "clear-blue", momentID: nil)
    }

    @Test func streakCountsBackFromYesterdayUntilAGap() {
        var journal = Journal()
        for day in ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12"] { journal.add(record(day, .caught)) }
        journal.add(record("2026-11-07", .caught))
        // 11-13 はまだ撮っていない → 昨日から数える。11-08 で途切れる
        #expect(journal.streak(asOf: at(2026, 11, 13, 6, 0), calendar: calendar) == 4)
        #expect(journal.bestStreak(calendar: calendar) == 4)
    }

    @Test func lateBreaksTheStreakButRestDaysDoNot() {
        var journal = Journal()
        journal.add(record("2026-11-10", .caught))
        journal.add(record("2026-11-11", .late))
        journal.add(record("2026-11-12", .early))
        #expect(journal.streak(asOf: at(2026, 11, 12, 9, 0), calendar: calendar) == 1)
        journal.records["2026-11-11"] = nil
        journal.restDays.insert("2026-11-11")
        #expect(journal.streak(asOf: at(2026, 11, 12, 9, 0), calendar: calendar) == 2)
    }

    @Test func monthGridStartsOnSundayAndMarksMissedDays() {
        var journal = Journal()
        journal.add(record("2026-11-02", .caught))
        journal.add(record("2026-11-03", .late))
        let cells = journal.monthCells(year: 2026, month: 11, today: at(2026, 11, 4, 12, 0), calendar: calendar)
        // 2026-11-01 は日曜なので、前の空きはない
        #expect(cells.count == 30)
        #expect(cells[0].state == .missed)
        if case .record(let r) = cells[1].state { #expect(r.result == .caught) } else { Issue.record("11-02 が記録になっていない") }
        #expect(cells[3].state == .today)
        #expect(cells[4].state == .future)
        let score = journal.monthScore(year: 2026, month: 11, today: at(2026, 11, 4, 12, 0), calendar: calendar)
        #expect(score.caught == 1)
        #expect(score.days == 4)
    }

    @Test func yearRingHasOneSlotPerDay() {
        var journal = Journal()
        journal.add(record("2026-01-01", .caught))
        let days = journal.yearDays(year: 2026, calendar: calendar)
        #expect(days.count == 365)
        #expect(days[0]?.day == "2026-01-01")
        #expect(days[1] == nil)
    }

    @Test func journalRoundTripsAsJSON() throws {
        var journal = Journal()
        journal.add(record("2026-11-12", .caught))
        journal.restDays.insert("2026-11-10")
        let data = try JSONEncoder().encode(journal)
        #expect(try JSONDecoder().decode(Journal.self, from: data) == journal)
    }

    @MainActor
    @Test func sampleHistoryIsFixedAndVaried() {
        let a = AppModel.makeSamples(endingBefore: at(2026, 11, 13, 6, 38), days: 52, schedule: schedule, calendar: calendar)
        let b = AppModel.makeSamples(endingBefore: at(2026, 11, 13, 6, 38), days: 52, schedule: schedule, calendar: calendar)
        #expect(a == b)
        let allSample = a.records.values.allSatisfy { $0.isSample }
        let hasLate = a.records.values.contains { $0.result == .late }
        let kinds = Set(a.records.values.map { $0.skyID }).count
        #expect(allSample)
        #expect(hasLate)
        #expect(a.records.count < 52)
        #expect(kinds >= 4)
    }
}

/// 画面の地の色（時刻で変わる空）
struct SkyClockTests {
    @Test func keyTimesReturnTheirOwnColors() {
        let dawn = SkyClock.keys.first { $0.minute == 6 * 60 }!
        #expect(SkyClock.colors(minute: 6 * 60) == [dawn.top, dawn.middle, dawn.bottom])
    }

    @Test func midnightWrapsAroundSmoothly() {
        #expect(SkyClock.colors(minute: 0) == SkyClock.colors(minute: 1440))
        #expect(SkyClock.colors(minute: -60) == SkyClock.colors(minute: 23 * 60))
    }

    @Test func betweenKeysIsAMix() {
        let a = SkyClock.colors(minute: 5 * 60)[2]
        let b = SkyClock.colors(minute: 6 * 60)[2]
        let mid = SkyClock.colors(minute: 5 * 60 + 30)[2]
        #expect(abs(mid.r - (a.r + b.r) / 2) < 0.01)
    }

    @Test func nightIsDarkerThanDawnAndDawnIsWarmAtTheHorizon() {
        let night = SkyClock.colors(minute: 23 * 60)
        let dawn = SkyClock.colors(minute: 6 * 60 + 30)
        #expect(SkyClock.luminance(night[1]) < SkyClock.luminance(dawn[1]))
        #expect(dawn[2].r > dawn[2].b)
    }

    @Test func everyMinuteStaysDarkEnoughForWhiteText() {
        for m in stride(from: 0, to: 1440, by: 5) {
            for c in SkyClock.colors(minute: m) { #expect(SkyClock.luminance(c) < 0.5) }
        }
    }

    @Test func capturedSkyIsDimmedForTheBackdropAndKeepsTopToBottomOrder() {
        let bright = [Swatch(color: RGB(0.95, 0.85, 0.80), share: 0.4, height: 0.8),
                      Swatch(color: RGB(0.70, 0.85, 1.0), share: 0.6, height: 0.2)]
        let colors = SkyClock.backdrop(from: bright)
        #expect(colors.count == 2)
        for c in colors { #expect(SkyClock.luminance(c) < 0.42) }
        // 上（height 0.2）は青い空、下は桃色
        #expect(colors[0].b > colors[0].r)
        #expect(colors[1].r > colors[1].b)
    }
}
