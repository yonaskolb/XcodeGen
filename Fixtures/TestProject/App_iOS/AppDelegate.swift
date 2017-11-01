//
//  AppDelegate.swift
//  TestProject
//
//  Created by Yonas Kolb on 19/7/17.
//  Copyright © 2017 Yonas Kolb. All rights reserved.
//

import UIKit
import Framework

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        _ = FrameworkStruct()
        // Standalone files added to project by path-to-file.
        _ = standaloneHello()
        return true
    }

}

