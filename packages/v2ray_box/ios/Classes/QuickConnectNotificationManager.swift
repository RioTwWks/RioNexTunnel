import Foundation
import UserNotifications

/// Disconnected-state notification with a Connect action (Hiddify / v2RayTun style).
final class QuickConnectNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = QuickConnectNotificationManager()

    private let notificationId = "v2ray_box_quick_connect"
    private let categoryId = "V2RAY_BOX_QUICK_CONNECT"
    private let connectActionId = "QUICK_CONNECT_ACTION"

    private var connectButtonText = "Connect"
    private var onConnect: (() -> Void)?

    private override init() {
        super.init()
    }

    func configure(connectButtonText: String) {
        self.connectButtonText = connectButtonText.isEmpty ? "Connect" : connectButtonText
        registerCategory()
    }

    func setConnectHandler(_ handler: @escaping () -> Void) {
        onConnect = handler
    }

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            default:
                completion(false)
            }
        }
    }

    func show(profileName: String, statusText: String) {
        requestAuthorizationIfNeeded { [weak self] granted in
            guard let self, granted else { return }
            self.postNotification(profileName: profileName, statusText: statusText)
        }
    }

    func dismiss() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [notificationId]
        )
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationId]
        )
    }

    func consumePendingLaunch() -> Bool {
        let key = "v2ray_box_pending_quick_connect"
        let pending = UserDefaults.standard.bool(forKey: key)
        if pending {
            UserDefaults.standard.set(false, forKey: key)
        }
        return pending
    }

    private func registerCategory() {
        let connect = UNNotificationAction(
            identifier: connectActionId,
            title: connectButtonText,
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [connect],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

    private func postNotification(profileName: String, statusText: String) {
        let content = UNMutableNotificationContent()
        content.title = profileName.isEmpty ? "RioNexTunnel" : profileName
        let body = statusText.isEmpty ? "Tap Connect to start VPN" : statusText
        if !profileName.isEmpty && profileName != content.title {
            content.subtitle = profileName
        }
        content.body = body
        content.categoryIdentifier = categoryId
        content.threadIdentifier = notificationId

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func dispatchConnect() {
        UserDefaults.standard.set(true, forKey: "v2ray_box_pending_quick_connect")
        DispatchQueue.main.async { [weak self] in
            self?.onConnect?()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == notificationId {
            if response.actionIdentifier == connectActionId ||
                response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                dispatchConnect()
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == notificationId {
            completionHandler([.banner, .list])
            return
        }
        completionHandler([])
    }
}
