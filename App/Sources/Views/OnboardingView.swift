import SwiftUI

/// 最初の 3 ページ：窓 → 欠けたマス → 写真は端末の中だけ＋起きる時刻を決める
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        ZStack {
            Tone.ground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Tone.dawnDeep : Tone.hair)
                            .frame(width: i == page ? 18 : 6, height: 6)
                    }
                    Spacer()
                }
                .padding(.top, 12)
                .animation(.easeOut(duration: 0.25), value: page)
                ScrollView {
                    Group {
                        switch page {
                        case 0: windowPage
                        case 1: chippedPage
                        default: privacyPage
                        }
                    }
                    .transition(.opacity.combined(with: .offset(x: reduceMotion ? 0 : 24)))
                    .id(page)
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: Space.readable)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if page < 2 {
                    DeepButton(title: "次へ") {
                        model.pressTick += 1
                        withAnimation(.easeOut(duration: 0.3)) { page += 1 }
                    }
                    .accessibilityIdentifier("main.next")
                } else {
                    DeepButton(title: "はじめる", systemImage: "sun.horizon") {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: wake)
                        model.setWake(minutes: (c.hour ?? 7) * 60 + (c.minute ?? 0), weekday: nil)
                        model.pressTick += 1
                        model.onboarded = true
                    }
                    .accessibilityIdentifier("main.start")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: Space.readable)
            .frame(maxWidth: .infinity)
            .background(Tone.ground.ignoresSafeArea(edges: .bottom))
        }
        .onAppear {
            let m = model.schedule.minutes(forWeekday: 2)
            wake = Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? wake
        }
    }

    private var windowPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            let target = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()) ?? Date()
            WindowDial(now: target.addingTimeInterval(6 * 60), target: target,
                       phase: .open(target: target, secondsLeft: 9 * 60))
                .frame(height: 150)
            Eyebrow("1 / 3")
            Text("起きてからの 15 分が、空の図鑑になる")
                .font(Typo.serif(28))
                .kerning(-0.8)
                .foregroundStyle(Tone.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("起きると決めた時刻から 15 分以内に空を撮ると、その朝の空の色が 1 マスになって、今月のパレットと図鑑に入ります。")
                .font(Typo.body)
                .foregroundStyle(Tone.mute)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chippedPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            let cells = model.sampleJournal.monthCells(year: model.year, month: model.calendar.component(.month, from: model.now),
                                                       today: model.now, calendar: model.calendar)
            PaletteGrid(cells: cells, spacing: 5)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).fill(Tone.sheet))
                .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Tone.hair, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    Text("見本").font(Typo.label).foregroundStyle(Tone.glowDeep)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Tone.glowSoft))
                        .padding(8)
                }
            Eyebrow("2 / 3")
            Text("寝坊した朝は、マスが欠ける")
                .font(Typo.serif(28))
                .kerning(-0.8)
                .foregroundStyle(Tone.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("罰はありません。欠けたマスが見えるだけ。めずらしい空は、早起きした朝にしか出会えません。図鑑は 48 ページ。")
                .font(Typo.body)
                .foregroundStyle(Tone.mute)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacyPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow("3 / 3")
            Text("起きる時刻を決める")
                .font(Typo.serif(28))
                .kerning(-0.8)
                .foregroundStyle(Tone.ink)
            DatePicker("", selection: $wake, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .environment(\.locale, Lang.locale)
            Text("曜日ごとの時刻は、あとで設定から変えられます。")
                .font(Typo.small)
                .foregroundStyle(Tone.mute)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Tone.dawnDeep)
                Text("写真は色を読むためだけに使い、この iPhone の外には送りません。ログインも広告もありません。")
                    .font(Typo.small)
                    .foregroundStyle(Tone.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Tone.dawnPale))
        }
    }
}
