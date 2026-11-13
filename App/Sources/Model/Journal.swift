import Foundation

/// 1 つの朝の記録
struct DayRecord: Codable, Identifiable, Equatable, Sendable {
    var id: String { day }
    let day: String
    let capturedAt: Date
    let target: Date
    let result: CatchResult
    /// 上から順の空の色（2〜3 色）
    let swatches: [Swatch]
    /// 図鑑の「空」のページ
    let skyID: String
    /// 図鑑の「朝」のページ（あれば）
    let momentID: String?
    /// アプリの中に保存した小さな写真のファイル名（保存しない設定なら nil）
    var photo: String?
    /// 見本のデータ（撮影・デモ・最初の画面）
    var isSample: Bool = false

    var minutesFromTarget: Int { Int(capturedAt.timeIntervalSince(target) / 60) }
}

/// 月のマス目の 1 マス
struct MonthCell: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable {
        /// 月の前の空き
        case blank
        /// これからの日
        case future
        /// 今日（まだ撮っていない）
        case today
        /// 撮らなかった日（欠けたマス）
        case missed
        /// 休む日（Pro）
        case rest
        case record(DayRecord)
    }

    let id: Int
    let day: Int
    let state: State
}

/// すべての朝の記録と、図鑑で見つけたページ
struct Journal: Codable, Equatable, Sendable {
    var records: [String: DayRecord] = [:]
    /// 休む日（Pro。続けた朝を途切れさせない）
    var restDays: Set<String> = []
    /// 図鑑のページ ID → 最初に見つけた日
    var found: [String: String] = [:]

    var realRecords: [DayRecord] { records.values.filter { !$0.isSample }.sorted { $0.day < $1.day } }
    var hasRealRecords: Bool { records.values.contains { !$0.isSample } }

    func record(on date: Date, calendar: Calendar) -> DayRecord? { records[DayKey.string(date, calendar: calendar)] }

    /// 記録を置き、新しく見つけたページの ID を返す
    @discardableResult
    mutating func add(_ record: DayRecord) -> [String] {
        records[record.day] = record
        var new: [String] = []
        for id in [record.skyID, record.momentID].compactMap({ $0 }) where found[id] == nil {
            found[id] = record.day
            new.append(id)
        }
        return new
    }

    /// 続けた朝（窓の中で撮った日が続いた数）。今日まだ撮っていなければ、昨日から数える。休む日は飛ばす
    func streak(asOf now: Date, calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: now)
        let todayKey = DayKey.string(day, calendar: calendar)
        if records[todayKey]?.result.counts != true && !restDays.contains(todayKey) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        for _ in 0..<3660 {
            let key = DayKey.string(day, calendar: calendar)
            if restDays.contains(key) {
                // 休む日は数えず、途切れさせない
            } else if records[key]?.result.counts == true {
                count += 1
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// いちばん長く続けた朝
    func bestStreak(calendar: Calendar) -> Int {
        let keys = records.values.filter { $0.result.counts }.map(\.day).sorted()
        guard let first = keys.first, var day = DayKey.date(first, calendar: calendar),
              let last = keys.last, let end = DayKey.date(last, calendar: calendar) else { return 0 }
        var best = 0, run = 0
        while day <= end {
            let key = DayKey.string(day, calendar: calendar)
            if restDays.contains(key) {
                // 飛ばす
            } else if records[key]?.result.counts == true {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    /// 前の記録から何日あいたか（最初の記録なら nil）
    func gapDays(before date: Date, calendar: Calendar) -> Int? {
        let key = DayKey.string(date, calendar: calendar)
        guard let previous = records.keys.filter({ $0 < key }).max(),
              let previousDate = DayKey.date(previous, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: previousDate, to: calendar.startOfDay(for: date)).day
    }

    /// 月のマス目（日曜はじまり、前の空きを含む）
    func monthCells(year: Int, month: Int, today: Date, calendar: Calendar) -> [MonthCell] {
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let lead = (calendar.component(.weekday, from: first) - 1 + 7) % 7
        let todayStart = calendar.startOfDay(for: today)
        var cells: [MonthCell] = (0..<lead).map { MonthCell(id: -1 - $0, day: 0, state: .blank) }
        for day in range {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
            let key = DayKey.string(date, calendar: calendar)
            let state: MonthCell.State
            if let record = records[key] {
                state = .record(record)
            } else if restDays.contains(key) {
                state = .rest
            } else if date > todayStart {
                state = .future
            } else if date == todayStart {
                state = .today
            } else {
                state = .missed
            }
            cells.append(MonthCell(id: day, day: day, state: state))
        }
        return cells
    }

    /// その月に窓の中で撮った日の数と、その月の過ぎた日の数
    func monthScore(year: Int, month: Int, today: Date, calendar: Calendar) -> (caught: Int, days: Int) {
        let cells = monthCells(year: year, month: month, today: today, calendar: calendar)
        var caught = 0, days = 0
        for cell in cells {
            switch cell.state {
            case .record(let r):
                days += 1
                if r.result.counts { caught += 1 }
            case .missed, .today:
                days += 1
            default:
                break
            }
        }
        return (caught, days)
    }

    /// 1 年の輪：その年の日ごとの記録（1 月 1 日から）
    func yearDays(year: Int, calendar: Calendar) -> [DayRecord?] {
        guard let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let range = calendar.range(of: .day, in: .year, for: first) else { return [] }
        return range.map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 1, to: first) else { return nil }
            return records[DayKey.string(date, calendar: calendar)]
        }
    }

    /// 起きる時刻からの平均のずれ（分。窓の中・早起きの記録だけ）
    func averageOffset(lastDays: Int, asOf now: Date, calendar: Calendar) -> Double? {
        guard let start = calendar.date(byAdding: .day, value: -lastDays, to: now) else { return nil }
        let key = DayKey.string(start, calendar: calendar)
        let values = records.values.filter { $0.day > key && $0.result.counts }.map { Double($0.minutesFromTarget) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
