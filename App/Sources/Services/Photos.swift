import UIKit

/// 写真から色を読む・小さく縮めてアプリの中に保存する。写真は端末の外に出さない
enum PixelReader {
    /// 写真の上 3/4 を空とみなし、24×32 に縮めて画素を読む
    static func samples(from image: UIImage) -> [SkySample] {
        guard let cg = normalized(image).cgImage else { return [] }
        let cols = 24, rows = 32
        var pixels = [UInt8](repeating: 0, count: cols * rows * 4)
        let skyHeight = Double(cg.height) * 0.75
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: cols, height: rows, bitsPerComponent: 8,
                                      bytesPerRow: cols * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            // 上 3/4 だけを 24×32 に引き伸ばして描く（CGContext は下が原点）
            let scale = Double(rows) / skyHeight
            let fullHeight = Double(cg.height) * scale
            ctx.draw(cg, in: CGRect(x: 0, y: Double(rows) - fullHeight, width: Double(cols), height: fullHeight))
            return true
        }
        guard drawn else { return [] }
        var out: [SkySample] = []
        out.reserveCapacity(cols * rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let i = (row * cols + col) * 4
                let color = RGB(Double(pixels[i]) / 255, Double(pixels[i + 1]) / 255, Double(pixels[i + 2]) / 255)
                out.append(SkySample(color: color, y: (Double(row) + 0.5) / Double(rows)))
            }
        }
        return out
    }

    /// 向きを直した画像
    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// 見本の空を画像にする（撮った写真の代わりに見せる）
    static func image(of sky: SampleSky, size: CGSize = CGSize(width: 300, height: 400)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let steps = 64
            for i in 0..<steps {
                let y = Double(i) / Double(steps)
                let c = sky.color(at: y / 0.75)
                UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: size.height * y, width: size.width, height: size.height / Double(steps) + 1))
            }
            // 下の 1/4 は地面（街の影）
            UIColor(red: 0.42, green: 0.46, blue: 0.52, alpha: 1).setFill()
            let ground = UIBezierPath()
            ground.move(to: CGPoint(x: 0, y: size.height * 0.82))
            let widths: [Double] = [0.12, 0.08, 0.15, 0.1, 0.18, 0.09, 0.14, 0.14]
            let heights: [Double] = [0.78, 0.74, 0.80, 0.70, 0.79, 0.76, 0.81, 0.77]
            var x = 0.0
            for (w, h) in zip(widths, heights) {
                ground.addLine(to: CGPoint(x: size.width * x, y: size.height * h))
                x += w
                ground.addLine(to: CGPoint(x: size.width * x, y: size.height * h))
            }
            ground.addLine(to: CGPoint(x: size.width, y: size.height))
            ground.addLine(to: CGPoint(x: 0, y: size.height))
            ground.close()
            ground.fill()
        }
    }
}

/// アプリの中の写真（Application Support/skies）。設定で「写真を残さない」にすると保存しない
enum PhotoStore {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("skies", isDirectory: true)
    }

    /// 長い辺 480px の JPEG にして保存し、ファイル名を返す
    static func save(_ image: UIImage, day: String) -> String? {
        let normalized = PixelReader.normalized(image)
        let longest = max(normalized.size.width, normalized.size.height)
        let scale = min(1, 480 / max(longest, 1))
        let size = CGSize(width: (normalized.size.width * scale).rounded(), height: (normalized.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = small.jpegData(compressionQuality: 0.7) else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = "\(day).jpg"
            try data.write(to: folder.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: folder.appendingPathComponent(name).path)
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: folder)
    }
}
