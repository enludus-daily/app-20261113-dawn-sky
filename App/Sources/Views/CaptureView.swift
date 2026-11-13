import AVFoundation
import SwiftUI
import UIKit

/// 撮る場面：カメラ → 発表。カメラが使えない端末（シミュレータなど）では見本の空で試す
struct CaptureFlowView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.captureStage {
        case .choosing:
            CaptureChooser()
        case .reveal(let reveal):
            RevealView(reveal: reveal)
        }
    }
}

struct CaptureChooser: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private var denied: Bool {
        if model.cameraDeniedOverride { return true }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .denied || status == .restricted
    }

    var body: some View {
        if cameraAvailable && !denied && !model.cameraDeniedOverride {
            CameraPicker { image in
                model.capture(photo: image)
            } onCancel: {
                model.cover = nil
            }
            .ignoresSafeArea()
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            Tone.ground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button {
                            model.cover = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(Tone.ink)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text("閉じる"))
                        Spacer()
                    }
                    if denied {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("カメラの許可がありません", color: Tone.glowDeep)
                            Text("空を撮るには、カメラをオンに")
                                .font(Typo.serif(24))
                                .foregroundStyle(Tone.ink)
                            Text("設定 › あさやけ図鑑 › カメラ をオンにしてください。写真は色を読むためだけに使い、この iPhone の外には送りません。")
                                .font(Typo.body)
                                .foregroundStyle(Tone.mute)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        DeepButton(title: "設定を開く", systemImage: "gearshape") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("この端末ではカメラが使えません")
                            Text("見本の空で試す")
                                .font(Typo.serif(24))
                                .foregroundStyle(Tone.ink)
                            Text("空の色が図鑑に入るまでを、見本の写真で試せます。見本は記録には入りません。")
                                .font(Typo.body)
                                .foregroundStyle(Tone.mute)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(SampleSky.allCases) { sky in
                            Button {
                                model.capture(sample: sky)
                            } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                        .fill(skyGradient(colors: sky.stops))
                                        .aspectRatio(3 / 4, contentMode: .fit)
                                    Text(verbatim: sky.name)
                                        .font(Typo.small)
                                        .foregroundStyle(Tone.ink)
                                }
                            }
                            .buttonStyle(PressStyle(scale: 0.95))
                            .accessibilityIdentifier(sky == .dawnGlow ? "main.sample" : "sample.\(sky.rawValue)")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: Space.readable)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// UIImagePickerController（カメラ）。写真は色を読み、設定に従って小さく縮めてアプリの中だけに残す
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, onCancel: onCancel) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onImage(image) } else { onCancel() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}

/// 発表：写真 → 色が 3 つに分かれる → 判定 → 図鑑のページがめくれる → 空のメモ
struct RevealView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let reveal: Reveal
    @State private var step = 0

    private var record: DayRecord { reveal.record }
    private var page: SkyPage { SkyCatalog.page(record.skyID) ?? SkyCatalog.skies[SkyCatalog.skies.count - 1] }
    private var moment: SkyPage? { record.momentID.flatMap { SkyCatalog.page($0) } }
    private var isNew: Bool { reveal.newPages.contains(record.skyID) }

    var body: some View {
        ZStack {
            Tone.ground.ignoresSafeArea()
            skyGradient(record.swatches)
                .opacity(step >= 1 ? 0.28 : 0)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text(verbatim: judgementLine)
                        .font(Typo.label)
                        .kerning(0.8)
                        .foregroundStyle(record.result == .late ? Tone.mute : Tone.glowDeep)
                        .padding(.top, 20)
                    photoAndSwatches
                    pageCard
                    if let moment {
                        momentRow(moment)
                            .opacity(step >= 4 ? 1 : 0)
                    }
                    resultLine
                        .opacity(step >= 2 ? 1 : 0)
                    note
                        .opacity(step >= 4 ? 1 : 0)
                    if reveal.isTryOut {
                        Text("見本の空なので、記録には入りません。")
                            .font(Typo.small)
                            .foregroundStyle(Tone.mute)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: Space.readable)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DeepButton(title: reveal.isTryOut ? "閉じる" : "パレットに置く", systemImage: reveal.isTryOut ? nil : "square.grid.3x3.bottomright.filled") {
                model.place()
            }
            .accessibilityIdentifier("main.place")
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: Space.readable)
            .frame(maxWidth: .infinity)
            .background(Tone.ground.opacity(0.92).ignoresSafeArea(edges: .bottom))
        }
        .task {
            if reduceMotion || Launch.isStill {
                step = 4
                return
            }
            for i in 1...4 {
                try? await Task.sleep(for: .milliseconds(i == 3 ? 900 : 600))
                withAnimation(i == 3 ? .spring(response: 0.42, dampingFraction: 0.72) : .easeOut(duration: 0.35)) { step = i }
            }
        }
    }

    private var judgementLine: String {
        let time = record.capturedAt.clock
        switch reveal.judgement {
        case .early(let m): return tr("\(time) ・ 起きる時刻の \(m) 分前", "\(time) · \(m) min before wake time")
        case .caught(let m): return m == 0 ? tr("\(time) ・ 起きる時刻ちょうど", "\(time) · right at wake time")
                                             : tr("\(time) ・ 起きて \(m) 分、窓の中", "\(time) · \(m) min in, inside the window")
        case .late(let m): return record.result == .trial ? tr("\(time) ・ 試しの 1 枚", "\(time) · a trial shot")
                                                          : tr("\(time) ・ 窓から \(m - WakeWindow.windowMinutes) 分おくれ", "\(time) · \(m - WakeWindow.windowMinutes) min past the window")
        case .tooEarly, .closed: return tr("\(time) ・ 試しの 1 枚", "\(time) · a trial shot")
        }
    }

    private var photoAndSwatches: some View {
        HStack(alignment: .center, spacing: 18) {
            Group {
                if let image = model.revealImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    skyGradient(record.swatches)
                }
            }
            .frame(width: 132, height: 176)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Color.white.opacity(0.7), lineWidth: 1))
            .shadow(color: Tone.shadowLift, radius: 10, y: 6)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(record.swatches.enumerated()), id: \.offset) { i, swatch in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(swatch.color))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: hex(swatch.color))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Tone.ink)
                            Text(verbatim: "\(Int((swatch.share * 100).rounded()))%")
                                .font(Typo.caption)
                                .foregroundStyle(Tone.mute)
                        }
                    }
                    .offset(x: step >= 1 || reduceMotion ? 0 : -40)
                    .opacity(step >= 1 ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8).delay(Double(i) * 0.055), value: step)
                }
                SkyTile(state: .record(record))
                    .frame(width: 44, height: 44)
                    .scaleEffect(step >= 2 || reduceMotion ? 1 : 0.6)
                    .opacity(step >= 2 ? 1 : 0)
                    .padding(.top, 4)
            }
            .frame(minWidth: 120, alignment: .leading)
        }
    }

    private var pageCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .stroke(Tone.missing, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .overlay(Text(verbatim: "？").font(Typo.serif(28)).foregroundStyle(Tone.mute))
                .opacity(step >= 3 ? 0 : 1)
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .fill(skyGradient(colors: page.colors))
                    .frame(width: 66, height: 88)
                    .overlay {
                        if !model.isUnlocked(page) {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Tone.ground.opacity(0.5))
                                Image(systemName: "lock").font(.system(size: 13)).foregroundStyle(Tone.dawnDeep)
                            }
                        }
                    }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        RarityDots(level: page.rarity)
                        Text(verbatim: page.rarityName)
                            .font(Typo.caption)
                            .foregroundStyle(Tone.rarity(page.rarity))
                        if isNew {
                            Text("新しいページ")
                                .font(Typo.label)
                                .foregroundStyle(Tone.glowDeep)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Tone.glowSoft))
                        }
                    }
                    Text(verbatim: page.name)
                        .font(Typo.serif(24))
                        .kerning(-0.5)
                        .foregroundStyle(Tone.ink)
                    Text(verbatim: page.note)
                        .font(Typo.small)
                        .foregroundStyle(Tone.mute)
                        .fixedSize(horizontal: false, vertical: true)
                    if !model.isUnlocked(page) {
                        Text("めずらしい空は Pro の図鑑に残せます")
                            .font(Typo.caption)
                            .foregroundStyle(Tone.dawnDeep)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).fill(Tone.sheet))
            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Tone.hair, lineWidth: 1))
            .shadow(color: Tone.shadow, radius: 12, y: 5)
            .rotation3DEffect(.degrees(step >= 3 || reduceMotion ? 0 : -90), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(step == 3 && !reduceMotion && !Launch.isStill ? 1.03 : 1)
            .opacity(step >= 3 ? 1 : 0)
        }
        .frame(minHeight: 120)
    }

    private func momentRow(_ moment: SkyPage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.horizon")
                .font(.system(size: 14))
                .foregroundStyle(Tone.glowDeep)
            Text(verbatim: tr("朝のページ「\(moment.name)」", "Morning page: \(moment.name)"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Tone.ink)
            if reveal.newPages.contains(moment.id) {
                Text("新しい").font(Typo.label).foregroundStyle(Tone.glowDeep)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var resultLine: some View {
        switch record.result {
        case .early, .caught:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("続けた朝")
                    .font(Typo.small)
                    .foregroundStyle(Tone.mute)
                Text(verbatim: "\(reveal.streak)")
                    .font(Typo.serif(30))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Tone.ink)
                Spacer()
            }
        case .late:
            Text(verbatim: tr("窓の外だったので、マスは欠けて残ります。明日の窓は \(model.schedule.target(on: model.now.addingTimeInterval(86_400), calendar: model.calendar).clock) から 15 分。",
                              "Outside your window, so the square stays chipped. Tomorrow's window opens at \(model.schedule.target(on: model.now.addingTimeInterval(86_400), calendar: model.calendar).clock) for 15 minutes."))
                .font(Typo.small)
                .foregroundStyle(Tone.mute)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        case .trial:
            Text("最初の 1 枚は試しです。明日の朝、起きて 15 分以内に撮ると、続けた朝が始まります。")
                .font(Typo.small)
                .foregroundStyle(Tone.mute)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("空のメモ")
            Text(verbatim: SkyNotes.note(for: record.day).text)
                .font(Typo.serif(15))
                .foregroundStyle(Tone.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .overlay(alignment: .top) { Rectangle().fill(Tone.hair).frame(height: 1).offset(y: -6) }
    }

    private func hex(_ c: RGB) -> String {
        String(format: "#%02X%02X%02X", Int(c.r * 255), Int(c.g * 255), Int(c.b * 255))
    }
}
