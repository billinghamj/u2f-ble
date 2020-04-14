//
//  AppDelegate.swift
//  u2f-mac
//
//  Created by James Billingham on 18/12/2018.
//  Copyright © 2018 Cuvva. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	@IBOutlet weak var window: NSWindow!


	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		print(urls)
	}
}

