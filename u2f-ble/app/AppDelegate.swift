//
//  AppDelegate.swift
//  u2f-ble
//
//  Created by James Billingham on 28/11/2018.
//  Copyright © 2018 James Billingham. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		return true
	}

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
		guard
			url.scheme == "cuvva-u2f",
			url.host == "auth",
			url.path == "",
			let (data, returnURL) = parseParams(url)
			else { return false }

		print(data.challenge.data.base64EncodedString())
		print(returnURL)

		return false
	}
}

func parseParams(_ url: URL) -> (data: U2FRequest, returnURL: URL)? {
	guard
		let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
		else { return nil }

	var data: U2FRequest?
	var returnURL: URL?

	for item in params {
		switch item.name {
		case "data":
			data = try! JSONDecoder().decode(U2FRequest.self, from: item.value!.data(using: .utf8)!)
		case "returnUrl":
			returnURL = URL(string: item.value!)!
		default:
			return nil
		}
	}

	guard
		let data2 = data,
		let returnURL2 = returnURL
		else { return nil }

	return (data2, returnURL2)
}

struct U2FRequest: Decodable {
	let type: RequestType
	let appId: URL
	let challenge: Base64URLData
	let registeredKeys: [RegisteredKeys]?
	let timeoutSeconds: Int64?
	let requestId: Int64?

	enum RequestType: String, Codable {
		case register = "u2f_register_request"
		case sign = "u2f_sign_request"
	}

	struct RegisteredKeys: Decodable {
		let keyHandle: Base64URLData
	}
}

struct Base64URLData: Decodable {
	let data: Data

	init(from decoder: Decoder) throws {
		let b64URL = try String.init(from: decoder)

		data = Data(base64Encoded: b64URLToB64(b64URL))!
	}
}

func b64URLToB64(_ b64URL: String) -> String {
	var b64 = b64URL
		.replacingOccurrences(of: "-", with: "+")
		.replacingOccurrences(of: "_", with: "/")

	if b64.count % 4 != 0 {
		b64.append(String(repeating: "=", count: 4 - b64.count % 4))
	}

	return b64
}
