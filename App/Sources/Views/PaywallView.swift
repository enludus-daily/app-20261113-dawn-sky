import StoreKit
import SwiftUI

/// 課金の画面：価値を感じた直後（3 回目の朝を置いた・鍵のあるページやポスターを押した）にだけ出す。
/// 値段・購入・復元は下に固定し、スクロールしなくても見える
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason
    @State private var buying = false
    @State private var message: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(headline, color: Tone.glowDeep)
                        Text("朝を、1 年ぶんの絵に")
                            .font(Typo.serif(28))
                            .kerning(-0.8)
                            .foregroundStyle(Tone.ink)
                        Text("あさやけ図鑑 Pro は 1 回だけの買い切りです。サブスクではありません。")
                            .font(.system(size: 13))
                            .foregroundStyle(Tone.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    preview
                    VStack(spacing: 0) {
                        Feature(systemName: "sparkles", title: "めずらしい空 18 ページ", detail: "燃える空・星の残る空・地平の光・夏至や冬至の朝・三十日目の朝など。見つけた空を図鑑に残せます。")
                        Feature(systemName: "circle.dashed", title: "1 年のポスター", detail: "1 年の輪と、最近 30 朝の帯を、きれいな 1 枚に書き出せます。")
                        Feature(systemName: "chart.bar", title: "くわしい振り返り", detail: "この 30 日の平均の起きた時刻、曜日ごとの強さ。")
                        Feature(systemName: "moon.zzz", title: "休む日", detail: "体調の悪い日や旅行の日に。続けた朝を途切れさせません。", last: true)
                    }
                    .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Tone.sheet))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Tone.hair, lineWidth: 1))
                    Text("空を撮る・今月のパレット・1 年の輪・図鑑の 30 ページ・今月のパレットの共有は、ずっと無料です。")
                        .font(.system(size: 12))
                        .foregroundStyle(Tone.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: Space.readable)
                .frame(maxWidth: .infinity)
            }
            .background(Tone.ground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    buyArea
                    HStack(spacing: 16) {
                        Button("購入を復元") {
                            Task {
                                await model.purchases.restore()
                                message = model.isPro ? "Pro を復元しました" : "復元できる購入が見つかりませんでした"
                            }
                        }
                        .accessibilityIdentifier("main.restore")
                        Link(destination: URL(string: "https://github.com/enludus-daily/app-20261113-dawn-sky/blob/main/PRIVACY.md")!) {
                            Text("プライバシーポリシー")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Tone.dawnDeep)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: Space.readable)
                .frame(maxWidth: .infinity)
                .background(
                    Tone.ground
                        .overlay(alignment: .top) { Rectangle().fill(Tone.hair).frame(height: 1) }
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(Tone.ink) }
                        .accessibilityLabel(Text("閉じる"))
                }
            }
        }
    }

    private var headline: LocalizedStringKey {
        switch reason {
        case .firstMornings: "3 つの朝が、パレットに入りました"
        case .rarePage: "めずらしい空を、図鑑に残す"
        case .poster: "1 年の輪を、ポスターに"
        case .rest: "休む日をつくる"
        case .stats: "朝のくせを、振り返る"
        case .settings: "あさやけ図鑑 Pro"
        }
    }

    /// Pro で増えるものの見本（めずらしい空のカードと、1 年の輪）
    private var preview: some View {
        HStack(spacing: 12) {
            ForEach(["fire-sky", "horizon-glow", "lingering-stars"], id: \.self) { id in
                if let page = SkyCatalog.page(id) {
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                            .fill(skyGradient(colors: page.colors))
                            .aspectRatio(3 / 4, contentMode: .fit)
                        Text(verbatim: page.name)
                            .font(Typo.serif(11))
                            .foregroundStyle(Tone.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        RarityDots(level: page.rarity)
                    }
                }
            }
            YearRing(days: model.paletteJournal.yearDays(year: model.year, calendar: model.calendar), lineWidthRatio: 0.36)
                .frame(maxWidth: .infinity)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var buyArea: some View {
        if model.isPro {
            Label("Pro をお使いいただいています", systemImage: "checkmark.seal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Tone.dawnDeep)
                .frame(maxWidth: .infinity, minHeight: 52)
        } else if let product = model.purchases.products.first {
            VStack(spacing: 6) {
                Button {
                    buying = true
                    Task {
                        let outcome = await model.purchases.purchase(product)
                        buying = false
                        switch outcome {
                        case .purchased: message = "ありがとうございます。Pro がひらきました"
                        case .pending: message = "承認を待っています"
                        case .failed: message = "購入できませんでした。時間をおいて、もう一度お試しください"
                        case .cancelled: break
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if buying { ProgressView().tint(.white) }
                        Text(verbatim: tr("\(product.displayPrice) で Pro にする（買い切り）", "Get Pro for \(product.displayPrice) (one-time)"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Tone.dawnDeep))
                }
                .buttonStyle(PressStyle(scale: 0.97))
                .disabled(buying)
                .accessibilityIdentifier("main.buy")
                if let message {
                    Text(message).font(Typo.small).foregroundStyle(Tone.mute)
                } else {
                    Text("ファミリー共有に対応しています").font(Typo.caption).foregroundStyle(Tone.mute)
                }
            }
        } else if model.purchases.loadState == .loading || model.purchases.loadState == .idle {
            ProgressView().frame(maxWidth: .infinity, minHeight: 52)
        } else {
            VStack(spacing: 6) {
                Text("いまは購入できません")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Tone.ink)
                Text("通信のよい場所で、この画面を開き直してください。")
                    .font(Typo.small)
                    .foregroundStyle(Tone.mute)
                Button("もう一度読み込む") { Task { await model.purchases.load() } }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Tone.dawnDeep)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .accessibilityIdentifier("main.buyUnavailable")
        }
    }
}

private struct Feature: View {
    let systemName: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var last = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Tone.dawnDeep)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Tone.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Tone.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Tone.hair).frame(height: 1).padding(.leading, 50) }
        }
    }
}
