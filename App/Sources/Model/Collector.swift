import Foundation

/// 空を撮ったときに、記録・図鑑のページ・判定を決める（画面から切り離してテストする）
enum Collector {
    struct Outcome: Sendable {
        let record: DayRecord
        let judgement: WakeWindow.Judgement
        /// この朝を入れた続けた朝
        let streak: Int
    }

    enum Refusal: Error, Equatable, Sendable {
        /// 今日はもう撮った
        case alreadyToday
        /// まだ夜（窓の 2 時間より前）
        case tooEarly(target: Date)
        /// 今日の朝は過ぎた
        case closed
        /// 色が取れなかった
        case noColor
    }

    static func capture(samples: [SkySample], at moment: Date, schedule: WakeSchedule, journal: Journal,
                        calendar: Calendar, photo: String?, isSample: Bool = false) -> Result<Outcome, Refusal> {
        let dayKey = DayKey.string(moment, calendar: calendar)
        if let existing = journal.records[dayKey], !existing.isSample { return .failure(.alreadyToday) }
        let target = schedule.target(on: moment, calendar: calendar)
        let judgement = WakeWindow.judge(moment, target: target)
        let first = journal.records.isEmpty
        let result: CatchResult
        switch judgement.result {
        case .early?: result = .early
        case .caught?: result = .caught
        case .late?: result = first ? .trial : .late
        case .trial?: result = .trial
        case nil:
            guard first else {
                if case .tooEarly = judgement { return .failure(.tooEarly(target: target)) }
                return .failure(.closed)
            }
            result = .trial
        }
        let swatches = SkyExtractor.swatches(from: samples)
        guard !swatches.isEmpty else { return .failure(.noColor) }

        var after = journal
        let minutes = Int((moment.timeIntervalSince(target) / 60).rounded(.down))
        let provisional = DayRecord(day: dayKey, capturedAt: moment, target: target, result: result, swatches: swatches,
                                    skyID: "", momentID: nil, photo: photo, isSample: isSample)
        after.records[dayKey] = provisional
        let streak = result.counts ? after.streak(asOf: moment, calendar: calendar) : 0
        let c = calendar.dateComponents([.month, .day, .weekday], from: moment)
        let gap = first ? nil : (journal.gapDays(before: moment, calendar: calendar) ?? 1)
        let features = SkyFeatures(swatches: swatches, month: c.month ?? 1, day: c.day ?? 1, weekday: c.weekday ?? 1,
                                   minutes: minutes, result: result, streak: streak, gapDays: gap)
        let sky = SkyCatalog.sky(for: features)
        let moment2 = SkyCatalog.moment(for: features)
        let record = DayRecord(day: dayKey, capturedAt: moment, target: target, result: result, swatches: swatches,
                               skyID: sky.id, momentID: moment2?.id, photo: photo, isSample: isSample)
        return .success(Outcome(record: record, judgement: judgement, streak: streak))
    }
}

/// 見本の空（CI・撮影・デモ・カメラがない端末の「見本で試す」）。上から下への色の並び
enum SampleSky: String, CaseIterable, Identifiable, Sendable {
    case dawnGlow, clearBlue, lilac, overcast, predawn, golden

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dawnGlow: tr("朝焼け", "Dawn glow")
        case .clearBlue: tr("晴れ", "Clear")
        case .lilac: tr("藤色", "Lilac")
        case .overcast: tr("曇り", "Overcast")
        case .predawn: tr("夜明け前", "Predawn")
        case .golden: tr("金色", "Golden")
        }
    }

    /// 上から下への色（写真の上 3/4 を空とみなす）
    var stops: [RGB] {
        switch self {
        case .dawnGlow: [RGB(0.55, 0.69, 0.86), RGB(0.80, 0.80, 0.88), RGB(0.95, 0.70, 0.58), RGB(0.97, 0.80, 0.62)]
        case .clearBlue: [RGB(0.46, 0.66, 0.88), RGB(0.60, 0.76, 0.92), RGB(0.80, 0.88, 0.95)]
        case .lilac: [RGB(0.62, 0.60, 0.80), RGB(0.76, 0.72, 0.88), RGB(0.93, 0.84, 0.86)]
        case .overcast: [RGB(0.70, 0.72, 0.75), RGB(0.78, 0.79, 0.81), RGB(0.84, 0.85, 0.86)]
        case .predawn: [RGB(0.12, 0.17, 0.32), RGB(0.20, 0.27, 0.45), RGB(0.38, 0.42, 0.58)]
        case .golden: [RGB(0.80, 0.84, 0.88), RGB(0.96, 0.84, 0.60), RGB(0.98, 0.90, 0.72)]
        }
    }

    /// 色を、上からの位置 y（0〜1）で取る
    func color(at y: Double) -> RGB {
        let stops = self.stops
        let position = min(max(y, 0), 1) * Double(stops.count - 1)
        let i = min(Int(position), stops.count - 2)
        return stops[i].mixed(with: stops[i + 1], position - Double(i))
    }

    /// 写真の画素の代わり（24×32。わずかな揺らぎは決まった値）
    var samples: [SkySample] {
        var out: [SkySample] = []
        let rows = 32, cols = 24
        for row in 0..<rows {
            let y = (Double(row) + 0.5) / Double(rows)
            for col in 0..<cols {
                let wobble = Double((row * 7 + col * 13) % 9 - 4) * 0.004
                let base = color(at: y)
                out.append(SkySample(color: RGB(base.r + wobble, base.g + wobble, base.b + wobble), y: y))
            }
        }
        return out
    }
}
