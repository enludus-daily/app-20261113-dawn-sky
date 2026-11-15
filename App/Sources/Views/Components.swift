import SwiftUI

// 題材の現物を部品にする：空の色の「マス」、地平線と日の出の弧の「窓」、1 年の「輪」、写真集の「図版」

/// 角の丸みを大きさに合わせたマス
struct TileShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: max(3, rect.width * 0.24), style: .continuous)
    }
}

/// 右上が欠けたマス（寝坊した朝）
struct ChippedTileShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = max(3, rect.width * 0.24)
        let cut = rect.width * 0.38
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// 空の色を上から下へ並べたグラデーション（空の見た目どおり。グラデーションはここ＝空にだけ使う）
func skyGradient(_ swatches: [Swatch]) -> LinearGradient {
    guard !swatches.isEmpty else {
        return LinearGradient(colors: [Tone.hair], startPoint: .top, endPoint: .bottom)
    }
    if swatches.count == 1 {
        return LinearGradient(colors: [Color(swatches[0].color), Color(swatches[0].color)], startPoint: .top, endPoint: .bottom)
    }
    var stops: [Gradient.Stop] = []
    var acc = 0.0
    for s in swatches {
        stops.append(Gradient.Stop(color: Color(s.color), location: acc + s.share / 2))
        acc += s.share
    }
    return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
}

func skyGradient(colors: [RGB]) -> LinearGradient {
    LinearGradient(colors: colors.map { Color($0) }, startPoint: .top, endPoint: .bottom)
}

/// パレットの 1 マス
struct SkyTile: View {
    let state: MonthCell.State

    var body: some View {
        ZStack {
            switch state {
            case .blank:
                Color.clear
            case .future:
                Circle().fill(Tone.hair).frame(width: 3, height: 3)
            case .today:
                TileShape().stroke(Tone.glow, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
            case .missed:
                TileShape().stroke(Tone.missing, style: StrokeStyle(lineWidth: 0.8, dash: [2, 2.5]))
            case .rest:
                TileShape().fill(Tone.dawnPale)
                Image(systemName: "moon.zzz").font(.system(size: 9)).foregroundStyle(Tone.mute)
            case .record(let record):
                if record.result == .late {
                    ChippedTileShape().fill(skyGradient(record.swatches)).opacity(0.5)
                    ChippedTileShape().stroke(Tone.missing, style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
                } else {
                    TileShape().fill(skyGradient(record.swatches))
                    TileShape().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    if record.result == .early {
                        // 早起きの印：小さな日の光
                        GeometryReader { geo in
                            Circle().fill(Color.white.opacity(0.85))
                                .frame(width: max(3, geo.size.width * 0.14), height: max(3, geo.size.width * 0.14))
                                .position(x: geo.size.width * 0.78, y: geo.size.height * 0.78)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibility))
    }

    private var accessibility: String {
        switch state {
        case .blank: ""
        case .future: tr("これからの日", "Upcoming")
        case .today: tr("今日、まだ", "Today, not yet")
        case .missed: tr("撮らなかった朝", "Missed morning")
        case .rest: tr("休む日", "Rest day")
        case .record(let r):
            switch r.result {
            case .late: tr("寝坊した朝、欠けたマス", "Slept in — chipped square")
            case .early: tr("早起きの朝", "Early morning")
            case .trial: tr("試しの空", "Trial sky")
            case .caught: tr("窓の中で撮った朝", "Caught in the window")
            }
        }
    }
}

/// 曜日の見出し（日曜はじまり）
struct WeekdayHeader: View {
    var body: some View {
        let symbols = Self.symbols
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(verbatim: symbols[i])
                    .font(Typo.caption)
                    .foregroundStyle(Tone.mute)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    static var symbols: [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Lang.locale
        return cal.veryShortWeekdaySymbols
    }
}

/// 月のパレット（7 列のマス目）
struct PaletteGrid: View {
    let cells: [MonthCell]
    var spacing: CGFloat = 6
    var onTap: ((DayRecord) -> Void)?

    var body: some View {
        VStack(spacing: spacing) {
            WeekdayHeader()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7), spacing: spacing) {
                ForEach(cells) { cell in
                    if case .record(let record) = cell.state, let onTap {
                        Button { onTap(record) } label: { SkyTile(state: cell.state) }
                            .buttonStyle(PressStyle(scale: 0.9))
                    } else {
                        SkyTile(state: cell.state)
                    }
                }
            }
        }
    }
}

/// 窓：地平線と、日がのぼる弧。弧の右の 15 分が窓（桃色）。太陽は今の時刻の位置
struct WindowDial: View {
    let now: Date
    let target: Date
    let phase: WakeWindow.Phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 弧の左端（起きる時刻の 60 分前）から右端（15 分後）まで
    private var progress: Double {
        let start = target.addingTimeInterval(-60 * 60)
        return now.timeIntervalSince(start) / (75 * 60)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizon = h * 0.86
            let radius = min(w * 0.42, h * 0.78)
            let center = CGPoint(x: w / 2, y: horizon)
            let windowStart = 60.0 / 75.0
            ZStack {
                // 地平線
                Path { p in
                    p.move(to: CGPoint(x: 0, y: horizon))
                    p.addLine(to: CGPoint(x: w, y: horizon))
                }
                .stroke(Tone.hair, lineWidth: 1)
                // 弧（起きる前）
                arc(center: center, radius: radius, from: 0, to: windowStart)
                    .stroke(Tone.dawnLine, style: StrokeStyle(lineWidth: 0.8, dash: [1.5, 4]))
                // 弧（窓の 15 分）
                arc(center: center, radius: radius, from: windowStart, to: 1)
                    .stroke(Tone.glow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                // 窓の始まりと終わりの印
                tick(center: center, radius: radius, at: windowStart)
                tick(center: center, radius: radius, at: 1)
                // 太陽
                sun(center: center, radius: radius, horizon: horizon)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tr("起きる時刻から 15 分の窓", "Your 15-minute window after wake time")))
    }

    private func point(center: CGPoint, radius: CGFloat, at t: Double) -> CGPoint {
        let angle = Double.pi * (1 - t)
        return CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
    }

    private func arc(center: CGPoint, radius: CGFloat, from a: Double, to b: Double) -> Path {
        Path { p in
            let steps = 60
            for i in 0...steps {
                let t = a + (b - a) * Double(i) / Double(steps)
                let pt = point(center: center, radius: radius, at: t)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }

    private func tick(center: CGPoint, radius: CGFloat, at t: Double) -> some View {
        let inner = point(center: center, radius: radius - 6, at: t)
        let outer = point(center: center, radius: radius + 6, at: t)
        return Path { p in
            p.move(to: inner)
            p.addLine(to: outer)
        }
        .stroke(Tone.glowDeep.opacity(0.6), lineWidth: 1)
    }

    @ViewBuilder
    private func sun(center: CGPoint, radius: CGFloat, horizon: CGFloat) -> some View {
        let done: Bool = { if case .done = phase { return true } else { return false } }()
        let t = min(max(progress, 0), 1)
        let below = progress < 0
        let p = below ? CGPoint(x: center.x - radius, y: horizon + 6) : point(center: center, radius: radius, at: t)
        ZStack {
            Circle().fill(RadialGradient(colors: [Tone.glow.opacity(0.45), .clear], center: .center, startRadius: 8, endRadius: 32)).frame(width: 64, height: 64)
            Circle().fill(Tone.glowSoft).frame(width: 40, height: 40)
            Circle().fill(done ? Color.white.opacity(0.9) : Tone.glow).frame(width: 22, height: 22)
            Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.2).frame(width: 22, height: 22)
        }
        .position(p)
        .mask(alignment: .top) {
            // 地平線より下は隠す（夜は太陽が沈んで見える）
            Rectangle().frame(height: horizon)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: t)
    }
}

/// 1 年の輪：1 日 1 本の細いくさび。窓の中で撮った朝は空の色、寝坊は薄く、撮らなかった日は線の色
struct YearRing: View {
    let days: [DayRecord?]
    var lineWidthRatio: CGFloat = 0.3

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = side / 2
            let inner = outer * (1 - lineWidthRatio)
            let count = max(days.count, 1)
            let step = 2 * Double.pi / Double(count)
            for (i, record) in days.enumerated() {
                let a0 = Double(i) * step - Double.pi / 2
                let a1 = a0 + step * 0.82
                var path = Path()
                path.addArc(center: center, radius: outer, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                path.addArc(center: center, radius: inner, startAngle: .radians(a1), endAngle: .radians(a0), clockwise: true)
                path.closeSubpath()
                if let record {
                    let color = Color(record.swatches.first?.color ?? RGB(0.8, 0.85, 0.9))
                    context.fill(path, with: .color(record.result == .late ? color.opacity(0.35) : color))
                } else {
                    context.fill(path, with: .color(Tone.hair.opacity(0.7)))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tr("1 年の輪：\(days.compactMap { $0 }.count) 日ぶんの空", "Year ring: \(days.compactMap { $0 }.count) days of sky")))
    }
}

/// めずらしさの点（1〜4）
struct RarityDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...4, id: \.self) { i in
                Circle()
                    .fill(i <= level ? Tone.rarity(level) : Tone.hair)
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 図鑑の 1 枚：枠のない写真集の図版（空の色の版）。下に番号と名前を小さく添える
struct PageCard: View {
    let page: SkyPage
    let found: Bool
    let unlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if found {
                    PlateShape().fill(skyGradient(colors: page.colors))
                    // 図版の光沢：上からわずかに白
                    PlateShape().fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center))
                    if !unlocked {
                        PlateShape().fill(Color.black.opacity(0.35))
                        Image(systemName: "lock").font(.system(size: 13, weight: .light)).foregroundStyle(Tone.ink)
                    }
                } else {
                    PlateShape().fill(Tone.sheet)
                    PlateShape().stroke(Tone.missing, style: StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
                    Image(systemName: unlocked ? "questionmark" : "lock")
                        .font(.system(size: 13, weight: .ultraLight))
                        .foregroundStyle(Tone.mute)
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .shadow(color: found ? Tone.shadow : .clear, radius: 10, y: 6)
            Text(verbatim: page.plateNumber)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .kerning(1.2)
                .foregroundStyle(Tone.mute)
            Text(verbatim: found ? page.name : "？")
                .font(Typo.display(12.5, .regular))
                .foregroundStyle(found ? Tone.ink : Tone.mute)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            RarityDots(level: page.rarity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(found ? "\(page.name)、\(page.rarityName)" : tr("まだ見つけていない空", "Not found yet")))
    }
}

/// 写真集の図版の形：角はほとんど丸めない（印画紙の角）
struct PlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: 3, style: .continuous)
    }
}

extension SkyPage {
    /// 図版の番号（No.07）
    var plateNumber: String {
        let i = (SkyCatalog.all.firstIndex { $0.id == id } ?? 0) + 1
        return String(format: "No.%02d", i)
    }
}

extension Date {
    /// 「6:30」の形（端末の 12/24 時間表示に合わせる）
    var clock: String { formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Lang.locale)) }
}

extension Int {
    /// 0 時からの分を「6:30」の形に
    var clockFromMinutes: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: self / 60, minute: self % 60)) ?? Date()
        return date.clock
    }
}
