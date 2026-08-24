import UserNotifications
import FirebaseMessaging

/// Firebase-compatible Notification Service Extension.
///
/// Downloads any `fcm_options.image` attachment attached to a data-only push
/// so rich-media notifications render. Falls through to the original
/// content on failure — the notification is never silently dropped.
class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttempt: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttempt = (request.content.mutableCopy() as? UNMutableNotificationContent)

    if let attempt = bestAttempt {
      Messaging.serviceExtension().populateNotificationContent(
        attempt,
        withContentHandler: contentHandler
      )
    } else {
      contentHandler(request.content)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    if let handler = contentHandler, let attempt = bestAttempt {
      handler(attempt)
    }
  }
}
