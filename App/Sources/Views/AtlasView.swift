import SwiftUI

/// 図鑑：空 36 ページ・朝 12 ページ。見つけていないページは点線と「？」、Pro のページは鍵
struct AtlasView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var kind: SkyPage.Kind = .sky
    @State private var detail: String?
    @State private var paywall = false

    private var found: [String: String] { model.showsSample ? model.paletteJournal.found : model.journal.found }
    /// 見つけたページを先に、あとはふつう → まぼろしの順（最初に開いたとき、鍵と「？」だけにならないように）
    private var pages: [SkyPage] {
        let list = kind == .sky ? SkyCatalog.skies : SkyCatalog.moments
        let order = Dictionary(uniqueKeysWithValues: list.enumerated().map { ($1.id, $0) })
        return list.sorted { a, b in
            let fa = found[a.id] != nil, fb = found[b.id] != nil
            if fa != fb { return fa }
            if a.rarity != b.rarity { return a.rarity < b.rarity }
            return (order[a.id] ?? 0) < (order[b.id] ?? 0)
        }
    }

    var body: some View {
        ZStack {
            Tone.ground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("ATLAS OF MORNINGS")
                        HStack(alignment: .firstTextBaseline) {
                            Text("空の図鑑")
                                .font(Typo.serif(32))
                                .kerning(-0.8)
                                .foregroundStyle(Tone.ink)
                            Spacer()
                            Text(verbatim: "\(found.count)")
                                .font(Typo.serif(30, .light))
                                .monospacedDigit()
                                .foregroundStyle(Tone.ink)
                            Text(verbatim: "/ \(SkyCatalog.all.count)")
                                .font(Typo.serif(15))
                                .foregroundStyle(Tone.mute)
                        }
                        Text("空の色と、起きた朝のできごとで、ページが埋まっていきます。")
                            .font(Typo.small)
                            .foregroundStyle(Tone.mute)
                        if model.showsSample {
                            Text("いまは見本の図鑑です。最初の空を撮ると、あなたの図鑑になります。")
                                .font(Typo.small)
                                .foregroundStyle(Tone.glowDeep)
                        }
                    }
                    kindPicker
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: sizeClass == .regular ? 6 : 3), spacing: 18) {
                        ForEach(pages) { page in
                            Button {
                                model.pressTick += 1
                                detail = page.id
                            } label: {
                                PageCard(page: page, found: found[page.id] != nil, unlocked: model.isUnlocked(page))
                            }
                            .buttonStyle(PressStyle(scale: 0.95))
                        }
                    }
                    if !model.isPro {
                        Button {
                            paywall = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock")
                                Text("めずらしい空・まぼろしの空 18 ページは Pro の図鑑")
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.system(size: 11))
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Tone.dawnDeep)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Tone.hair, lineWidth: 1))
                        }
                        .buttonStyle(PressStyle(scale: 0.98))
                        .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: sizeClass == .regular ? 900 : Space.readable)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // 閉じるボタンは、スクロールしても画面の上に残す
            HStack {
                Button {
                    model.cover = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Tone.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("閉じる"))
                .accessibilityIdentifier("main.closeAtlas")
                Spacer()
            }
            .padding(.horizontal, 12)
            .background(Tone.ground.opacity(0.94).ignoresSafeArea(edges: .top))
        }
        .sheet(item: Binding(get: { detail.map { PageRef(id: $0) } }, set: { detail = $0?.id })) { ref in
            PageDetailView(pageID: ref.id) {
                detail = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    paywall = true
                }
            }
            .environment(model)
            .preferredColorScheme(.light)
            .modifier(JapaneseForScreenshots())
        }
        .sheet(isPresented: $paywall) {
            PaywallView(reason: .rarePage)
                .environment(model)
                .preferredColorScheme(.light)
                .modifier(JapaneseForScreenshots())
        }
    }

    private var kindPicker: some View {
        HStack(spacing: 0) {
            segment(.sky, "空", count: SkyCatalog.skies.filter { found[$0.id] != nil }.count, total: SkyCatalog.skies.count)
            segment(.moment, "朝のできごと", count: SkyCatalog.moments.filter { found[$0.id] != nil }.count, total: SkyCatalog.moments.count)
        }
        .padding(3)
        .background(Capsule().fill(Tone.dawnPale))
        .overlay(Capsule().stroke(Tone.hair, lineWidth: 1))
    }

    private func segment(_ value: SkyPage.Kind, _ title: LocalizedStringKey, count: Int, total: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) { kind = value }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Text(verbatim: "\(count)/\(total)").monospacedDigit().foregroundStyle(Tone.mute)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(kind == value ? Tone.ink : Tone.mute)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(Capsule().fill(kind == value ? Tone.sheet : .clear).shadow(color: kind == value ? Tone.shadow : .clear, radius: 4, y: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct PageRef: Identifiable, Hashable {
    let id: String
}

/// 図鑑の 1 ページ
struct PageDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let pageID: String
    var onUnlock: (() -> Void)?

    private var journal: Journal { model.showsSample ? model.paletteJournal : model.journal }

    var body: some View {
        let page = SkyCatalog.page(pageID) ?? SkyCatalog.skies[0]
        let firstDay = journal.found[page.id]
        let unlocked = model.isUnlocked(page)
        let days = journal.records.values.filter { $0.skyID == page.id || $0.momentID == page.id }.sorted { $0.day > $1.day }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        if firstDay != nil {
                            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                                .fill(skyGradient(colors: page.colors))
                        } else {
                            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                                .stroke(Tone.missing, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            Text(verbatim: "？").font(Typo.serif(40)).foregroundStyle(Tone.mute)
                        }
                        if !unlocked {
                            RoundedRectangle(cornerRadius: Radius.l, style: .continuous).fill(Tone.ground.opacity(0.5))
                            Image(systemName: "lock").font(.system(size: 20)).foregroundStyle(Tone.dawnDeep)
                        }
                    }
                    .frame(height: 220)
                    .shadow(color: Tone.shadow, radius: 12, y: 6)
                    HStack(spacing: 8) {
                        RarityDots(level: page.rarity)
                        Text(verbatim: page.rarityName)
                            .font(Typo.caption)
                            .foregroundStyle(Tone.rarity(page.rarity))
                        Text(verbatim: page.kind == .sky ? tr("空", "Sky") : tr("朝のできごと", "Morning"))
                            .font(Typo.caption)
                            .foregroundStyle(Tone.mute)
                    }
                    Text(verbatim: firstDay != nil || unlocked ? page.name : "？")
                        .font(Typo.serif(30))
                        .kerning(-0.8)
                        .foregroundStyle(Tone.ink)
                    if firstDay != nil && unlocked {
                        Text(verbatim: page.note)
                            .font(Typo.serif(16))
                            .foregroundStyle(Tone.ink)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("見つけ方")
                        Text(verbatim: page.hint)
                            .font(Typo.body)
                            .foregroundStyle(Tone.mute)
                    }
                    if let firstDay, let date = DayKey.date(firstDay, calendar: model.calendar) {
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow("最初に見つけた朝")
                            Text(verbatim: date.formatted(Date.FormatStyle().year().month(.wide).day().locale(Lang.locale)))
                                .font(Typo.serif(17))
                                .foregroundStyle(Tone.ink)
                        }
                    }
                    if !days.isEmpty && unlocked {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("この空の朝")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                                ForEach(days.prefix(32)) { record in
                                    SkyTile(state: .record(record))
                                }
                            }
                        }
                    }
                    if !unlocked {
                        DeepButton(title: "Pro の図鑑をひらく", systemImage: "lock.open") {
                            if let onUnlock {
                                onUnlock()
                            } else {
                                model.activeSheet = .paywall(.rarePage)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: Space.readable)
                .frame(maxWidth: .infinity)
            }
            .background(Tone.ground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(Tone.ink) }
                        .accessibilityLabel(Text("閉じる"))
                }
            }
        }
    }
}
