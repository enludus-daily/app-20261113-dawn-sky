import SwiftUI

/// ホーム：上に今朝の窓（地平線と日の出の弧）と「空を撮る」、下に今月のパレットと 1 年の輪。
/// Duo の内側など広い画面（regular）では、左に窓と今月のパレット、右に図鑑と 1 年の輪
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            Tone.ground.ignoresSafeArea()
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        VStack(spacing: 22) {
                            header
                            WindowSection()
                            StatsRow()
                            MonthSection()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .frame(maxWidth: Space.readable)
                        .frame(maxWidth: .infinity)
                    }
                    Rectangle().fill(Tone.hair).frame(width: 1).ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 22) {
                            AtlasPreview()
                            YearSection()
                            PrivacyFooter()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                        .frame(maxWidth: Space.readable)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        WindowSection()
                        StatsRow()
                        MonthSection()
                        YearSection()
                        PrivacyFooter()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: Space.readable)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .alert(refusalTitle, isPresented: Binding(get: { model.refusal != nil }, set: { if !$0 { model.refusal = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: refusalMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: model.now.formatted(Date.FormatStyle().month(.wide).day().weekday(.wide).locale(Lang.locale)))
                    .font(Typo.label)
                    .kerning(0.8)
                    .foregroundStyle(Tone.mute)
                Text("あさやけ図鑑")
                    .font(Typo.serif(26))
                    .kerning(-0.6)
                    .foregroundStyle(Tone.ink)
            }
            Spacer(minLength: 8)
            Button {
                model.pressTick += 1
                model.cover = .atlas
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 13))
                    Text(verbatim: "\(model.foundCount)/\(model.totalPages)")
                        .font(Typo.serif(14))
                        .monospacedDigit()
                }
                .foregroundStyle(Tone.dawnDeep)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(Capsule().stroke(Tone.dawnLine, lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(PressStyle())
            .frame(minHeight: 44)
            .accessibilityLabel(Text("図鑑"))
            .accessibilityIdentifier("main.atlas")
            Button {
                model.pressTick += 1
                model.activeSheet = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Tone.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(Text("設定"))
            .accessibilityIdentifier("main.settings")
        }
        .padding(.top, 8)
    }

    private var refusalTitle: LocalizedStringKey {
        switch model.refusal {
        case .alreadyToday: "今日の空は、もう図鑑に入っています"
        case .tooEarly: "まだ夜です"
        case .closed: "今日の朝は過ぎました"
        case .noColor: "色が読めませんでした"
        case nil: ""
        }
    }

    private var refusalMessage: String {
        switch model.refusal {
        case .alreadyToday: tr("1 日 1 枚です。明日の朝、また新しい色を。", "One sky per day. Come back tomorrow morning for a new color.")
        case .tooEarly(let target): tr("窓は \(target.addingTimeInterval(-Double(WakeWindow.earlyMinutes * 60)).clock) から開きます。起きる時刻は \(target.clock) です。",
                                       "You can shoot from \(target.addingTimeInterval(-Double(WakeWindow.earlyMinutes * 60)).clock). Your wake time is \(target.clock).")
        case .closed: tr("明日の朝、起きて 15 分以内に撮ると、マスが埋まります。", "Tomorrow, shoot within 15 minutes of waking to fill the square.")
        case .noColor: tr("もう一度、空を大きく入れて撮ってください。", "Try again with more sky in the frame.")
        case nil: ""
        }
    }
}

/// 今朝の窓と「空を撮る」
struct WindowSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = model.frozen ? model.now : context.date
            let phase = model.phase(at: date)
            let target = model.schedule.target(on: date, calendar: model.calendar)
            VStack(spacing: 6) {
                ZStack(alignment: .bottom) {
                    WindowDial(now: date, target: target, phase: phase)
                        .frame(height: 132)
                    HStack {
                        Text(verbatim: target.addingTimeInterval(-3600).clock)
                        Spacer()
                        Text(verbatim: target.clock)
                            .foregroundStyle(Tone.glowDeep)
                        Text(verbatim: "–")
                        Text(verbatim: target.addingTimeInterval(Double(WakeWindow.windowMinutes * 60)).clock)
                            .foregroundStyle(Tone.glowDeep)
                    }
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Tone.mute)
                    .offset(y: 16)
                }
                .padding(.bottom, 16)
                status(phase: phase, date: date)
                    .frame(maxWidth: .infinity)
                if case .done = phase {
                    EmptyView()
                } else {
                    SunButton()
                }
            }
        }
    }

    @ViewBuilder
    private func status(phase: WakeWindow.Phase, date: Date) -> some View {
        VStack(spacing: 4) {
            switch phase {
            case .night(let next):
                Text(verbatim: next.clock)
                    .font(Typo.serif(44, .light))
                    .kerning(-2)
                    .monospacedDigit()
                    .foregroundStyle(Tone.ink)
                Text(verbatim: tr("明日の朝 \(next.clock)〜\(next.addingTimeInterval(900).clock) に、空を撮ろう",
                                  "Tomorrow, catch the sky between \(next.clock) and \(next.addingTimeInterval(900).clock)"))
                    .font(Typo.body)
                    .foregroundStyle(Tone.mute)
                if model.showsSample {
                    Text("最初の 1 枚は、今すぐ試し撮りできます")
                        .font(Typo.small)
                        .foregroundStyle(Tone.glowDeep)
                }
            case .before(let target):
                let minutes = Int(ceil(target.timeIntervalSince(date) / 60))
                Text(verbatim: date.clock)
                    .font(Typo.serif(44, .light))
                    .kerning(-2)
                    .monospacedDigit()
                    .foregroundStyle(Tone.ink)
                Text(verbatim: tr("起きる時刻まであと \(minutes) 分。今撮ると早起きの印がつきます",
                                  "\(minutes) min before wake time. Shoot now for an early-bird mark"))
                    .font(Typo.body)
                    .foregroundStyle(Tone.mute)
            case .open(_, let left):
                Text(verbatim: String(format: "%d:%02d", left / 60, left % 60))
                    .font(Typo.serif(48, .light))
                    .kerning(-2)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(Tone.ink)
                Text("窓が開いています。カーテンを開けて、空を")
                    .font(Typo.body)
                    .foregroundStyle(Tone.mute)
            case .late(let target):
                Text("寝坊の朝")
                    .font(Typo.serif(34, .light))
                    .foregroundStyle(Tone.ink)
                Text(verbatim: tr("窓は \(target.addingTimeInterval(900).clock) に閉じました。撮ると、マスは欠けて残ります",
                                  "Your window closed at \(target.addingTimeInterval(900).clock). You can still shoot — the square stays chipped"))
                    .font(Typo.body)
                    .foregroundStyle(Tone.mute)
            case .done:
                TodayCard()
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 「空を撮る」：太陽の形のシャッター
struct SunButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.startCapture()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Tone.glowSoft).frame(width: 84, height: 84)
                    Circle().fill(Tone.glow).frame(width: 68, height: 68)
                    Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 58, height: 58)
                    Image(systemName: "camera")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Tone.ink.opacity(0.8))
                }
                Text("空を撮る")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Tone.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityIdentifier("main.capture")
        .padding(.top, 6)
    }
}

/// 今日撮った空
struct TodayCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let record = model.todayRecord, let page = SkyCatalog.page(record.skyID) {
            Button {
                model.activeSheet = .page(page.id)
            } label: {
                HStack(spacing: 14) {
                    SkyTile(state: .record(record))
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow("今朝の空")
                        Text(verbatim: page.name)
                            .font(Typo.serif(20))
                            .foregroundStyle(Tone.ink)
                        Text(verbatim: resultLine(record))
                            .font(Typo.small)
                            .foregroundStyle(Tone.mute)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Tone.mute)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).fill(Tone.sheet))
                .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Tone.hair, lineWidth: 1))
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .multilineTextAlignment(.leading)
        }
    }

    private func resultLine(_ r: DayRecord) -> String {
        switch r.result {
        case .early: tr("\(r.capturedAt.clock) ・ 早起き", "\(r.capturedAt.clock) · early")
        case .caught: tr("\(r.capturedAt.clock) ・ 窓の中", "\(r.capturedAt.clock) · in the window")
        case .late: tr("\(r.capturedAt.clock) ・ 寝坊（マスは欠け）", "\(r.capturedAt.clock) · late (chipped)")
        case .trial: tr("\(r.capturedAt.clock) ・ 試しの空", "\(r.capturedAt.clock) · trial sky")
        }
    }
}

/// 続けた朝・最長・図鑑
struct StatsRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let journal = model.paletteJournal
        let streak = journal.streak(asOf: model.now, calendar: model.calendar)
        let best = journal.bestStreak(calendar: model.calendar)
        let found = model.showsSample ? journal.found.count : model.foundCount
        HStack(spacing: 0) {
            stat("続けた朝", "\(streak)")
            Rectangle().fill(Tone.hair).frame(width: 1, height: 36)
            stat("いちばん長く", "\(best)")
            Rectangle().fill(Tone.hair).frame(width: 1, height: 36)
            stat("図鑑", "\(found)", suffix: "/\(model.totalPages)")
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Tone.hair).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Tone.hair).frame(height: 1) }
    }

    private func stat(_ title: LocalizedStringKey, _ value: String, suffix: String = "") -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: value)
                    .font(Typo.serif(28))
                    .kerning(-1)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Tone.ink)
                if !suffix.isEmpty {
                    Text(verbatim: suffix)
                        .font(Typo.serif(13))
                        .foregroundStyle(Tone.mute)
                }
            }
            Text(title)
                .font(Typo.caption)
                .kerning(0.6)
                .foregroundStyle(Tone.mute)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 今月のパレット
struct MonthSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let m = model.shownMonth
        let score = model.paletteJournal.monthScore(year: m.year, month: m.month, today: model.now, calendar: model.calendar)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: monthTitle(m.year, m.month))
                    .font(Typo.serif(21))
                    .kerning(-0.4)
                    .foregroundStyle(Tone.ink)
                if model.showsSample {
                    Text("見本")
                        .font(Typo.label)
                        .kerning(0.6)
                        .foregroundStyle(Tone.glowDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Tone.glowSoft))
                }
                Spacer()
                Button { model.monthOffset -= 1 } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .accessibilityLabel(Text("前の月"))
                Button { model.monthOffset = min(0, model.monthOffset + 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .disabled(model.monthOffset >= 0)
                .accessibilityLabel(Text("次の月"))
            }
            .font(.system(size: 13))
            .foregroundStyle(Tone.dawnDeep)
            Text(verbatim: tr("窓の中で撮った朝 \(score.caught) / \(score.days)", "Caught in the window: \(score.caught) of \(score.days)"))
                .font(Typo.small)
                .foregroundStyle(Tone.mute)
            PaletteGrid(cells: model.monthCells) { record in
                model.activeSheet = .page(record.skyID)
            }
            Legend()
            if model.showsSample {
                Text("これは見本です。明日の朝、起きて 15 分以内に空を撮ると、ここに今朝の色が入ります。")
                    .font(Typo.small)
                    .foregroundStyle(Tone.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HairButton(title: "今月の空のパレットを共有", systemImage: "square.and.arrow.up") {
                model.activeSheet = .share
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.monthOffset)
    }

    private func monthTitle(_ year: Int, _ month: Int) -> String {
        let date = model.calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? model.now
        let name = date.formatted(Date.FormatStyle().month(.wide).locale(Lang.locale))
        let sameYear = year == model.year
        if Lang.isJapanese { return sameYear ? "\(name)のパレット" : "\(year)年\(name)のパレット" }
        return sameYear ? "\(name) palette" : "\(name) \(year) palette"
    }
}

/// マスの見方
struct Legend: View {
    var body: some View {
        HStack(spacing: 12) {
            item(.caught, "窓の中")
            item(.early, "早起き")
            item(.late, "寝坊")
            HStack(spacing: 4) {
                SkyTile(state: .missed).frame(width: 12, height: 12)
                Text("撮らなかった")
            }
        }
        .font(Typo.caption)
        .foregroundStyle(Tone.mute)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func item(_ result: CatchResult, _ title: LocalizedStringKey) -> some View {
        let record = DayRecord(day: "legend", capturedAt: Date(), target: Date(), result: result,
                               swatches: [Swatch(color: RGB(0.62, 0.76, 0.90), share: 0.5, height: 0.3),
                                          Swatch(color: RGB(0.95, 0.80, 0.72), share: 0.5, height: 0.7)],
                               skyID: "", momentID: nil)
        return HStack(spacing: 4) {
            SkyTile(state: .record(record)).frame(width: 12, height: 12)
            Text(title)
        }
    }
}

/// 1 年の輪
struct YearSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let journal = model.paletteJournal
        let days = journal.yearDays(year: model.year, calendar: model.calendar)
        let count = days.compactMap { $0 }.count
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("1 年の輪")
            ZStack {
                YearRing(days: days)
                    .frame(maxWidth: 240)
                VStack(spacing: 0) {
                    Text(verbatim: "\(model.year)")
                        .font(Typo.serif(30, .light))
                        .kerning(-1)
                        .foregroundStyle(Tone.ink)
                    Text(verbatim: tr("\(count) 朝", "\(count) mornings"))
                        .font(Typo.small)
                        .foregroundStyle(Tone.mute)
                }
            }
            .frame(maxWidth: .infinity)
            if model.isPro {
                ProStats()
            } else {
                Button {
                    model.activeSheet = .paywall(.stats)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock").font(.system(size: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("くわしい振り返りと、1 年のポスター")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Tone.ink)
                            Text("平均の起きた時刻・曜日ごとの強さ・季節の色（Pro）")
                                .font(Typo.small)
                                .foregroundStyle(Tone.mute)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 11))
                    }
                    .foregroundStyle(Tone.dawnDeep)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Tone.hair, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.98))
                .multilineTextAlignment(.leading)
            }
        }
    }
}

/// Pro：くわしい振り返り
struct ProStats: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let journal = model.paletteJournal
        let offset = journal.averageOffset(lastDays: 30, asOf: model.now, calendar: model.calendar)
        let byWeekday = Insights.weekdayRates(journal, calendar: model.calendar)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("この 30 日の平均")
                    .font(Typo.small)
                    .foregroundStyle(Tone.mute)
                Spacer()
                Text(verbatim: offsetText(offset))
                    .font(Typo.serif(17))
                    .foregroundStyle(Tone.ink)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("曜日ごとの、窓の中で起きた割合")
                    .font(Typo.small)
                    .foregroundStyle(Tone.mute)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Tone.dawn)
                                .frame(height: max(3, 54 * byWeekday[i]))
                            Text(verbatim: WeekdayHeader.symbols[i])
                                .font(Typo.caption)
                                .foregroundStyle(Tone.mute)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 74, alignment: .bottom)
            }
            Button {
                model.activeSheet = .share
            } label: {
                Label("1 年のポスターを書き出す", systemImage: "circle.dashed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Tone.dawnDeep)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Tone.sheet))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Tone.hair, lineWidth: 1))
    }

    private func offsetText(_ value: Double?) -> String {
        guard let value else { return "—" }
        let m = Int(value.rounded())
        if m < 0 { return tr("起きる時刻の \(-m) 分前", "\(-m) min before wake time") }
        return tr("起きる時刻の \(m) 分後", "\(m) min after wake time")
    }
}

/// Duo の内側：右の列の図鑑
struct AtlasPreview: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let found = model.showsSample ? model.paletteJournal.found : model.journal.found
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("空の図鑑")
                    .font(Typo.serif(21))
                    .foregroundStyle(Tone.ink)
                Spacer()
                Button("すべて見る") { model.cover = .atlas }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Tone.dawnDeep)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                ForEach(SkyCatalog.skies.prefix(12)) { page in
                    PageCard(page: page, found: found[page.id] != nil, unlocked: model.isUnlocked(page))
                }
            }
        }
    }
}

struct PrivacyFooter: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield").font(.system(size: 12))
            Text("写真と記録は、この iPhone の中だけに保存されます。送信しません。")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Typo.caption)
        .foregroundStyle(Tone.mute)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 振り返りの計算（Pro）
enum Insights {
    /// 曜日ごと（日曜から）の、窓の中で撮った割合（0〜1）
    static func weekdayRates(_ journal: Journal, calendar: Calendar) -> [Double] {
        var hit = [Int](repeating: 0, count: 7)
        var all = [Int](repeating: 0, count: 7)
        for record in journal.records.values {
            guard let date = DayKey.date(record.day, calendar: calendar) else { continue }
            let i = calendar.component(.weekday, from: date) - 1
            all[i] += 1
            if record.result.counts { hit[i] += 1 }
        }
        return (0..<7).map { all[$0] == 0 ? 0 : Double(hit[$0]) / Double(all[$0]) }
    }
}
