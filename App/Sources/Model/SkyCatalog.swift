import Foundation

/// 言語。撮影で日本語の画面を撮るときは forcedJapanese を立てる
enum Lang {
    nonisolated(unsafe) static var forcedJapanese = false

    static var isJapanese: Bool {
        forcedJapanese || (Bundle.main.preferredLocalizations.first ?? "ja").hasPrefix("ja")
    }

    static var locale: Locale { Locale(identifier: isJapanese ? "ja_JP" : "en_US") }
}

/// 中身のデータ（図鑑・空のメモ）の日本語と英語
func tr(_ ja: String, _ en: String) -> String { Lang.isJapanese ? ja : en }

/// 撮った朝の特徴。図鑑のどのページになるかを決める
struct SkyFeatures: Sendable {
    let swatches: [Swatch]
    let month: Int
    let day: Int
    /// 1 = 日曜
    let weekday: Int
    /// 起きる時刻からの分（マイナスは早起き）
    let minutes: Int
    let result: CatchResult
    /// この朝を入れた続けた朝
    let streak: Int
    /// 前の記録からあいた日数（最初なら nil）
    let gapDays: Int?

    var isFirst: Bool { gapDays == nil }
    private var hsls: [(HSL, Double)] {
        swatches.isEmpty ? [(HSL(h: 0, s: 0, l: 0.7), 1)] : swatches.map { ($0.color.hsl, $0.share) }
    }

    func share(_ test: (HSL) -> Bool) -> Double { hsls.filter { test($0.0) }.reduce(0) { $0 + $1.1 } }
    var avgL: Double { hsls.reduce(0) { $0 + $1.0.l * $1.1 } }
    var avgS: Double { hsls.reduce(0) { $0 + $1.0.s * $1.1 } }
    var top: HSL { hsls.first!.0 }
    var bottom: HSL { hsls.last!.0 }
    var contrast: Double {
        let ls = hsls.map { $0.0.l }
        return (ls.max() ?? 0) - (ls.min() ?? 0)
    }
    var blue: Double { share { $0.isBlue } }
    var warm: Double { share { $0.isWarm } }
    var gold: Double { share { $0.isGold } }
    var purple: Double { share { $0.isPurple } }
    var grey: Double { share { $0.isGrey } }
    var teal: Double { share { $0.isTeal } }
    var isSpring: Bool { (3...5).contains(month) }
    var isSummer: Bool { (6...8).contains(month) }
    var isAutumn: Bool { (9...11).contains(month) }
    var isWinter: Bool { month == 12 || month <= 2 }
    var counts: Bool { result.counts }

    static func hueGap(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }
}

/// 図鑑の 1 ページ
struct SkyPage: Identifiable, Sendable {
    enum Kind: String, Sendable { case sky, moment }

    let id: String
    let kind: Kind
    /// 1 ふつう・2 ときどき・3 めずらしい・4 まぼろし
    let rarity: Int
    let ja: String
    let en: String
    let noteJa: String
    let noteEn: String
    let hintJa: String
    let hintEn: String
    /// 図鑑のカードの色（上から）
    let colors: [RGB]
    let match: @Sendable (SkyFeatures) -> Bool

    var name: String { tr(ja, en) }
    var note: String { tr(noteJa, noteEn) }
    var hint: String { tr(hintJa, hintEn) }
    /// めずらしい・まぼろしのページは Pro の図鑑
    var isPro: Bool { rarity >= 3 }
    var rarityName: String {
        switch rarity {
        case 4: tr("まぼろし", "Mythic")
        case 3: tr("めずらしい", "Rare")
        case 2: tr("ときどき", "Uncommon")
        default: tr("ふつう", "Common")
        }
    }
}

/// 図鑑：空 36 ページ・朝 12 ページ（手で用意したもの）。上から順に調べ、最初に当てはまったページになる
enum SkyCatalog {
    static func page(_ id: String) -> SkyPage? { all.first { $0.id == id } }

    static var all: [SkyPage] { skies + moments }

    /// 空のページ（必ずどれか 1 つに当たる。最後は「薄曇り」）
    static func sky(for f: SkyFeatures) -> SkyPage {
        skies.first { $0.match(f) } ?? skies[skies.count - 1]
    }

    /// 朝のページ（当たらなければ nil）
    static func moment(for f: SkyFeatures) -> SkyPage? {
        moments.first { $0.match(f) }
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> RGB { RGB(r, g, b) }

    static let skies: [SkyPage] = [
        SkyPage(id: "first-of-year", kind: .sky, rarity: 4, ja: "一年の最初の空", en: "First Sky of the Year",
                noteJa: "1 月 1 日の朝にだけ現れる 1 枚。今年のパレットの最初のマス。", noteEn: "Only appears on the morning of January 1st — the first square of your year.",
                hintJa: "1 月 1 日の朝、窓の中で。", hintEn: "January 1st, inside your window.",
                colors: [c(0.72, 0.80, 0.91), c(0.95, 0.83, 0.78), c(0.98, 0.93, 0.86)],
                match: { $0.month == 1 && $0.day == 1 && $0.counts }),
        SkyPage(id: "summer-solstice", kind: .sky, rarity: 4, ja: "夏至の朝", en: "Solstice Morning",
                noteJa: "一年でいちばん早く日がのぼる頃。朝の光がいちばん長い。", noteEn: "The sun rises earliest of the year. The longest morning light.",
                hintJa: "6 月 20〜22 日の朝。", hintEn: "June 20–22, in the morning.",
                colors: [c(0.62, 0.79, 0.92), c(0.84, 0.91, 0.96), c(0.99, 0.92, 0.80)],
                match: { $0.month == 6 && (20...22).contains($0.day) && $0.counts }),
        SkyPage(id: "winter-solstice", kind: .sky, rarity: 4, ja: "冬至の朝", en: "Midwinter Morning",
                noteJa: "一年でいちばん遅い日の出。暗い朝に起きた人だけの空。", noteEn: "The latest sunrise of the year — a sky for those who rose in the dark.",
                hintJa: "12 月 21〜22 日の朝。", hintEn: "December 21–22, in the morning.",
                colors: [c(0.42, 0.50, 0.66), c(0.71, 0.70, 0.82), c(0.93, 0.82, 0.80)],
                match: { $0.month == 12 && (21...22).contains($0.day) && $0.counts }),
        SkyPage(id: "equinox", kind: .sky, rarity: 3, ja: "昼と夜が同じ朝", en: "Equinox Morning",
                noteJa: "昼と夜の長さがほぼ同じになる日。日の出は真東から。", noteEn: "Day and night are nearly equal; the sun rises due east.",
                hintJa: "3 月 19〜21 日か 9 月 22〜24 日。", hintEn: "March 19–21 or September 22–24.",
                colors: [c(0.70, 0.82, 0.92), c(0.90, 0.90, 0.92), c(0.97, 0.88, 0.80)],
                match: { (($0.month == 3 && (19...21).contains($0.day)) || ($0.month == 9 && (22...24).contains($0.day))) && $0.counts }),
        SkyPage(id: "fire-sky", kind: .sky, rarity: 4, ja: "燃える空", en: "Burning Sky",
                noteJa: "空の半分以上が橙と朱に染まる朝。数分で消える。", noteEn: "More than half the sky glows orange and red. Gone within minutes.",
                hintJa: "雲が多い朝の、日の出の直前。", hintEn: "Just before sunrise on a cloudy morning.",
                colors: [c(0.93, 0.60, 0.48), c(0.96, 0.72, 0.55), c(0.98, 0.84, 0.66)],
                match: { f in f.share { ($0.h < 35 || $0.h >= 330) && $0.s >= 0.45 && $0.l >= 0.3 } >= 0.55 }),
        SkyPage(id: "lingering-stars", kind: .sky, rarity: 4, ja: "星の残る空", en: "Lingering Stars",
                noteJa: "まだ夜の色。起きる時刻より 30 分以上早く空を見た人だけが知っている。", noteEn: "Still the color of night — known only to those up 30+ minutes early.",
                hintJa: "とても早起きをして、暗い空を。", hintEn: "Wake very early and catch the dark sky.",
                colors: [c(0.10, 0.13, 0.24), c(0.16, 0.20, 0.34), c(0.28, 0.30, 0.44)],
                match: { $0.avgL < 0.14 && $0.result == .early && $0.minutes <= -30 }),
        SkyPage(id: "horizon-glow", kind: .sky, rarity: 3, ja: "地平の光", en: "Horizon Glow",
                noteJa: "上は青、地平線の近くだけが暖かい。朝のいちばん美しい並び。", noteEn: "Blue above, warm only near the horizon — the loveliest morning order.",
                hintJa: "低い空まで入れて撮る。", hintEn: "Include the low sky in the frame.",
                colors: [c(0.60, 0.74, 0.88), c(0.82, 0.86, 0.92), c(0.97, 0.78, 0.64)],
                match: { $0.top.isBlue && $0.bottom.isWarm }),
        SkyPage(id: "crimson-band", kind: .sky, rarity: 3, ja: "茜の帯", en: "Crimson Ribbon",
                noteJa: "濃い茜色の雲が帯になって流れる。", noteEn: "A band of deep crimson cloud drifting across.",
                hintJa: "日の出の 10 分前ごろ、筋の雲がある朝。", hintEn: "About 10 minutes before sunrise, with streaky clouds.",
                colors: [c(0.80, 0.84, 0.92), c(0.88, 0.55, 0.52), c(0.96, 0.80, 0.70)],
                match: { f in f.share { ($0.h < 30 || $0.h >= 330) && $0.s >= 0.5 && $0.l >= 0.3 && $0.l < 0.62 } >= 0.2 }),
        SkyPage(id: "blue-and-peach", kind: .sky, rarity: 3, ja: "青と桃", en: "Blue and Peach",
                noteJa: "青い空に桃色の雲。朝焼けと晴れが同じ画面に入った。", noteEn: "Peach clouds on a blue sky — dawn and clear weather in one frame.",
                hintJa: "晴れの日の日の出のころ。", hintEn: "Around sunrise on a clear day.",
                colors: [c(0.64, 0.78, 0.91), c(0.95, 0.78, 0.72), c(0.78, 0.86, 0.94)],
                match: { $0.blue >= 0.25 && $0.warm >= 0.2 }),
        SkyPage(id: "violet-twilight", kind: .sky, rarity: 3, ja: "紫の薄明", en: "Violet Twilight",
                noteJa: "日の出の前、空が深い紫になるひととき。", noteEn: "The brief moment before sunrise when the sky turns deep violet.",
                hintJa: "日の出の 20〜30 分前。", hintEn: "20–30 minutes before sunrise.",
                colors: [c(0.30, 0.28, 0.48), c(0.48, 0.42, 0.62), c(0.80, 0.64, 0.72)],
                match: { $0.purple >= 0.3 && $0.avgL < 0.42 }),
        SkyPage(id: "predawn-navy", kind: .sky, rarity: 3, ja: "夜明け前の紺", en: "Predawn Navy",
                noteJa: "夜と朝のあいだの紺色。街灯がまだ点いている。", noteEn: "The navy between night and morning; streetlights still on.",
                hintJa: "冬の朝、日の出より前に。", hintEn: "A winter morning, before sunrise.",
                colors: [c(0.14, 0.20, 0.36), c(0.22, 0.30, 0.48), c(0.40, 0.46, 0.60)],
                match: { f in f.avgL < 0.28 && f.share { $0.h >= 200 && $0.h < 260 && $0.s >= 0.15 } >= 0.4 }),
        SkyPage(id: "celadon", kind: .sky, rarity: 3, ja: "青磁の空", en: "Celadon Sky",
                noteJa: "青と緑のあいだの、めずらしい色。空気が澄んだ朝に。", noteEn: "A rare tint between blue and green, on very clear air.",
                hintJa: "雨上がりの、日の出のすぐあと。", hintEn: "Right after sunrise following rain.",
                colors: [c(0.68, 0.84, 0.84), c(0.80, 0.90, 0.88), c(0.92, 0.95, 0.92)],
                match: { $0.teal >= 0.3 }),
        SkyPage(id: "cherry-haze", kind: .sky, rarity: 3, ja: "花曇り", en: "Blossom Haze",
                noteJa: "4 月の、ほんのり桃色を帯びた白い空。", noteEn: "April's white sky with a faint blush of pink.",
                hintJa: "4 月の曇りの朝。", hintEn: "A cloudy morning in April.",
                colors: [c(0.94, 0.88, 0.89), c(0.96, 0.92, 0.92), c(0.92, 0.90, 0.92)],
                match: { f in f.month == 4 && f.share { ($0.h >= 330 || $0.h < 20) && $0.s >= 0.08 && $0.s < 0.45 && $0.l >= 0.7 } >= 0.25 }),
        SkyPage(id: "snow-clouds", kind: .sky, rarity: 3, ja: "雪雲", en: "Snow Clouds",
                noteJa: "青みのある明るい灰色。雪の前の、静かな空。", noteEn: "Bright bluish grey — the quiet sky before snow.",
                hintJa: "冬の、明るい曇りの朝。", hintEn: "A bright, overcast winter morning.",
                colors: [c(0.80, 0.84, 0.89), c(0.86, 0.89, 0.92), c(0.91, 0.92, 0.94)],
                match: { f in f.isWinter && f.share { $0.h >= 185 && $0.h < 235 && $0.s < 0.2 && $0.l >= 0.72 } >= 0.5 }),
        SkyPage(id: "indian-summer", kind: .sky, rarity: 3, ja: "小春の空", en: "Indian Summer Sky",
                noteJa: "11 月の、春のようにやわらかい晴れ。", noteEn: "A November clear sky, soft as spring.",
                hintJa: "11 月の晴れた朝。", hintEn: "A clear morning in November.",
                colors: [c(0.66, 0.80, 0.92), c(0.80, 0.88, 0.95), c(0.93, 0.93, 0.90)],
                match: { $0.month == 11 && $0.blue >= 0.5 && $0.avgL >= 0.55 }),
        SkyPage(id: "rainy-season", kind: .sky, rarity: 2, ja: "梅雨の灰", en: "Monsoon Grey",
                noteJa: "6 月と 7 月の、重たい雲。起きた事実がいちばん光る季節。", noteEn: "Heavy June–July clouds. The season when just getting up shines most.",
                hintJa: "6〜7 月の曇りや雨の朝。", hintEn: "A cloudy or rainy morning in June or July.",
                colors: [c(0.66, 0.69, 0.72), c(0.74, 0.76, 0.78), c(0.80, 0.82, 0.83)],
                match: { (6...7).contains($0.month) && $0.grey >= 0.6 }),
        SkyPage(id: "golden-hour", kind: .sky, rarity: 2, ja: "金色の朝", en: "Golden Morning",
                noteJa: "日がのぼりきった直後の、金色の光。", noteEn: "The gold light just after the sun clears the horizon.",
                hintJa: "日の出の 10〜20 分後。", hintEn: "10–20 minutes after sunrise.",
                colors: [c(0.88, 0.86, 0.80), c(0.97, 0.86, 0.62), c(0.99, 0.93, 0.78)],
                match: { $0.gold >= 0.35 }),
        SkyPage(id: "morning-glow", kind: .sky, rarity: 2, ja: "朝焼け", en: "Morning Glow",
                noteJa: "東の空が暖かい色に染まる。早起きのいちばんのごほうび。", noteEn: "The east turns warm. The classic reward for rising early.",
                hintJa: "日の出の前後、東を向いて。", hintEn: "Face east around sunrise.",
                colors: [c(0.78, 0.82, 0.92), c(0.95, 0.76, 0.66), c(0.98, 0.88, 0.76)],
                match: { $0.warm >= 0.25 }),
        SkyPage(id: "lilac-daybreak", kind: .sky, rarity: 2, ja: "藤色の夜明け", en: "Lilac Daybreak",
                noteJa: "やわらかい藤色。空が夜を脱ぐところ。", noteEn: "Soft lilac — the sky slipping out of night.",
                hintJa: "日の出の少し前の、明るくなりかけた空。", hintEn: "Just before sunrise as the sky brightens.",
                colors: [c(0.72, 0.70, 0.86), c(0.82, 0.78, 0.90), c(0.94, 0.86, 0.88)],
                match: { $0.purple >= 0.25 }),
        SkyPage(id: "deep-blue", kind: .sky, rarity: 2, ja: "深い青", en: "Deep Blue",
                noteJa: "まだ暗さの残る、深い青。", noteEn: "A deep blue with a little night left in it.",
                hintJa: "日の出のすぐ前の、晴れた空。", hintEn: "A clear sky just before sunrise.",
                colors: [c(0.24, 0.38, 0.62), c(0.34, 0.50, 0.72), c(0.52, 0.64, 0.80)],
                match: { $0.blue >= 0.5 && $0.avgL < 0.45 }),
        SkyPage(id: "winter-crystal", kind: .sky, rarity: 2, ja: "冬の澄んだ青", en: "Winter Crystal",
                noteJa: "乾いた冬の空気の、硬くて濃い青。", noteEn: "The hard, clear blue of dry winter air.",
                hintJa: "12〜2 月の晴れた朝。", hintEn: "A clear morning, December to February.",
                colors: [c(0.46, 0.64, 0.86), c(0.60, 0.75, 0.90), c(0.80, 0.87, 0.94)],
                match: { $0.isWinter && $0.blue >= 0.5 && $0.avgS >= 0.35 }),
        SkyPage(id: "high-autumn", kind: .sky, rarity: 2, ja: "秋の高い空", en: "High Autumn Sky",
                noteJa: "秋の空は高く見える。雲が薄く、遠くまで青い。", noteEn: "Autumn skies look higher: thin clouds, blue all the way out.",
                hintJa: "9〜11 月の晴れた朝。", hintEn: "A clear morning, September to November.",
                colors: [c(0.56, 0.72, 0.89), c(0.70, 0.82, 0.93), c(0.88, 0.92, 0.95)],
                match: { $0.isAutumn && $0.blue >= 0.5 }),
        SkyPage(id: "summer-blue", kind: .sky, rarity: 2, ja: "夏の青", en: "Summer Blue",
                noteJa: "朝からもう強い、夏の青。", noteEn: "Summer blue, already strong first thing.",
                hintJa: "6〜8 月の晴れた朝。", hintEn: "A clear morning, June to August.",
                colors: [c(0.42, 0.66, 0.90), c(0.58, 0.77, 0.93), c(0.84, 0.91, 0.96)],
                match: { $0.isSummer && $0.blue >= 0.5 && $0.avgS >= 0.4 }),
        SkyPage(id: "fresh-leaf-blue", kind: .sky, rarity: 2, ja: "若葉の青", en: "New-Leaf Blue",
                noteJa: "5 月の、いちばん気持ちのいい青。", noteEn: "May's most pleasant blue.",
                hintJa: "5 月の晴れた朝。", hintEn: "A clear morning in May.",
                colors: [c(0.62, 0.78, 0.92), c(0.76, 0.86, 0.94), c(0.90, 0.94, 0.92)],
                match: { $0.month == 5 && $0.blue >= 0.4 }),
        SkyPage(id: "spring-haze", kind: .sky, rarity: 2, ja: "春がすみ", en: "Spring Haze",
                noteJa: "春の、白くかすんだやわらかい空。", noteEn: "The soft, milky haze of spring.",
                hintJa: "3〜5 月の、かすんだ朝。", hintEn: "A hazy morning, March to May.",
                colors: [c(0.86, 0.88, 0.90), c(0.90, 0.91, 0.91), c(0.94, 0.92, 0.90)],
                match: { $0.isSpring && $0.avgS < 0.25 && $0.avgS >= 0.06 && $0.avgL >= 0.7 }),
        SkyPage(id: "midsummer-glare", kind: .sky, rarity: 2, ja: "真夏の白", en: "Midsummer Glare",
                noteJa: "8 月の朝の、白く光る空。", noteEn: "August's white, glaring morning sky.",
                hintJa: "8 月の明るい朝。", hintEn: "A bright morning in August.",
                colors: [c(0.88, 0.92, 0.96), c(0.94, 0.95, 0.96), c(0.98, 0.97, 0.94)],
                match: { $0.month == 8 && $0.avgL >= 0.86 }),
        SkyPage(id: "fog", kind: .sky, rarity: 2, ja: "霧の朝", en: "Fog Morning",
                noteJa: "空と地面の境目が消える、白い朝。", noteEn: "A white morning where sky and ground blur together.",
                hintJa: "冷えた、風のない朝。", hintEn: "A cold, windless morning.",
                colors: [c(0.86, 0.87, 0.88), c(0.88, 0.89, 0.89), c(0.90, 0.90, 0.90)],
                match: { $0.grey >= 0.85 && $0.avgL >= 0.74 && $0.contrast < 0.12 }),
        SkyPage(id: "storm-grey", kind: .sky, rarity: 2, ja: "嵐の灰", en: "Storm Grey",
                noteJa: "暗く重い雲。こんな朝に起きたこと自体が記録になる。", noteEn: "Dark, heavy cloud. Getting up on a morning like this is its own record.",
                hintJa: "雨や風の強い朝。", hintEn: "A rainy or windy morning.",
                colors: [c(0.30, 0.33, 0.37), c(0.40, 0.43, 0.46), c(0.52, 0.54, 0.56)],
                match: { $0.grey >= 0.6 && $0.avgL < 0.36 }),
        SkyPage(id: "break-in-clouds", kind: .sky, rarity: 2, ja: "雲の切れ間", en: "Break in the Clouds",
                noteJa: "灰色の雲のあいだから、青がのぞく。", noteEn: "Blue peeking through grey cloud.",
                hintJa: "雨が上がりかけの朝。", hintEn: "A morning as the rain clears.",
                colors: [c(0.70, 0.73, 0.76), c(0.62, 0.76, 0.90), c(0.82, 0.84, 0.86)],
                match: { $0.grey >= 0.25 && $0.blue >= 0.25 }),
        SkyPage(id: "two-tone", kind: .sky, rarity: 2, ja: "二色の空", en: "Two-Tone Sky",
                noteJa: "上と下で、まったく違う色。", noteEn: "Completely different colors above and below.",
                hintJa: "空を縦に大きく入れて。", hintEn: "Frame the sky tall.",
                colors: [c(0.62, 0.72, 0.88), c(0.80, 0.80, 0.86), c(0.94, 0.86, 0.72)],
                match: { SkyFeatures.hueGap($0.top.h, $0.bottom.h) >= 60 && $0.top.s >= 0.2 && $0.bottom.s >= 0.2 }),
        SkyPage(id: "gradient-morning", kind: .sky, rarity: 1, ja: "グラデーションの朝", en: "Gradient Morning",
                noteJa: "上から下へ、明るさがなめらかに変わる。", noteEn: "Brightness flowing smoothly from top to bottom.",
                hintJa: "空を広く入れて。", hintEn: "Fit plenty of sky in.",
                colors: [c(0.50, 0.62, 0.80), c(0.72, 0.80, 0.90), c(0.92, 0.94, 0.96)],
                match: { $0.contrast >= 0.3 }),
        SkyPage(id: "pale-blue", kind: .sky, rarity: 1, ja: "水色の朝", en: "Pale Blue Morning",
                noteJa: "うすい水色。いちばんよくある、いちばんやさしい朝。", noteEn: "Pale blue — the most common, and the gentlest, morning.",
                hintJa: "晴れた朝、いつでも。", hintEn: "Any clear morning.",
                colors: [c(0.74, 0.84, 0.93), c(0.82, 0.89, 0.95), c(0.90, 0.94, 0.97)],
                match: { $0.blue >= 0.4 && $0.avgL >= 0.68 }),
        SkyPage(id: "clear-blue", kind: .sky, rarity: 1, ja: "晴れの青", en: "Clear Blue",
                noteJa: "雲のない、まっすぐな青。", noteEn: "A straight, cloudless blue.",
                hintJa: "晴れた朝。", hintEn: "A clear morning.",
                colors: [c(0.52, 0.70, 0.88), c(0.64, 0.79, 0.92), c(0.80, 0.88, 0.95)],
                match: { $0.blue >= 0.4 }),
        SkyPage(id: "white-sky", kind: .sky, rarity: 1, ja: "白い空", en: "White Sky",
                noteJa: "雲が一面に広がった、明るい白。", noteEn: "Bright white, clouds spread edge to edge.",
                hintJa: "明るい曇りの朝。", hintEn: "A bright, overcast morning.",
                colors: [c(0.88, 0.89, 0.90), c(0.92, 0.92, 0.93), c(0.95, 0.95, 0.95)],
                match: { $0.grey >= 0.6 && $0.avgL >= 0.82 }),
        SkyPage(id: "lead-clouds", kind: .sky, rarity: 1, ja: "鉛色の雲", en: "Lead Clouds",
                noteJa: "低く垂れこめた灰色。それでも起きた朝。", noteEn: "Low, heavy grey. You got up anyway.",
                hintJa: "暗い曇りの朝。", hintEn: "A dark, overcast morning.",
                colors: [c(0.48, 0.51, 0.55), c(0.56, 0.58, 0.61), c(0.66, 0.67, 0.69)],
                match: { $0.grey >= 0.5 && $0.avgL < 0.58 }),
        SkyPage(id: "thin-clouds", kind: .sky, rarity: 1, ja: "薄曇り", en: "Thin Clouds",
                noteJa: "うすい雲ごしの、やわらかい光。", noteEn: "Soft light through a thin veil of cloud.",
                hintJa: "どんな朝でも。", hintEn: "Any morning at all.",
                colors: [c(0.76, 0.80, 0.85), c(0.83, 0.86, 0.89), c(0.89, 0.91, 0.92)],
                match: { _ in true }),
    ]

    static let moments: [SkyPage] = [
        SkyPage(id: "first-sky", kind: .moment, rarity: 1, ja: "最初の空", en: "Your First Sky",
                noteJa: "図鑑の 1 ページ目。ここから集めはじめる。", noteEn: "Page one of your atlas. The collection starts here.",
                hintJa: "はじめて空を撮る。", hintEn: "Take your first sky.",
                colors: [c(0.74, 0.84, 0.93), c(0.92, 0.90, 0.92), c(0.97, 0.86, 0.80)],
                match: { $0.isFirst }),
        SkyPage(id: "thirtieth", kind: .moment, rarity: 4, ja: "三十日目の朝", en: "Thirtieth Morning",
                noteJa: "30 日続けて、窓の中で起きた。1 か月ぶんのパレット。", noteEn: "Thirty mornings in a row inside your window — a full month of palette.",
                hintJa: "30 日続ける。", hintEn: "Keep it up for 30 days.",
                colors: [c(0.66, 0.78, 0.90), c(0.94, 0.80, 0.74), c(0.98, 0.92, 0.80)],
                match: { $0.counts && $0.streak == 30 }),
        SkyPage(id: "fourteenth", kind: .moment, rarity: 3, ja: "十四日目の朝", en: "Fourteenth Morning",
                noteJa: "2 週間続いた。もう習慣と呼んでいい。", noteEn: "Two weeks straight. You can call it a habit now.",
                hintJa: "14 日続ける。", hintEn: "Keep it up for 14 days.",
                colors: [c(0.70, 0.80, 0.91), c(0.86, 0.84, 0.90), c(0.96, 0.88, 0.82)],
                match: { $0.counts && $0.streak == 14 }),
        SkyPage(id: "seventh", kind: .moment, rarity: 2, ja: "七日目の朝", en: "Seventh Morning",
                noteJa: "1 週間、毎朝の空がそろった。", noteEn: "A full week of morning skies.",
                hintJa: "7 日続ける。", hintEn: "Keep it up for 7 days.",
                colors: [c(0.72, 0.82, 0.92), c(0.88, 0.88, 0.92), c(0.95, 0.90, 0.86)],
                match: { $0.counts && $0.streak == 7 }),
        SkyPage(id: "third", kind: .moment, rarity: 1, ja: "三日目の朝", en: "Third Morning",
                noteJa: "三日坊主の壁をこえた。", noteEn: "Past the three-day wall.",
                hintJa: "3 日続ける。", hintEn: "Keep it up for 3 days.",
                colors: [c(0.76, 0.84, 0.92), c(0.88, 0.90, 0.93), c(0.94, 0.92, 0.90)],
                match: { $0.counts && $0.streak == 3 }),
        SkyPage(id: "hour-early", kind: .moment, rarity: 3, ja: "一時間早い朝", en: "An Hour Early",
                noteJa: "起きる時刻より 1 時間も前に、空を見た。", noteEn: "You saw the sky a full hour before your wake time.",
                hintJa: "起きる時刻の 60 分以上前に撮る。", hintEn: "Shoot 60+ minutes before your wake time.",
                colors: [c(0.28, 0.32, 0.50), c(0.56, 0.54, 0.70), c(0.90, 0.76, 0.76)],
                match: { $0.counts && $0.minutes <= -60 }),
        SkyPage(id: "early-riser", kind: .moment, rarity: 2, ja: "早起きの朝", en: "Early Riser",
                noteJa: "起きる時刻より 30 分早く起きた。", noteEn: "Up 30 minutes before your wake time.",
                hintJa: "起きる時刻の 30 分以上前に撮る。", hintEn: "Shoot 30+ minutes before your wake time.",
                colors: [c(0.52, 0.58, 0.76), c(0.76, 0.76, 0.88), c(0.94, 0.84, 0.82)],
                match: { $0.counts && $0.minutes <= -30 }),
        SkyPage(id: "on-the-dot", kind: .moment, rarity: 2, ja: "ぴったりの朝", en: "Right on Time",
                noteJa: "起きる時刻の 1 分の中で撮った。", noteEn: "Shot within a minute of your wake time.",
                hintJa: "起きる時刻ちょうどに撮る。", hintEn: "Shoot right at your wake time.",
                colors: [c(0.70, 0.82, 0.93), c(0.84, 0.90, 0.95), c(0.95, 0.92, 0.88)],
                match: { $0.result == .caught && $0.minutes == 0 }),
        SkyPage(id: "last-minute", kind: .moment, rarity: 2, ja: "ぎりぎりの朝", en: "Just Made It",
                noteJa: "窓が閉まる 1 分前。間に合った。", noteEn: "One minute before the window closed. Made it.",
                hintJa: "窓の最後の 1 分で撮る。", hintEn: "Shoot in the last minute of your window.",
                colors: [c(0.78, 0.84, 0.92), c(0.90, 0.88, 0.90), c(0.96, 0.84, 0.78)],
                match: { $0.result == .caught && $0.minutes >= 14 }),
        SkyPage(id: "welcome-back", kind: .moment, rarity: 1, ja: "おかえりの朝", en: "Welcome Back",
                noteJa: "しばらくぶりの空。また今日から集めればいい。", noteEn: "Your first sky in a while. Start collecting again today.",
                hintJa: "3 日以上あけてから、窓の中で撮る。", hintEn: "Catch your window after a 3+ day break.",
                colors: [c(0.80, 0.86, 0.92), c(0.92, 0.90, 0.90), c(0.97, 0.90, 0.84)],
                match: { $0.counts && ($0.gapDays ?? 0) >= 3 }),
        SkyPage(id: "weekend-early", kind: .moment, rarity: 1, ja: "休みの日の早起き", en: "Weekend Early Bird",
                noteJa: "休みの日でも、窓の中で起きた。", noteEn: "Inside your window, even on the weekend.",
                hintJa: "土曜か日曜に、窓の中で。", hintEn: "Saturday or Sunday, inside your window.",
                colors: [c(0.74, 0.84, 0.92), c(0.86, 0.90, 0.94), c(0.96, 0.90, 0.84)],
                match: { $0.counts && ($0.weekday == 1 || $0.weekday == 7) }),
        SkyPage(id: "monday", kind: .moment, rarity: 1, ja: "月曜の空", en: "Monday Sky",
                noteJa: "いちばん起きにくい曜日に、起きた。", noteEn: "Up on the hardest morning of the week.",
                hintJa: "月曜に、窓の中で。", hintEn: "Monday, inside your window.",
                colors: [c(0.70, 0.78, 0.88), c(0.84, 0.86, 0.90), c(0.92, 0.90, 0.88)],
                match: { $0.counts && $0.weekday == 2 }),
    ]
}
