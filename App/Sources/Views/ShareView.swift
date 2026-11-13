import SwiftUI

enum ShareStyle: String, CaseIterable, Identifiable {
    case month, ring, strip
    var id: String { rawValue }
    var isPro: Bool { self != .month }
}

/// 共有カード：今月の空のパレット（無料）・1 年の輪と帯のポスター（Pro）。画像は端末の中で作り、共有先は利用者が選ぶ
struct ShareView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var style: ShareStyle = Launch.scene == "year" ? .ring : .month
    @State private var rendered: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 8) {
                        chip(.month, "今月のパレット")
                        chip(.ring, "1 年の輪")
                        chip(.strip, "朝の帯")
                    }
                    card
                        .frame(width: 300, height: 375)
                        .shadow(color: Tone.shadowLift, radius: 14, y: 8)
                        .padding(.vertical, 6)
                    if model.showsSample {
                        Text("見本のパレットです。空を撮ると、あなたの色になります。")
                            .font(Typo.small)
                            .foregroundStyle(Tone.mute)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(Tone.ground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Group {
                    if style.isPro && !model.isPro {
                        DeepButton(title: "Pro で書き出す", systemImage: "lock.open") {
                            model.activeSheet = .paywall(.poster)
                        }
                    } else if let rendered {
                        let image = Image(uiImage: rendered)
                        ShareLink(item: image, preview: SharePreview("あさやけ図鑑", image: image)) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .medium))
                                Text("共有する").font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Capsule().fill(Tone.dawnDeep))
                        }
                        .accessibilityIdentifier("main.shareLink")
                    } else {
                        ProgressView().frame(height: 52)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Tone.ground.ignoresSafeArea(edges: .bottom))
            }
            .navigationTitle(Text("共有カード"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(Tone.ink) }
                        .accessibilityLabel(Text("閉じる"))
                }
            }
            .task(id: style) { render() }
        }
    }

    private func chip(_ value: ShareStyle, _ title: LocalizedStringKey) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) { style = value }
        } label: {
            HStack(spacing: 4) {
                if value.isPro && !model.isPro { Image(systemName: "lock").font(.system(size: 10)) }
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(style == value ? Tone.ink : Tone.mute)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Capsule().fill(style == value ? Tone.dawnSoft : .clear))
            .overlay(Capsule().stroke(style == value ? Tone.dawnLine : Tone.hair, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var card: ShareCard {
        let journal = model.paletteJournal
        let m = model.shownMonth
        let date = model.calendar.date(from: DateComponents(year: m.year, month: m.month, day: 1)) ?? model.now
        let score = journal.monthScore(year: m.year, month: m.month, today: model.now, calendar: model.calendar)
        let strip = journal.records.values.sorted { $0.day < $1.day }.suffix(30)
        return ShareCard(style: style,
                         title: date.formatted(Date.FormatStyle().year().month(.wide).locale(Lang.locale)),
                         cells: journal.monthCells(year: m.year, month: m.month, today: model.now, calendar: model.calendar),
                         yearDays: journal.yearDays(year: model.year, calendar: model.calendar),
                         year: model.year,
                         strip: Array(strip),
                         caught: score.caught,
                         days: score.days,
                         streak: journal.streak(asOf: model.now, calendar: model.calendar),
                         found: journal.found.count)
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: card.frame(width: 360, height: 450).environment(\.locale, Lang.locale))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}

/// 共有する 1 枚（360×450 を 3 倍で書き出す）
struct ShareCard: View {
    let style: ShareStyle
    let title: String
    let cells: [MonthCell]
    let yearDays: [DayRecord?]
    let year: Int
    let strip: [DayRecord]
    let caught: Int
    let days: Int
    let streak: Int
    let found: Int

    var body: some View {
        ZStack {
            Tone.sheet
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: tr("あさやけ図鑑", "Dawn Atlas"))
                        .font(.system(size: 10, weight: .medium))
                        .kerning(1.2)
                        .foregroundStyle(Tone.mute)
                    Spacer()
                    Text(verbatim: style == .ring ? "\(year)" : title)
                        .font(.system(size: 10, weight: .medium))
                        .kerning(0.8)
                        .foregroundStyle(Tone.mute)
                }
                switch style {
                case .month:
                    Text(verbatim: tr("今月の空のパレット", "This month's sky palette"))
                        .font(Typo.serif(22))
                        .kerning(-0.5)
                        .foregroundStyle(Tone.ink)
                    PaletteGrid(cells: cells, spacing: 5)
                    let records: [DayRecord] = cells.compactMap { (cell: MonthCell) -> DayRecord? in if case .record(let r) = cell.state { return r } else { return nil } }
                    if !records.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(records) { r in
                                Rectangle().fill(skyGradient(r.swatches)).opacity(r.result == .late ? 0.4 : 1)
                            }
                        }
                        .frame(height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        if let top = Self.mostFrequent(records) {
                            Text(verbatim: tr("今月いちばん多かった空：\(top)", "Most frequent sky: \(top)"))
                                .font(Typo.serif(12))
                                .foregroundStyle(Tone.mute)
                        }
                    }
                case .ring:
                    Text(verbatim: tr("1 年の朝の輪", "A year of mornings"))
                        .font(Typo.serif(22))
                        .kerning(-0.5)
                        .foregroundStyle(Tone.ink)
                    YearRing(days: yearDays, lineWidthRatio: 0.34)
                        .padding(.horizontal, 28)
                case .strip:
                    Text(verbatim: tr("朝の帯：最近の 30 朝", "Morning strip: last 30"))
                        .font(Typo.serif(22))
                        .kerning(-0.5)
                        .foregroundStyle(Tone.ink)
                    HStack(spacing: 2) {
                        ForEach(strip) { record in
                            Rectangle()
                                .fill(skyGradient(record.swatches))
                                .opacity(record.result == .late ? 0.4 : 1)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                Spacer(minLength: 0)
                HStack(spacing: 18) {
                    figure("\(caught)/\(days)", tr("窓の中の朝", "in the window"))
                    figure("\(streak)", tr("続けた朝", "streak"))
                    figure("\(found)", tr("図鑑", "atlas pages"))
                }
            }
            .padding(22)
        }
    }

    static func mostFrequent(_ records: [DayRecord]) -> String? {
        var counts: [String: Int] = [:]
        for r in records { counts[r.skyID, default: 0] += 1 }
        guard let best = counts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }) else { return nil }
        return SkyCatalog.page(best.key)?.name
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: value)
                .font(Typo.serif(20))
                .monospacedDigit()
                .foregroundStyle(Tone.ink)
            Text(verbatim: label)
                .font(.system(size: 9))
                .kerning(0.4)
                .foregroundStyle(Tone.mute)
        }
    }
}
