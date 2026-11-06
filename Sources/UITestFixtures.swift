#if DEBUG
import UIKit
import AVFoundation

enum UITestFixtures {
    static func resetIfRequested() {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains("-ui-reset-state") else { return }
        if let bundle = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: bundle) }
        try? SecureStore.delete(account: "vault-auth-v1")
        try? SecureStore.delete(account: "vault-key-v1")
        try? BiometricVaultKey.disable()
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: support.appendingPathComponent("PrivateVault"))
        #endif
    }
    @MainActor
    static func seedMedia(in store: VaultStore) throws {
        guard ProcessInfo.processInfo.arguments.contains("-ui-seed-media"), store.activeItems.isEmpty else { return }
        for index in 1...2 {
            let data = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).pngData { context in
                (index == 1 ? UIColor.systemTeal : UIColor.systemIndigo).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
                let label = "UI 测试照片 \(index)" as NSString
                label.draw(at: CGPoint(x: 130, y: 210), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 40), .foregroundColor: UIColor.white
                ])
            }
            try store.importData(data, kind: .photo, originalName: "UI测试照片\(index).png")
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-seed-video") {
            let video = try makeVideo()
            defer { try? FileManager.default.removeItem(at: video) }
            try store.importData(Data(contentsOf: video), kind: .video, originalName: "UI测试视频.mov")
        }
    }

    private static func makeVideo() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                                                                        AVVideoWidthKey: 320, AVVideoHeightKey: 240])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                                         kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
        writer.add(input)
        guard writer.startWriting() else { throw ValidationError("测试视频无法创建。") }
        writer.startSession(atSourceTime: .zero)
        let deadline = Date().addingTimeInterval(10)
        for index in 0..<12 {
            while !input.isReadyForMoreMediaData {
                guard Date() < deadline else { writer.cancelWriting(); throw ValidationError("测试视频超时。") }
                Thread.sleep(forTimeInterval: 0.005)
            }
            var pixel: CVPixelBuffer?
            CVPixelBufferCreate(nil, 320, 240, kCVPixelFormatType_32ARGB, nil, &pixel)
            guard let pixel else { throw ValidationError("测试视频像素创建失败。") }
            CVPixelBufferLockBaseAddress(pixel, [])
            if let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: 320, height: 240,
                                       bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
                                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
                context.setFillColor(UIColor.systemTeal.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
            }
            CVPixelBufferUnlockBaseAddress(pixel, [])
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(index), timescale: 6)) else {
                throw ValidationError("测试视频帧写入失败。")
            }
        }
        input.markAsFinished()
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        guard finished.wait(timeout: .now() + 10) == .success, writer.status == .completed else {
            throw ValidationError("测试视频写入失败。")
        }
        return url
    }
}
#endif
