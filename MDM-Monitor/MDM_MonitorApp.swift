//
//  MDM_MonitorApp.swift
//  MDM-Monitor
//
//  Created by George Babichev on 4/2/26.
//

import AppKit
import Combine
import SwiftUI
import UserNotifications

final class NotificationCoordinator: NSObject, ObservableObject {
    private let center = UNUserNotificationCenter.current()
    private var unreadCount = 0

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    @MainActor
    func notify(for event: CheckInEvent, mode: MonitoringMode) {
        unreadCount += 1
        NSApp.dockTile.badgeLabel = "\(unreadCount)"

        let content = UNMutableNotificationContent()
        content.title = mode == .mdmclient ? "MDM Check-In" : "JAMF Pro Check-In"
        content.body = event.message
        content.sound = .default
        content.badge = NSNumber(value: unreadCount)

        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    @MainActor
    func clearDeliveredNotifications() {
        unreadCount = 0
        NSApp.dockTile.badgeLabel = nil
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
}

extension NotificationCoordinator: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct MDM_MonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = MDMCheckInMonitor()
    @StateObject private var notificationCoordinator = NotificationCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    @State private var monitorSubscription: AnyCancellable?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
                .onAppear {
                    if monitor.notificationsEnabled {
                        notificationCoordinator.requestAuthorizationIfNeeded()
                    }

                    if monitorSubscription == nil {
                        monitorSubscription = monitor.liveEventPublisher
                            .receive(on: RunLoop.main)
                            .sink { event in
                                guard monitor.notificationsEnabled else { return }
                                notificationCoordinator.notify(for: event, mode: monitor.monitoringMode)
                            }
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                notificationCoordinator.clearDeliveredNotifications()
            }
        }
        .onChange(of: monitor.notificationsEnabled) { _, isEnabled in
            if isEnabled {
                notificationCoordinator.requestAuthorizationIfNeeded()
            } else {
                notificationCoordinator.clearDeliveredNotifications()
            }
        }
    }
}
