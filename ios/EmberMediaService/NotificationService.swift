import UIKit
import UserNotifications

/// Downloads the FCM image and attaches it. No Firebase in this process —
/// that path used to drop banners. Always delivers, with or without art.
final class NotificationService: UNNotificationServiceExtension {
  private var deliver: ((UNNotificationContent) -> Void)?
  private var draft: UNMutableNotificationContent?
  private var task: URLSessionDataTask?
  private var finished = false

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    deliver = contentHandler
    guard let draft = request.content.mutableCopy() as? UNMutableNotificationContent else {
      contentHandler(request.content)
      return
    }
    self.draft = draft

    guard let remote = Self.imageURL(in: request.content.userInfo) else {
      finish()
      return
    }

    let session = URLSession(configuration: {
      let config = URLSessionConfiguration.ephemeral
      config.timeoutIntervalForRequest = 3.5
      config.timeoutIntervalForResource = 3.5
      config.waitsForConnectivity = false
      return config
    }())

    task = session.dataTask(with: remote) { [weak self] data, response, _ in
      defer { self?.finish() }
      guard let self, let data, !data.isEmpty else { return }
      let mime = (response as? HTTPURLResponse)?.mimeType
      guard let file = Self.stage(data, mime: mime, fallback: remote.pathExtension) else { return }
      if let attachment = try? UNNotificationAttachment(
        identifier: "cv-media",
        url: file,
        options: [UNNotificationAttachmentOptionsTypeHintKey: Self.hint(for: file.pathExtension)]
      ) {
        draft.attachments = [attachment]
      }
    }
    task?.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    task?.cancel()
    finish()
  }

  private func finish() {
    guard !finished else { return }
    finished = true
    task?.cancel()
    let handler = deliver
    deliver = nil
    handler?(draft ?? UNNotificationContent())
  }

  private static func imageURL(in payload: [AnyHashable: Any]) -> URL? {
    for key in [
      "fcm_options.image",
      "image",
      "image_url",
      "imageUrl",
      "picture",
      "media",
      "media_url",
      "attachment",
      "attachment-url",
      "gcm.notification.image",
    ] {
      if let url = url(from: payload[key]) { return url }
    }
    if let options = payload["fcm_options"] as? [AnyHashable: Any],
       let url = url(from: options["image"]) {
      return url
    }
    if let nested = payload["data"] as? [AnyHashable: Any], nested as NSDictionary != payload as NSDictionary {
      return imageURL(in: nested)
    }
    if let nested = payload["payload"] as? [AnyHashable: Any] {
      return imageURL(in: nested)
    }
    return nil
  }

  private static func url(from raw: Any?) -> URL? {
    guard let text = raw as? String else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("http"), let parsed = URL(string: trimmed) else { return nil }
    return parsed
  }

  private static func stage(_ data: Data, mime: String?, fallback: String) -> URL? {
    var bytes = data
    var ext = normalizedExtension(mime: mime, fallback: fallback)
    if ext == "webp" || mime?.contains("webp") == true {
      guard let image = UIImage(data: data),
            let jpeg = image.jpegData(compressionQuality: 0.86) else { return nil }
      bytes = jpeg
      ext = "jpg"
    }
    let folder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let file = folder.appendingPathComponent("art.\(ext)")
      try bytes.write(to: file, options: .atomic)
      return file
    } catch {
      return nil
    }
  }

  private static func normalizedExtension(mime: String?, fallback: String) -> String {
    let lower = (mime ?? "").lowercased()
    if lower.contains("png") { return "png" }
    if lower.contains("gif") { return "gif" }
    if lower.contains("webp") { return "webp" }
    if lower.contains("jpeg") || lower.contains("jpg") { return "jpg" }
    switch fallback.lowercased() {
    case "png", "gif", "jpg", "jpeg", "webp":
      return fallback.lowercased() == "jpeg" ? "jpg" : fallback.lowercased()
    default:
      return "jpg"
    }
  }

  private static func hint(for ext: String) -> String {
    switch ext {
    case "png": return "public.png"
    case "gif": return "com.compuserve.gif"
    default: return "public.jpeg"
    }
  }
}
