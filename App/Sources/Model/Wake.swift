import Foundation

/// 起きる時刻（曜日ごと。0 時からの分）。index は Calendar の weekday - 1（0 = 日曜）
struct WakeSchedule: Codable, Equatable, Sendable {
    var minutes: [Int]

    static let standard = WakeSchedule(minutes: [480, 420, 420, 420, 420, 420, 480])

    init(minutes: [Int]) {
        var fixed = Array(minutes.prefix(7))
        while fixed.count < 7 { fixed.append(420) }
        self.minutes = fixed.map { min(max($0, 0), 24 * 60 - 1) }
    }

    func minutes(forWeekday weekday: Int) -> Int { minutes[(weekday - 1 + 7) % 7] }

    mutating func set(_ value: Int, forWeekday weekday: Int) {
        minutes[(weekday - 1 + 7) % 7] = min(max(value, 0), 24 * 60 - 1)
    }

    mutating func setAll(_ value: Int) {
        minutes = Array(repeating: min(max(value, 0), 24 * 60 - 1), count: 7)
    }

    var isSameEveryDay: Bool { Set(minutes).count == 1 }

    /// その日の起きる時刻
    func target(on day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        let weekday = calendar.component(.weekday, from: day)
        return calendar.date(byAdding: .minute, value: minutes(forWeekday: weekday), to: start) ?? start
    }
}

/// 撮った時刻の扱い
enum CatchResult: String, Codable, Sendable {
    /// 起きる時刻より前（2 時間まで）。早起き
    case early
    /// 起きる時刻から 15 分以内
    case caught
    /// 15 分を過ぎた（寝坊）。マスは欠ける
    case late
    /// 最初の 1 枚を、窓の外で試しに撮った（続けた朝には数えない）
    case trial

    var counts: Bool { self == .early || self == .caught }
}

/// 窓（起きる時刻から 15 分）の判定。画面から切り離してテストする
enum WakeWindow {
    static let windowMinutes = 15
    /// 起きる時刻の何分前から撮れるか（早起き）
    static let earlyMinutes = 120
    /// 起きる時刻の何分後まで撮れるか（寝坊として残す）
    static let lateMinutes = 6 * 60

    enum Judgement: Equatable, Sendable {
        /// 早すぎる（まだ夜）
        case tooEarly
        case early(minutesBefore: Int)
        case caught(minutesAfter: Int)
        case late(minutesAfter: Int)
        /// 今日の朝は過ぎた
        case closed

        var result: CatchResult? {
            switch self {
            case .early: .early
            case .caught: .caught
            case .late: .late
            case .tooEarly, .closed: nil
            }
        }
    }

    static func judge(_ moment: Date, target: Date) -> Judgement {
        let seconds = moment.timeIntervalSince(target)
        if seconds < -Double(earlyMinutes * 60) { return .tooEarly }
        if seconds < 0 { return .early(minutesBefore: Int((-seconds / 60).rounded(.up))) }
        if seconds <= Double(windowMinutes * 60) { return .caught(minutesAfter: Int(seconds / 60)) }
        if seconds <= Double(lateMinutes * 60) { return .late(minutesAfter: Int(seconds / 60)) }
        return .closed
    }

    /// ホームの文言を決める今の段階
    enum Phase: Equatable, Sendable {
        /// 夜（次の朝を待つ）。tomorrow は次の起きる時刻
        case night(next: Date)
        /// 起きる時刻の前（早起きで撮れる）
        case before(target: Date)
        /// 窓が開いている。残り秒
        case open(target: Date, secondsLeft: Int)
        /// 窓を過ぎた（寝坊として撮れる）
        case late(target: Date)
        /// 今日はもう撮った
        case done(result: CatchResult)
    }

    static func phase(now: Date, schedule: WakeSchedule, capturedToday: CatchResult?, calendar: Calendar) -> Phase {
        if let capturedToday { return .done(result: capturedToday) }
        let target = schedule.target(on: now, calendar: calendar)
        switch judge(now, target: target) {
        case .tooEarly:
            return .night(next: target)
        case .early:
            return .before(target: target)
        case .caught:
            let left = Int(target.addingTimeInterval(Double(windowMinutes * 60)).timeIntervalSince(now))
            return .open(target: target, secondsLeft: max(0, left))
        case .late:
            return .late(target: target)
        case .closed:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return .night(next: schedule.target(on: tomorrow, calendar: calendar))
        }
    }
}

/// 日付の鍵（"2026-11-13"）。端末の暦で決める
enum DayKey {
    static func string(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
