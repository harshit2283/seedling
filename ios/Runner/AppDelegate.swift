import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let privacyOverlayTag = 0x53EED

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register ML Text Analyzer plugin for on-device NLP
    MLTextAnalyzerPlugin.register(with: self.registrar(forPlugin: "MLTextAnalyzerPlugin")!)

    // Register Speech Transcription plugin for on-device voice transcription
    SpeechTranscriptionPlugin.register(with: self.registrar(forPlugin: "SpeechTranscriptionPlugin")!)

    // Register CloudKit Sync plugin for iCloud private database sync
    CloudKitSyncPlugin.register(with: self.registrar(forPlugin: "CloudKitSyncPlugin")!)

    // Apply iOS data-protection classes to stored media files.
    MediaFileProtectionPlugin.register(with: self.registrar(forPlugin: "MediaFileProtectionPlugin")!)

    // Register App Shortcuts for Siri
    if #available(iOS 16.0, *) {
      SeedlingShortcuts.updateAppShortcutParameters()
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func appWillResignActive() {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap(\.windows)
      .first(where: { $0.isKeyWindow }) else {
      return
    }

    if window.viewWithTag(privacyOverlayTag) != nil {
      return
    }

    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.tag = privacyOverlayTag
    blurView.frame = window.bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blurView)
  }

  @objc private func appDidBecomeActive() {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap(\.windows)
      .first(where: { $0.isKeyWindow }) else {
      return
    }
    window.viewWithTag(privacyOverlayTag)?.removeFromSuperview()
  }
}
