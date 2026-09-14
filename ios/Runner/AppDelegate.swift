import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Push (FCM): firebase_messaging registers for remote notifications and
    // forwards the APNs token through its app-delegate proxy
    // (FirebaseAppDelegateProxyEnabled in Info.plist), so nothing is wired by
    // hand here. Firebase itself is initialised from Dart (Firebase.initializeApp)
    // and tolerates a missing GoogleService-Info.plist by disabling push.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
