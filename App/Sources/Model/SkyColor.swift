import Foundation

/// 色（0〜1）。写真から取った空の色を、端末の中に保存する形
struct RGB: Codable, Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = min(max(r, 0), 1)
        self.g = min(max(g, 0), 1)
        self.b = min(max(b, 0), 1)
    }

    var hsl: HSL {
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        let d = maxV - minV
        guard d > 0.0001 else { return HSL(h: 0, s: 0, l: l) }
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double
        if maxV == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if maxV == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h *= 60
        return HSL(h: h, s: s, l: l)
    }

    func distance(to other: RGB) -> Double {
        let dr = r - other.r, dg = g - other.g, db = b - other.b
        return dr * dr + dg * dg + db * db
    }

    /// 2 つの色を混ぜる（t = 0 で自分、1 で相手）
    func mixed(with other: RGB, _ t: Double) -> RGB {
        RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }
}

/// 色相（0〜360）・彩度・明度
struct HSL: Equatable, Sendable {
    let h: Double
    let s: Double
    let l: Double

    var isBlue: Bool { h >= 190 && h < 255 && s >= 0.2 && l >= 0.18 && l <= 0.93 }
    var isWarm: Bool { (h < 50 || h >= 330) && s >= 0.3 && l >= 0.3 && l <= 0.92 }
    var isGold: Bool { h >= 38 && h < 70 && s >= 0.35 && l >= 0.4 && l <= 0.9 }
    var isPurple: Bool { h >= 255 && h < 330 && s >= 0.15 && l >= 0.15 }
    var isGrey: Bool { s < 0.14 }
    var isTeal: Bool { h >= 150 && h < 190 && s >= 0.15 && l >= 0.25 }
}

/// 写真の 1 点（色と、上からの位置 0〜1）
struct SkySample: Sendable {
    let color: RGB
    let y: Double
}

/// 写真から取った空の色 1 つ。share は写真の中での割合、height は上からの平均の位置
struct Swatch: Codable, Hashable, Sendable {
    let color: RGB
    let share: Double
    let height: Double
}

/// 写真の主な色を 2〜3 色取る（決まった初期値の k-means。毎回同じ結果になる）
enum SkyExtractor {
    static func swatches(from samples: [SkySample], count k: Int = 3, iterations: Int = 10) -> [Swatch] {
        guard !samples.isEmpty, k > 0 else { return [] }
        // 初期値：明るさの順に並べて、等間隔の位置の色
        let sorted = samples.sorted { luminance($0.color) < luminance($1.color) }
        var centers: [RGB] = (0..<k).map { i in
            let index = min(sorted.count - 1, Int((Double(i) + 0.5) / Double(k) * Double(sorted.count)))
            return sorted[index].color
        }
        var assignment = [Int](repeating: 0, count: samples.count)
        for _ in 0..<iterations {
            for (i, sample) in samples.enumerated() {
                var best = 0
                var bestDistance = Double.greatestFiniteMagnitude
                for (c, center) in centers.enumerated() {
                    let d = sample.color.distance(to: center)
                    if d < bestDistance { bestDistance = d; best = c }
                }
                assignment[i] = best
            }
            var sums = [(r: Double, g: Double, b: Double, n: Int)](repeating: (0, 0, 0, 0), count: k)
            for (i, sample) in samples.enumerated() {
                let c = assignment[i]
                sums[c].r += sample.color.r
                sums[c].g += sample.color.g
                sums[c].b += sample.color.b
                sums[c].n += 1
            }
            for c in 0..<k where sums[c].n > 0 {
                let n = Double(sums[c].n)
                centers[c] = RGB(sums[c].r / n, sums[c].g / n, sums[c].b / n)
            }
        }
        var counts = [Int](repeating: 0, count: k)
        var heights = [Double](repeating: 0, count: k)
        for (i, sample) in samples.enumerated() {
            counts[assignment[i]] += 1
            heights[assignment[i]] += sample.y
        }
        let total = Double(samples.count)
        var result: [Swatch] = []
        for c in 0..<k where counts[c] > 0 {
            let swatch = Swatch(color: centers[c], share: Double(counts[c]) / total, height: heights[c] / Double(counts[c]))
            // ほとんど同じ色は 1 つにまとめる
            if let same = result.firstIndex(where: { $0.color.distance(to: swatch.color) < 0.0009 }) {
                let a = result[same]
                let share = a.share + swatch.share
                result[same] = Swatch(color: a.color.mixed(with: swatch.color, swatch.share / share), share: share,
                                      height: (a.height * a.share + swatch.height * swatch.share) / share)
            } else {
                result.append(swatch)
            }
        }
        // 写真の上にある色から順に（空の見た目のとおりに帯を並べる）
        return result.sorted { $0.height < $1.height }
    }

    static func luminance(_ c: RGB) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
}
