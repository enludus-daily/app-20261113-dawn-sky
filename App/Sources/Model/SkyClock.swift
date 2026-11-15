import Foundation

/// 時刻ごとの空の色（画面の地）。夜 → 青い時間 → 夜明け → 朝 → 昼 → 夕暮れ → 夜。
/// 決まった時刻の色見本（上・中・下の 3 色）のあいだを混ぜてつなぐ。白い文字が読めるよう、どの時刻も明るくしすぎない
enum SkyClock {
    struct Key {
        let minute: Int
        let top: RGB
        let middle: RGB
        let bottom: RGB
    }

    static let keys: [Key] = [
        Key(minute: 0, top: hex(0x070A1C), middle: hex(0x0F1534), bottom: hex(0x1A2246)),          // 真夜中
        Key(minute: 4 * 60, top: hex(0x0A0F2A), middle: hex(0x1C2457), bottom: hex(0x34356E)),     // 夜明け前
        Key(minute: 5 * 60, top: hex(0x18245A), middle: hex(0x4A4389), bottom: hex(0x9A5E8A)),     // 青い時間
        Key(minute: 6 * 60, top: hex(0x2B3A78), middle: hex(0x8A5C93), bottom: hex(0xC06A55)),     // 朝焼け
        Key(minute: 7 * 60, top: hex(0x355A9A), middle: hex(0x7A6A9A), bottom: hex(0xB06E56)),     // 日の出
        Key(minute: 9 * 60, top: hex(0x2C5C9E), middle: hex(0x3F70AC), bottom: hex(0x4F7DAF)),     // 朝
        Key(minute: 15 * 60, top: hex(0x22528F), middle: hex(0x3A68A3), bottom: hex(0x4C7AAD)),    // 昼
        Key(minute: 17 * 60, top: hex(0x2E3F7C), middle: hex(0x8A5F8E), bottom: hex(0xB4654F)),    // 夕焼け
        Key(minute: 19 * 60, top: hex(0x151C46), middle: hex(0x3B2F66), bottom: hex(0x7A4A72)),    // 夕暮れ
        Key(minute: 21 * 60, top: hex(0x0A0E26), middle: hex(0x141B3F), bottom: hex(0x252A55)),    // 夜
        Key(minute: 24 * 60, top: hex(0x070A1C), middle: hex(0x0F1534), bottom: hex(0x1A2246)),   // 真夜中（0 時と同じ）
    ]

    /// 0 時からの分で、上・中・下の 3 色
    static func colors(minute: Int) -> [RGB] {
        let m = ((minute % 1440) + 1440) % 1440
        for i in 0..<(keys.count - 1) where m >= keys[i].minute && m < keys[i + 1].minute {
            let a = keys[i], b = keys[i + 1]
            let t = Double(m - a.minute) / Double(b.minute - a.minute)
            return [a.top.mixed(with: b.top, t), a.middle.mixed(with: b.middle, t), a.bottom.mixed(with: b.bottom, t)]
        }
        return [keys[0].top, keys[0].middle, keys[0].bottom]
    }

    static func colors(at date: Date, calendar: Calendar = .current) -> [RGB] {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return colors(minute: (c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    /// 撮った空の色を、画面の地にできる明るさまで沈める（白い文字が読めるように）。上の色から並べる
    static func backdrop(from swatches: [Swatch]) -> [RGB] {
        backdrop(colors: swatches.sorted { $0.height < $1.height }.map(\.color))
    }

    /// 上から順の色を、画面の地の色に
    static func backdrop(colors ordered: [RGB]) -> [RGB] {
        guard !ordered.isEmpty else { return colors(minute: 6 * 60) }
        let night = hex(0x0B1030)
        return ordered.enumerated().map { i, c in
            // 上ほど夜の色を多く混ぜる（写真集の上の余白のように、文字の載る所を落ち着かせる）
            let depth = ordered.count == 1 ? 0.45 : 0.55 - 0.25 * Double(i) / Double(ordered.count - 1)
            return dimmed(c, toLuminance: 0.42).mixed(with: night, depth)
        }
    }

    /// 明るすぎる色だけ、明るさを上限まで下げる
    static func dimmed(_ c: RGB, toLuminance limit: Double) -> RGB {
        let y = luminance(c)
        guard y > limit, y > 0 else { return c }
        let k = limit / y
        return RGB(c.r * k, c.g * k, c.b * k)
    }

    static func luminance(_ c: RGB) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    static func hex(_ v: UInt32) -> RGB {
        RGB(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }
}
