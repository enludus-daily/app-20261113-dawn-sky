import SwiftUI

/// 色・書体・形はここだけで決める。
/// 世界は「夜明けの空そのもの」。画面の地は時刻で変わる空のグラデーション（`SkyClock`）、撮った朝は撮った空の色。
/// 文字と線は空の上に白で載せる。白い枠のカードは使わず、面は空に溶ける薄い白（ベール）だけ。
/// 差し色は「日の光」の金と桃（太陽・窓・新しいページ）。見出しと数字は細いサンセリフ（天気や写真集のように）
enum Tone {
    // 地と文字（空の上）
    static let ground = Color(hex: 0x0F1534)                 // 地の色の予備（夜の空）
    static let sheet = Color.white.opacity(0.09)              // ベール（空に溶ける面）
    static let ink = Color.white.opacity(0.96)                // 文字
    static let mute = Color.white.opacity(0.68)               // 補助の文字
    static let hair = Color.white.opacity(0.22)               // 細い線・地平線

    // 空の上の水色（5 段階）
    static let dawn = Color(hex: 0xA8C8EE)                    // accent：棒・まだのしるし
    static let dawnSoft = Color.white.opacity(0.18)           // 選択中の面
    static let dawnDeep = Color(hex: 0xFFE3BF)                // 押せる文字・トグル（朝の光の色）
    static let dawnPale = Color.white.opacity(0.06)           // ごく薄い面
    static let dawnLine = Color.white.opacity(0.42)           // 押せる線・窓の弧

    // 日の光（差し色。太陽・新しいページ・窓の中の印）
    static let glow = Color(hex: 0xFFB37E)                    // 太陽
    static let glowSoft = Color(hex: 0xFFB37E).opacity(0.24)
    static let glowDeep = Color(hex: 0xFFD3A8)                // 空の上で読める金の文字

    /// 主なボタン（白い面）の上の文字：夜の藍
    static let night = Color(hex: 0x141A3C)

    /// 欠けたマス・まだのマスの線
    static let missing = Color.white.opacity(0.38)

    static let shadow = Color.black.opacity(0.18)
    static let shadowLift = Color.black.opacity(0.32)

    /// めずらしさの印の色（数で段階を持たせる：ふつう → まぼろし。空の色から日の光へ）
    static func rarity(_ level: Int) -> Color {
        switch level {
        case 4: Color(hex: 0xFF9E7A)
        case 3: glow
        case 2: glowDeep
        default: dawn
        }
    }
}

enum Typo {
    /// 見出し（細いサンセリフ。写真集の題のように字間を少し開ける）
    static func display(_ size: CGFloat, _ weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// 大きな数字（天気の気温のように、ごく細く）
    static func numeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .thin, design: .default)
    }

    /// 小さなラベル（字間を大きく開けて使う）
    static let label = Font.system(size: 10.5, weight: .semibold)
    static let body = Font.system(size: 14)
    static let small = Font.system(size: 12)
    static let caption = Font.system(size: 11)
}

enum Radius {
    static let s: CGFloat = 6
    static let m: CGFloat = 12
    static let l: CGFloat = 18
    /// マスの角は大きさに合わせる
    static func tile(_ side: CGFloat) -> CGFloat { max(4, side * 0.24) }
}

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    /// 大きい画面で幅を抑える
    static let readable: CGFloat = 560
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    init(_ rgb: RGB) {
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

/// 小さなラベル（字間を開けた大文字のような見出し）
struct Eyebrow: View {
    let text: LocalizedStringKey
    var color: Color = Tone.mute

    init(_ text: LocalizedStringKey, color: Color = Tone.mute) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Typo.label)
            .kerning(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// 押すと少し沈む（動きを減らす設定では沈まない）
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 主な操作：空の上に浮く白い面（夜の藍の文字）。グラデーションは使わない
struct DeepButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .medium)) }
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Tone.night)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(Color.white.opacity(0.94)))
            .shadow(color: Tone.shadow, radius: 14, y: 6)
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }
}

/// 細い線のボタン（副の操作）
struct HairButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 13)) }
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Tone.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().stroke(Tone.dawnLine, lineWidth: 0.8))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }
}

/// 画面の地：空のグラデーション。上の色から下の色へ。地平の近くに日の光を少しにじませ、上は文字が読めるよう少し沈める
struct SkyBackdrop: View {
    let colors: [RGB]
    var glow: Double = 0.35
    var body: some View {
        ZStack {
            LinearGradient(colors: colors.map { Color($0) }, startPoint: .top, endPoint: .bottom)
            // 地平線のにじみ（日の光）
            RadialGradient(colors: [Tone.glow.opacity(glow), .clear], center: UnitPoint(x: 0.5, y: 1.05),
                           startRadius: 0, endRadius: 420)
            // 文字の読みやすさのための、ごく薄い影
            LinearGradient(colors: [Color.black.opacity(0.12), .clear, Color.black.opacity(0.14)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 今の空：撮った朝はその空の色、ほかは時刻の色
struct CurrentSky: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SkyBackdrop(colors: model.backdropColors, glow: model.backdropGlow)
    }
}

extension View {
    /// 空を地にして、システムの部品（トグル・時刻の選択・閉じるボタン）を暗い地の形にする
    func onSky() -> some View {
        background(CurrentSky())
            .toolbarBackground(.hidden, for: .navigationBar)
            .environment(\.colorScheme, .dark)
    }
}

/// 画面の下に固定するボタンの地：空の上に、下へ向かって少し沈む帯（線や白い面で区切らない）
struct BottomFade: View {
    var body: some View {
        LinearGradient(colors: [.clear, Color.black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
    }
}
