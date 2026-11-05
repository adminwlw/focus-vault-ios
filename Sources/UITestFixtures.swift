#if DEBUG
import UIKit

enum UITestFixtures {
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
    }
}
#endif
