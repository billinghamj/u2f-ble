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
			let (data, returnURL) = parseParams(url),
			let req = try? JSONDecoder().decode(U2FRequest.self, from: data),
			let sourceAppBundleID = options[.sourceApplication] as? NSString,
			let returnURLFacetID = U2FFacets.genFacetID(returnURL)
			else { return false }

		let sourceAppFacetID = "ios:bundle-id:\(sourceAppBundleID)"

		switch req.type {
		case .register:
			// TODO: support?
			return false
		case .sign:
			let req = try! JSONDecoder().decode(U2FSignRequest.self, from: data)
			let challenge = req.challenge
			let requestID = req.requestID

			// TODO: evaluate all keys in order (though load trusted facet lists in parallel!)
			let key = req.registeredKeys![0]

			guard
				let appID = key.appID ?? req.appID,
				let appIDURL = URL(string: appID),
				let appIDFacetID = U2FFacets.genFacetID(appIDURL)
				else { return false }

			if sourceAppFacetID == appID {
				doSign(appID: appID, facetID: sourceAppFacetID, challenge: challenge, key: key, requestID: requestID, returnURL: returnURL)
				return true
			}

			if returnURLFacetID == appIDFacetID {
				doSign(appID: appID, facetID: returnURLFacetID, challenge: challenge, key: key, requestID: requestID, returnURL: returnURL)
				return true
			}

			guard
				appIDURL.scheme == "https"
				else { return false }

			U2FFacets.loadTrustedFacetList(appIDURL, completionHandler: { (ids) in
				guard
					let ids = ids
					else { return } // TODO: return error somehow?

				if ids.contains(where: { $0 == sourceAppFacetID }) {
					DispatchQueue.main.async(execute: { [unowned self] in
						self.doSign(appID: appID, facetID: sourceAppFacetID, challenge: challenge, key: key, requestID: requestID, returnURL: returnURL)
					})
				}

				if ids.contains(where: { $0 == returnURLFacetID }) {
					DispatchQueue.main.async(execute: { [unowned self] in
						self.doSign(appID: appID, facetID: returnURLFacetID, challenge: challenge, key: key, requestID: requestID, returnURL: returnURL)
					})
				}

				// TODO: return error?
			})

			return true
		}
	}

	private func doSign(appID: String, facetID: String, challenge: String, key: U2FRegisteredKey, requestID: UInt64?, returnURL: URL) {
		let clientData = try! JSONEncoder().encode(ClientData(type: .sign, challenge: challenge, facetID: facetID))
		let keyHandle = key.keyHandle.data

		(window?.rootViewController as? ViewController)?.handleAuthenticate(appID: appID, clientData: clientData, keyHandle: keyHandle, callback: { (signature) in
			let data = U2FSignResponseData(keyHandle: key.keyHandle, signatureData: Base64URLData(signature), clientData: Base64URLData(clientData))
			let response = U2FResponse(type: .sign, responseData: .sign(data), requestID: requestID)
			let json = try! String(data: JSONEncoder().encode(response), encoding: .utf8)

			var comps = URLComponents(url: returnURL, resolvingAgainstBaseURL: false)!
			comps.percentEncodedFragment = "chaldt=\(json!.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!)"

			UIApplication.shared.open(comps.url!)
		})
	}
}

func parseParams(_ url: URL) -> (data: Data, returnURL: URL)? {
	guard
		let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
		else { return nil }

	var data: Data?
	var returnURL: URL?

	for item in params {
		switch item.name {
		case "data":
			data = item.value!.data(using: .utf8)
		case "returnUrl":
			returnURL = URL(string: item.value!)
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

struct ClientData: Codable {
	let type: AssertionType
	let challenge: String
	let cidPubkey: String = "unused"
	let facetID: String

	private enum CodingKeys: String, CodingKey {
		case type = "typ", challenge, cidPubkey = "cid_pubkey", facetID = "origin"
	}

	enum AssertionType: String, Codable {
		case register = "navigator.id.finishEnrollment"
		case sign = "navigator.id.getAssertion"
	}
}
