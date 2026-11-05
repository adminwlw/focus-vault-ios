import SwiftUI
import UIKit

// Cover the window, including full-screen presentations and sheets, before iOS takes its snapshot.
struct PrivacyScreen: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.host = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var host: UIView?
        private var shield: UIView?

        override init() {
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(cover), name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(uncover), name: UIApplication.didBecomeActiveNotification, object: nil)
        }

        @objc private func cover() {
            guard shield == nil, let window = host?.window else { return }
            let view = UIView(frame: window.bounds)
            view.backgroundColor = .systemBackground
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            let icon = UIImageView(image: UIImage(systemName: "timer"))
            icon.tintColor = .secondaryLabel
            icon.frame = CGRect(x: (view.bounds.width - 44) / 2, y: (view.bounds.height - 44) / 2, width: 44, height: 44)
            icon.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            view.addSubview(icon)
            window.addSubview(view)
            shield = view
        }

        @objc private func uncover() {
            shield?.removeFromSuperview()
            shield = nil
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            shield?.removeFromSuperview()
        }
    }
}
