import SwiftUI

@main
struct DawnSkyApp: App {
    @State private var model = Launch.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    @State var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.onboarded {
                HomeView()
                    // 全画面の場面やシートを出している間は、下のホームを読み上げ・UI テストの対象から外す
                    .accessibilityHidden(model.cover != nil || model.activeSheet != nil)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: model.onboarded)
        .environment(model)
        // 地はいつも空のグラデーション（白い文字）。システムの部品も暗い地の形にそろえる
        .preferredColorScheme(.dark)
        .modifier(JapaneseForScreenshots())
        .fullScreenCover(item: $model.cover) { cover in
            Group {
                switch cover {
                case .capture: CaptureFlowView()
                case .atlas: AtlasView()
                }
            }
            .environment(model)
            .preferredColorScheme(.dark)
            .modifier(JapaneseForScreenshots())
        }
        .sheet(item: $model.activeSheet) { sheet in
            sheetView(sheet)
                .environment(model)
                .preferredColorScheme(.dark)
                .modifier(JapaneseForScreenshots())
        }
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.catchTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.lateTick) { _, _ in model.hapticsOn ? .impact(flexibility: .soft, intensity: 0.5) : nil }
        .sensoryFeedback(trigger: model.newPageTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: model.placeTick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .task {
            // 窓の残り時間を進める（撮影・デモでは止める）
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if !model.frozen { model.now = Date() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !model.frozen { model.now = Date() }
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .settings: SettingsView()
        case .paywall(let reason): PaywallView(reason: reason)
        case .share: ShareView()
        case .page(let id): PageDetailView(pageID: id)
        }
    }
}

/// 撮影で日本語の画面を撮るとき（-screenshotScene <名前>_ja）、画面の文字と日付を日本語にする（CI のシミュレータは英語）
struct JapaneseForScreenshots: ViewModifier {
    @ViewBuilder
    func body(content: Self.Content) -> some View {
        if Launch.forcesJapanese {
            content.environment(\.locale, Locale(identifier: "ja_JP"))
        } else {
            content
        }
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（例：home_ja）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    /// 撮影中は動きを最後の形で止めて撮る
    static var isStill: Bool { scene != nil }

    /// 撮影の時刻：今日の 6:38（起きる時刻 6:30 の窓の中）。夜の画面は 21:40
    static func stageTime(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    /// UI テスト：毎回、最初の起動の状態から始める（保存した記録と設定を消す）
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["onboarded", "schedule", "keepPhotos", "haptics", "reminder", "lastPaywallDay"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            try? FileManager.default.removeItem(at: AppModel.journalURL)
        }
        guard isDemo || scene != nil else { return AppModel() }
        let night = scene == "night"
        let late = scene == "late"
        let now = night ? stageTime(hour: 21, minute: 40) : late ? stageTime(hour: 7, minute: 24) : stageTime(hour: 6, minute: 38)
        let model = AppModel(persists: false, now: now)
        model.schedule = WakeSchedule(minutes: Array(repeating: 390, count: 7))
        model.onboarded = scene != "onboarding" && scene != "tutorial"
        if scene != "empty" && scene != "onboarding" {
            model.journal = AppModel.makeSamples(endingBefore: now, days: 52, schedule: model.schedule, calendar: model.calendar)
        }
        if scene == "pro" || scene == "year" || scene == "rest" { model.proOverride = true }
        if scene == "denied" { model.cameraDeniedOverride = true }
        return model
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(300))
        switch scene {
        case "reveal", "late":
            model.startCapture()
            model.capture(sample: scene == "late" ? .overcast : .dawnGlow)
        case "choose", "denied":
            model.startCapture()
        case "atlas", "pro":
            model.cover = .atlas
        case "page":
            model.activeSheet = .page("horizon-glow")
        case "share", "year":
            model.activeSheet = .share
        case "settings", "rest":
            model.activeSheet = .settings
        case "paywall":
            model.activeSheet = .paywall(.firstMornings)
        case "lastmonth":
            model.monthOffset = -1
        case "done":
            model.capture(sample: .clearBlue)
            model.cover = nil
        default:
            break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }
        model.journal = AppModel.makeSamples(endingBefore: model.now, days: 40, schedule: model.schedule, calendar: model.calendar)
        await wait(2.2)
        // 窓の中で、空を撮る
        model.startCapture()
        await wait(1.4)
        model.capture(sample: .dawnGlow)
        await wait(6.0)
        // パレットに置く
        model.place()
        await wait(3.0)
        // 図鑑
        model.cover = .atlas
        await wait(3.2)
        model.cover = nil
        await wait(0.8)
        // 今月の空のパレットを共有
        model.activeSheet = .share
    }
}
