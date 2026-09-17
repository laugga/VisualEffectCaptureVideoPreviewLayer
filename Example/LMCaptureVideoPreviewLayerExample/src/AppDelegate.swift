/*

 AppDelegate.swift
 LMCaptureVideoPreviewLayerExample

 Copyright (c) 2016 Luis Laugga.
 Some rights reserved, all wrongs deserved.

*/

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = CameraViewController()
        window.makeKeyAndVisible()

        self.window = window

        return true
    }
}
