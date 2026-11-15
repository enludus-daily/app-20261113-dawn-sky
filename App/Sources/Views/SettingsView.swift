import SwiftUI

/// 設定：起きる時刻（曜日ごと）・お知らせ・写真・休む日・振動・Pro・使い方・プライバシー
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var perDay = false
    @State private var confirmDelete = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section("起きる時刻") {
                        VStack(spacing: 0) {
                            Toggle(isOn: $perDay.animation(.easeOut(duration: 0.25))) {
                                Text("曜日ごとに変える")
                            }
                            .tint(Tone.glow)
                            .padding(.vertical, 10)
                            if perDay {
                                ForEach(1...7, id: \.self) { weekday in
                                    hair
                                    timeRow(label: Text(verbatim: weekdayName(weekday)), minutes: model.schedule.minutes(forWeekday: weekday)) {
                                        model.setWake(minutes: $0, weekday: weekday)
                                    }
                                }
                            } else {
                                hair
                                timeRow(label: Text("毎日"), minutes: model.schedule.minutes(forWeekday: 2)) {
                                    model.setWake(minutes: $0, weekday: nil)
                                }
                            }
                        }
                        note("起きる時刻から 15 分が「窓」です。窓の中で空を撮ると、マスが埋まります。2 時間前から撮れば早起きの印がつきます。")
                    }
                    section("お知らせ") {
                        Toggle(isOn: Binding(get: { model.reminderOn }, set: { on in Task { await model.setReminder(on) } })) {
                            Text("起きる時刻にお知らせする")
                        }
                        .tint(Tone.glow)
                        note("端末の中だけで予約するお知らせです。目覚ましの代わりではありません。")
                    }
                    section("写真") {
                        Toggle(isOn: $model.keepPhotos) {
                            Text("撮った写真を小さく残す")
                        }
                        .tint(Tone.glow)
                        note("オフにすると、写真は色を読んだらすぐに捨て、色だけを残します。写真も色も、この iPhone の外には送りません。")
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("残した写真をすべて消す")
                                .font(.system(size: 14))
                        }
                        .padding(.top, 4)
                    }
                    section("休む日（Pro）") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("今日を休む日にする")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Tone.ink)
                                Text(verbatim: tr("今月 \(model.restDaysThisMonth) 日", "\(model.restDaysThisMonth) this month"))
                                    .font(Typo.small)
                                    .foregroundStyle(Tone.mute)
                            }
                            Spacer()
                            Button {
                                model.toggleRest(on: model.now)
                            } label: {
                                Group {
                                    if model.journal.restDays.contains(model.todayKey) { Text("休むのをやめる") } else { Text("休む") }
                                }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Tone.dawnDeep)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 36)
                                    .background(Capsule().stroke(Tone.dawnLine, lineWidth: 1))
                            }
                            .buttonStyle(PressStyle())
                        }
                        note("体調の悪い日や旅行の日。続けた朝を途切れさせず、マスには月のしるしが入ります。")
                    }
                    section("手ざわり") {
                        Toggle(isOn: $model.hapticsOn) {
                            Text("振動")
                        }
                        .tint(Tone.glow)
                        note("音は鳴らしません。朝は家族が寝ていることが多いためです。")
                    }
                    section("Pro") {
                        if model.isPro {
                            Label("Pro をお使いいただいています", systemImage: "checkmark.seal")
                                .foregroundStyle(Tone.dawnDeep)
                        } else {
                            Button {
                                model.activeSheet = .paywall(.settings)
                            } label: {
                                HStack {
                                    Text("あさやけ図鑑 Pro")
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12))
                                }
                                .foregroundStyle(Tone.dawnDeep)
                            }
                        }
                        Button("購入を復元") {
                            Task { await model.purchases.restore() }
                        }
                        .foregroundStyle(Tone.dawnDeep)
                    }
                    section("そのほか") {
                        Button("使い方をもう一度見る") {
                            dismiss()
                            model.onboarded = false
                        }
                        .foregroundStyle(Tone.dawnDeep)
                        note("写真と記録は、この iPhone の中（アプリの中）だけに保存されます。サーバー・ログイン・広告・解析はありません。アプリを消すと、記録も消えます。")
                    }
                }
                .padding(20)
                .frame(maxWidth: Space.readable)
                .frame(maxWidth: .infinity)
            }
            .onSky()
            .navigationTitle(Text("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(Tone.dawnDeep)
                }
            }
            .confirmationDialog("残した写真をすべて消しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("消す", role: .destructive) { model.deletePhotos() }
            } message: {
                Text("空の色とマスは残ります。")
            }
            .onAppear { perDay = !model.schedule.isSameEveryDay }
        }
    }

    private var hair: some View { Rectangle().fill(Tone.hair).frame(height: 1) }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title)
            VStack(alignment: .leading, spacing: 8) { content() }
                .font(.system(size: 15))
                .foregroundStyle(Tone.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Tone.sheet))
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typo.small)
            .foregroundStyle(Tone.mute)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func timeRow(label: Text, minutes: Int, onChange: @escaping (Int) -> Void) -> some View {
        let binding = Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                onChange((c.hour ?? 7) * 60 + (c.minute ?? 0))
            }
        )
        return HStack {
            label
            Spacer()
            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.locale, Lang.locale)
        }
        .frame(minHeight: 44)
    }

    private func weekdayName(_ weekday: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Lang.locale
        return cal.weekdaySymbols[weekday - 1]
    }
}
