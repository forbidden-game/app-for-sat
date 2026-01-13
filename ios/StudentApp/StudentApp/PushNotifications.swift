import Combine
import Foundation
import StudentCore
import UIKit
import UserNotifications

extension Notification.Name {
    static let pushTokenUpdated = Notification.Name("pushTokenUpdated")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .pushTokenUpdated, object: token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(name: .pushTokenUpdated, object: nil)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }
}

@MainActor
final class PushTokenManager: ObservableObject {
    private let notificationService: SupabaseNotificationService
    private let notificationCenter: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let lastTokenKey = "pushToken.lastRegistered"
    private let lastUserKey = "pushToken.lastUserId"

    private var tokenObserver: NSObjectProtocol?
    private var pendingToken: String?
    private var isLoggedIn = false
    private var currentUserId: String?

    init(
        notificationService: SupabaseNotificationService = SupabaseNotificationService(),
        notificationCenter: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.notificationService = notificationService
        self.notificationCenter = notificationCenter
        self.defaults = defaults

        tokenObserver = NotificationCenter.default.addObserver(
            forName: .pushTokenUpdated,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let token = note.object as? String else { return }
            Task { @MainActor in
                guard let self else { return }
                self.pendingToken = token
                await self.registerIfPossible()
            }
        }
    }

    deinit {
        if let tokenObserver {
            NotificationCenter.default.removeObserver(tokenObserver)
        }
    }

    func updateAuth(userId: String?) {
        currentUserId = userId
        isLoggedIn = userId != nil

        guard isLoggedIn else { return }

        Task {
            await requestAuthorizationIfNeeded()
            await registerIfPossible()
        }
    }

    private func requestAuthorizationIfNeeded() async {
        let settings = await currentSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            } catch {
                return
            }
        case .authorized, .provisional, .ephemeral:
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        default:
            return
        }
    }

    private func currentSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func registerIfPossible() async {
        guard isLoggedIn, let token = pendingToken, let userId = currentUserId else { return }
        let lastToken = defaults.string(forKey: lastTokenKey)
        let lastUser = defaults.string(forKey: lastUserKey)
        if token == lastToken && userId == lastUser { return }

        do {
            try await notificationService.registerPushToken(deviceToken: token, platform: .apns)
            defaults.set(token, forKey: lastTokenKey)
            defaults.set(userId, forKey: lastUserKey)
        } catch {
            return
        }
    }
}
