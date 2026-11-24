import Flutter
import PassKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "Studio3AddPassButton") {
      registrar.register(
        AddPassButtonFactory(messenger: registrar.messenger()),
        withId: AddPassButtonFactory.viewType
      )
    }
  }
}

/// Apple's own "Add to Apple Wallet" button (PKAddPassButton), shown in Flutter as a platform
/// view. iOS draws it, so it is always the official badge (Apple's Wallet guidelines), in the
/// phone's language. A tap is sent to Dart on `studio3/add_pass_button_<view id>` ("tap"), and
/// the Dart side does the adding, as before.
final class AddPassButtonFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "studio3/add_pass_button"
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AddPassButtonView(frame: frame, viewId: viewId, messenger: messenger)
  }
}

final class AddPassButtonView: NSObject, FlutterPlatformView {
  private let button: PKAddPassButton
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    button = PKAddPassButton(addPassButtonStyle: .black)
    button.frame = frame
    channel = FlutterMethodChannel(name: "\(AddPassButtonFactory.viewType)_\(viewId)", binaryMessenger: messenger)
    super.init()
    button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
  }

  func view() -> UIView { button }

  @objc private func tapped() {
    channel.invokeMethod("tap", arguments: nil)
  }
}
