import Observation
import SwiftUI
import UIKit

enum PaywallReason: Hashable, Sendable {
    case firstMornings, rarePage, poster, rest, stats, settings
}

enum ActiveSheet: Identifiable, Hashable {
    case settings, paywall(PaywallReason), share, page(String)

    var id: String {
        switch self {
        case .settings: "settings"
        case .paywall: "paywall"
        case .share: "share"
        case .page(let id): "page-" + id
        }
    }
}

/// 画面全体をおおう場面（撮る・図鑑）
enum Cover: String, Identifiable, Hashable {
    case capture, atlas
    var id: String { rawValue }
}

/// 撮ったあとの発表
struct Reveal: Equatable {
    let record: DayRecord
    let judgement: WakeWindow.Judgement
    let newPages: [String]
    let streak: Int
    /// 見本の空で試した（記録に入れない）
    let isTryOut: Bool
}

enum CaptureStage: Equatable {
    case choosing
    case reveal(Reveal)
}

@MainActor
@Observable
final class AppModel {
    var journal: Journal { didSet { saveJournal() } }
    var schedule: WakeSchedule { didSet { saveSettings() } }
    var onboarded: Bool { didSet { saveSettings() } }
    var keepPhotos: Bool { didSet { saveSettings() } }
    var hapticsOn: Bool { didSet { saveSettings() } }
    var reminderOn: Bool { didSet { saveSettings() } }
    /// 今の時刻。撮影・デモでは止める
    var now: Date
    var frozen: Bool
    var cover: Cover?
    var activeSheet: ActiveSheet?
    var captureStage: CaptureStage = .choosing
    var revealImage: UIImage?
    var refusal: Collector.Refusal?
    var monthOffset = 0
    var proOverride = false
    /// 撮影で、カメラの許可がない状態を見せる
    var cameraDeniedOverride = false
    var lastPaywallDay: String?

    // 手応え（振動）のきっかけ
    var pressTick = 0
    var catchTick = 0
    var lateTick = 0
    var newPageTick = 0
    var placeTick = 0

    let purchases: PurchaseStore
    let persists: Bool
    let calendar: Calendar
    private let defaults: UserDefaults
    /// 記録がまだないときにホームに出す見本のパレット
    private(set) var sampleJournal = Journal()

    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.008"
    static let proID = ProductID.pro(bundleID: bundleID)

    init(persists: Bool = true, now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        self.persists = persists
        self.now = now
        self.frozen = !persists
        self.calendar = calendar
        self.defaults = defaults
        purchases = PurchaseStore(productIDs: [Self.proID], proProductIDs: [Self.proID])
        if persists, let data = try? Data(contentsOf: Self.journalURL), let saved = try? JSONDecoder().decode(Journal.self, from: data) {
            journal = saved
        } else {
            journal = Journal()
        }
        if persists, let data = defaults.data(forKey: "schedule"), let saved = try? JSONDecoder().decode(WakeSchedule.self, from: data) {
            schedule = saved
        } else {
            schedule = .standard
        }
        onboarded = persists ? defaults.bool(forKey: "onboarded") : true
        keepPhotos = persists && defaults.object(forKey: "keepPhotos") != nil ? defaults.bool(forKey: "keepPhotos") : true
        hapticsOn = persists && defaults.object(forKey: "haptics") != nil ? defaults.bool(forKey: "haptics") : true
        reminderOn = persists ? defaults.bool(forKey: "reminder") : false
        lastPaywallDay = persists ? defaults.string(forKey: "lastPaywallDay") : nil
        sampleJournal = Self.makeSamples(endingBefore: now, days: 24, schedule: schedule, calendar: calendar)
    }

    // MARK: - 保存（端末の中だけ）

    static var journalURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("journal.json")
    }

    private func saveJournal() {
        guard persists, let data = try? JSONEncoder().encode(journal) else { return }
        try? FileManager.default.createDirectory(at: Self.journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.journalURL, options: [.atomic, .completeFileProtection])
    }

    private func saveSettings() {
        guard persists else { return }
        if let data = try? JSONEncoder().encode(schedule) { defaults.set(data, forKey: "schedule") }
        defaults.set(onboarded, forKey: "onboarded")
        defaults.set(keepPhotos, forKey: "keepPhotos")
        defaults.set(hapticsOn, forKey: "haptics")
        defaults.set(reminderOn, forKey: "reminder")
        defaults.set(lastPaywallDay, forKey: "lastPaywallDay")
    }

    // MARK: - 状態

    var isPro: Bool { proOverride || purchases.entitlements.isPro }
    var todayKey: String { DayKey.string(now, calendar: calendar) }
    var todayRecord: DayRecord? { journal.records[todayKey] }
    /// 記録がまだなければ見本のパレットを見せる
    var showsSample: Bool { !journal.hasRealRecords && !journal.records.values.contains { $0.isSample } }
    var paletteJournal: Journal { showsSample ? sampleJournal : journal }

    var phase: WakeWindow.Phase {
        WakeWindow.phase(now: now, schedule: schedule, capturedToday: todayRecord?.result, calendar: calendar)
    }

    func phase(at date: Date) -> WakeWindow.Phase {
        let key = DayKey.string(date, calendar: calendar)
        return WakeWindow.phase(now: date, schedule: schedule, capturedToday: journal.records[key]?.result, calendar: calendar)
    }

    var streak: Int { journal.streak(asOf: now, calendar: calendar) }
    var bestStreak: Int { journal.bestStreak(calendar: calendar) }
    var foundCount: Int { journal.found.count }
    var totalPages: Int { SkyCatalog.all.count }

    /// 表示する月（monthOffset だけずらす）
    var shownMonth: (year: Int, month: Int) {
        let date = calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
        let c = calendar.dateComponents([.year, .month], from: date)
        return (c.year ?? 2026, c.month ?? 1)
    }

    var monthCells: [MonthCell] {
        let m = shownMonth
        return paletteJournal.monthCells(year: m.year, month: m.month, today: now, calendar: calendar)
    }

    var year: Int { calendar.component(.year, from: now) }

    func isUnlocked(_ page: SkyPage) -> Bool { !page.isPro || isPro }

    /// 画面の地の色：今日撮った朝はその空の色、ほかは時刻の空（夜 → 夜明け → 朝 → 昼 → 夕暮れ）
    var backdropColors: [RGB] {
        if let today = todayRecord, !today.isSample, !today.swatches.isEmpty {
            return SkyClock.backdrop(from: today.swatches)
        }
        return SkyClock.colors(at: now, calendar: calendar)
    }

    /// 地平のにじみの強さ：夜は弱く、夜明けと夕方に強く
    var backdropGlow: Double {
        let h = calendar.component(.hour, from: now)
        switch h {
        case 5...7, 16...18: return 0.45
        case 8...15: return 0.18
        default: return 0.08
        }
    }

    // MARK: - 撮る

    /// 「空を撮る」を押した
    func startCapture() {
        pressTick += 1
        if let today = todayRecord, !today.isSample {
            refusal = .alreadyToday
            return
        }
        if journal.hasRealRecords {
            switch WakeWindow.judge(now, target: schedule.target(on: now, calendar: calendar)) {
            case .tooEarly:
                refusal = .tooEarly(target: schedule.target(on: now, calendar: calendar))
                return
            case .closed:
                refusal = .closed
                return
            default:
                break
            }
        }
        captureStage = .choosing
        revealImage = nil
        cover = .capture
    }

    /// カメラで撮った写真
    func capture(photo image: UIImage) {
        if !frozen { now = Date() }
        let samples = PixelReader.samples(from: image)
        let name = keepPhotos && persists ? PhotoStore.save(image, day: todayKey) : nil
        apply(samples: samples, image: image, photo: name, tryOut: false)
    }

    /// 見本の空で試す（カメラが使えない端末。撮影・デモでは記録に入れる）
    func capture(sample sky: SampleSky) {
        apply(samples: sky.samples, image: PixelReader.image(of: sky), photo: nil, tryOut: persists)
    }

    private func apply(samples: [SkySample], image: UIImage?, photo: String?, tryOut: Bool) {
        let source = tryOut ? Journal() : journal
        switch Collector.capture(samples: samples, at: now, schedule: schedule, journal: source, calendar: calendar,
                                 photo: photo, isSample: false) {
        case .failure(let reason):
            refusal = reason
            cover = nil
        case .success(let outcome):
            var newPages: [String] = []
            if tryOut {
                var copy = source
                newPages = copy.add(outcome.record)
            } else {
                newPages = journal.add(outcome.record)
            }
            revealImage = image
            captureStage = .reveal(Reveal(record: outcome.record, judgement: outcome.judgement, newPages: newPages,
                                          streak: outcome.streak, isTryOut: tryOut))
            if outcome.record.result == .late { lateTick += 1 } else { catchTick += 1 }
            if !newPages.isEmpty { newPageTick += 1 }
        }
    }

    /// 発表を閉じて、パレットへ戻る
    func place() {
        placeTick += 1
        cover = nil
        monthOffset = 0
        // 課金の画面は、3 回目の朝を置いた直後に 1 回だけ（同じ日に 2 度出さない）
        let real = journal.realRecords.count
        if persists && !isPro && real == 3 && lastPaywallDay == nil {
            lastPaywallDay = todayKey
            saveSettings()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                self.activeSheet = .paywall(.firstMornings)
            }
        }
    }

    // MARK: - 設定

    func setWake(minutes: Int, weekday: Int?) {
        if let weekday { schedule.set(minutes, forWeekday: weekday) } else { schedule.setAll(minutes) }
        if reminderOn {
            let s = schedule
            Task { _ = await Reminder.enable(schedule: s, japanese: Lang.isJapanese) }
        }
    }

    func setReminder(_ on: Bool) async {
        if on {
            reminderOn = await Reminder.enable(schedule: schedule, japanese: Lang.isJapanese)
        } else {
            Reminder.disable()
            reminderOn = false
        }
    }

    /// 今日を休む日にする（Pro）
    func toggleRest(on date: Date) {
        guard isPro else {
            activeSheet = .paywall(.rest)
            return
        }
        let key = DayKey.string(date, calendar: calendar)
        if journal.restDays.contains(key) { journal.restDays.remove(key) } else { journal.restDays.insert(key) }
    }

    var restDaysThisMonth: Int {
        let m = calendar.dateComponents([.year, .month], from: now)
        let prefix = String(format: "%04d-%02d-", m.year ?? 0, m.month ?? 0)
        return journal.restDays.filter { $0.hasPrefix(prefix) }.count
    }

    func deletePhotos() {
        PhotoStore.deleteAll()
        for (key, record) in journal.records where record.photo != nil {
            var copy = record
            copy.photo = nil
            journal.records[key] = copy
        }
    }

    // MARK: - 見本のデータ

    /// 見本の記録（決まった並び。撮影・デモ・記録がないときのホーム）
    static func makeSamples(endingBefore end: Date, days: Int, schedule: WakeSchedule, calendar: Calendar) -> Journal {
        var journal = Journal()
        let skies = SampleSky.allCases
        var seed: UInt32 = 20_261_113
        func next() -> Int {
            seed = seed &* 1_103_515_245 &+ 12_345
            return Int((seed >> 16) & 0x7FFF)
        }
        for back in stride(from: days, through: 1, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -back, to: end) else { continue }
            let roll = next() % 100
            if roll < 12 { _ = next(); continue }  // 撮らなかった日
            let minutes: Int
            if roll < 24 { minutes = 20 + next() % 70 } else if roll < 40 { minutes = -(5 + next() % 50) } else { minutes = next() % 15 }
            let target = schedule.target(on: day, calendar: calendar)
            let moment = target.addingTimeInterval(Double(minutes * 60 + 20))
            let sky = skies[next() % skies.count]
            let shift = Double(next() % 9 - 4) * 0.018
            let samples = sky.samples.map { SkySample(color: RGB($0.color.r + shift, $0.color.g + shift * 0.5, $0.color.b - shift), y: $0.y) }
            if case .success(let outcome) = Collector.capture(samples: samples, at: moment, schedule: schedule, journal: journal,
                                                               calendar: calendar, photo: nil, isSample: true) {
                journal.add(outcome.record)
            }
        }
        return journal
    }
}
