import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentInteractionControllerDelegate {
  private let channelName = "com.share1.app/meta_share"
  private var documentController: UIDocumentInteractionController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    registerMetaShareChannel()
    return launched
  }

  private func registerMetaShareChannel() {
    let messenger: FlutterBinaryMessenger?
    if let controller = window?.rootViewController as? FlutterViewController {
      messenger = controller.binaryMessenger
    } else {
      messenger = self.registrar(forPlugin: "MetaShare")?.messenger()
    }
    guard let messenger else { return }
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "share" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let destination = args["destination"] as? String,
          let filePath = args["filePath"] as? String else {
      result(FlutterError(code: "invalid_args", message: "A photo and a share destination are required.", details: nil))
      return
    }
    let appId = (args["facebookAppId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let source = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: source.path) else {
      result(FlutterError(code: "invalid_file", message: "The selected photo is no longer available.", details: nil))
      return
    }

    switch destination {
    case "instagram_story":
      shareStory(
        urlScheme: "instagram-stories://share?source_application=\(appId)",
        queryScheme: "instagram-stories://share",
        backgroundKey: "com.instagram.sharedSticker.backgroundImage",
        appIdKey: nil,
        appId: appId,
        appName: "Instagram",
        fileUrl: source,
        result: result
      )
    case "facebook_story":
      shareStory(
        urlScheme: "facebook-stories://share",
        queryScheme: "facebook-stories://share",
        backgroundKey: "com.facebook.sharedSticker.backgroundImage",
        appIdKey: "com.facebook.sharedSticker.appID",
        appId: appId,
        appName: "Facebook",
        fileUrl: source,
        result: result
      )
    case "instagram_feed":
      shareInstagramFeed(fileUrl: source, result: result)
    case "facebook_feed":
      shareFacebookFeed(fileUrl: source, result: result)
    default:
      result(FlutterError(code: "invalid_args", message: "Unknown share destination.", details: nil))
    }
  }

  /// Instagram and Facebook Stories: image bytes go on the pasteboard, then the
  /// custom URL scheme opens the story composer. The Facebook App ID is required.
  private func shareStory(
    urlScheme: String,
    queryScheme: String,
    backgroundKey: String,
    appIdKey: String?,
    appId: String,
    appName: String,
    fileUrl: URL,
    result: @escaping FlutterResult
  ) {
    guard !appId.isEmpty else {
      result(FlutterError(code: "missing_app_id", message: "Add your Facebook App ID before sharing to Stories.", details: nil))
      return
    }
    guard let schemeUrl = URL(string: urlScheme), canOpen(queryScheme) else {
      result(FlutterError(code: "not_installed", message: "\(appName) is not installed.", details: nil))
      return
    }
    do {
      let data = try Data(contentsOf: fileUrl)
      guard !data.isEmpty else {
        result(FlutterError(code: "invalid_file", message: "The selected photo is empty.", details: nil))
        return
      }
      var item: [String: Any] = [backgroundKey: data]
      if let appIdKey {
        item[appIdKey] = appId
      }
      let options: [UIPasteboard.OptionsKey: Any] = [
        .expirationDate: Date().addingTimeInterval(5 * 60)
      ]
      UIPasteboard.general.setItems([item], options: options)
      UIApplication.shared.open(schemeUrl, options: [:]) { opened in
        if opened {
          result(nil)
        } else {
          result(FlutterError(code: "failed", message: "Could not open \(appName).", details: nil))
        }
      }
    } catch {
      result(FlutterError(code: "invalid_file", message: "Could not read the selected photo.", details: nil))
    }
  }

  /// Instagram Feed: a JPEG/PNG saved with the `.igo` extension and UTI
  /// `com.instagram.exclusivegram` opens Instagram's composer only.
  private func shareInstagramFeed(fileUrl: URL, result: @escaping FlutterResult) {
    guard canOpen("instagram-stories://share") || canOpen("instagram://app") else {
      result(FlutterError(code: "not_installed", message: "Instagram is not installed.", details: nil))
      return
    }
    do {
      let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("instagram-feed-\(UUID().uuidString).igo")
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.copyItem(at: fileUrl, to: destination)
      let controller = UIDocumentInteractionController(url: destination)
      controller.uti = "com.instagram.exclusivegram"
      controller.delegate = self
      documentController = controller
      guard let root = topViewController() else {
        result(FlutterError(code: "failed", message: "Could not present Instagram.", details: nil))
        return
      }
      let rect = CGRect(x: 0, y: root.view.bounds.height - 1, width: root.view.bounds.width, height: 1)
      let presented = controller.presentOpenInMenu(from: rect, in: root.view, animated: true)
      if presented {
        result(nil)
      } else {
        result(FlutterError(code: "not_installed", message: "Instagram cannot open this photo.", details: nil))
      }
    } catch {
      result(FlutterError(code: "failed", message: "Could not prepare the photo for Instagram.", details: nil))
    }
  }

  /// Facebook has no documented image-to-feed URL scheme on iOS. The share
  /// sheet is the supported way to hand the photo to Facebook's share extension.
  private func shareFacebookFeed(fileUrl: URL, result: @escaping FlutterResult) {
    guard let root = topViewController() else {
      result(FlutterError(code: "failed", message: "Could not present the share sheet.", details: nil))
      return
    }
    let controller = UIActivityViewController(activityItems: [fileUrl], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
      popover.sourceView = root.view
      popover.sourceRect = CGRect(
        x: root.view.bounds.midX,
        y: root.view.bounds.midY,
        width: 0,
        height: 0
      )
      popover.permittedArrowDirections = []
    }
    root.present(controller, animated: true)
    result(nil)
  }

  private func canOpen(_ urlString: String) -> Bool {
    guard let url = URL(string: urlString) else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? self.window
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
