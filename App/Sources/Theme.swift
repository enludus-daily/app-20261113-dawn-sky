import SwiftUI

/// 色・書体・形はここだけで決める。
/// トーンは StudyReel（淡い・細い線・弱い影・セリフの見出し）。色の系統は「夜明けの水色」1 つ＋差し色の「朝の桃」。
/// 主役の色は、利用者が撮った空の色そのもの（パレットのマス）なので、地と飾りは静かにする。
enum Tone {
    // 地と文字
    static let ground = Color(hex: 0xF3F6F9)    // 画面の地（ほぼ白、わずかに青）
    static let sheet = Color(hex: 0xFBFCFD)     // 浮いた面
    static let ink = Color(hex: 0x2D3946)       // 文字（真っ黒にしない）
    static let mute = Color(hex: 0x8B97A4)      // 補助の文字
    static let hair = Color(hex: 0xDFE6EC)      // 細い線・地平線

    // 夜明けの水色（5 段階）
    static let dawn = Color(hex: 0x9DC1E1)      // accent L0.75
    static let dawnSoft = Color(hex: 0xE2ECF5)  // 選択中の地
    static let dawnDeep = Color(hex: 0x5884AE)  // 白い文字を載せるボタン・小さな文字
    static let dawnPale = Color(hex: 0xF0F5FA)  // 面
    static let dawnLine = Color(hex: 0xC5D9EA)  // 窓の弧

    // 朝の桃（差し色。太陽・新しいページ・窓の中の印）
    static let glow = Color(hex: 0xF3BBA3)      // L0.80
    static let glowSoft = Color(hex: 0xFBEAE2)
    static let glowDeep = Color(hex: 0xB9806A)  // 小さな文字

    /// 欠けたマス・まだのマスの線
    static let missing = Color(hex: 0xCDD5DD)

    static let shadow = Color(hex: 0x2D3946).opacity(0.07)
    static let shadowLift = Color(hex: 0x2D3946).opacity(0.16)

    /// めずらしさの印の色（数で段階を持たせる：ふつう → まぼろし）
    static func rarity(_ level: Int) -> Color {
        switch level {
        case 4: glowDeep
        case 3: glow
        case 2: dawnDeep
        default: dawn
        }
    }
}

enum Typo {
    /// 見出しと数字（セリフ）
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// 小さなラベル（字間を開けて使う）
    static let label = Font.system(size: 11, weight: .medium)
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
            .kerning(0.8)
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

/// 白い文字を載せる濃い水色のボタン（主な操作）。グラデーションは使わない
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(Tone.dawnDeep))
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
            .foregroundStyle(Tone.dawnDeep)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Capsule().stroke(Tone.dawnLine, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }
}
