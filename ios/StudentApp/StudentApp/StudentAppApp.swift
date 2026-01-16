//
//  StudentAppApp.swift
//  StudentApp
//
//  Created by ForbiddenGame on 2026/1/4.
//

import SwiftUI

@main
struct StudentAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        AppFont.registerCoachFontIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
