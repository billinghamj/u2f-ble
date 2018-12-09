//
//  AppDelegate.swift
//  u2f-ble
//
//  Created by James Billingham on 28/11/2018.
//  Copyright © 2018 James Billingham. All rights reserved.
//

import UIKit
import TLDExtract

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

		let req = try! JSONDecoder().decode(U2FRequest.self, from: data)

		guard
			let facetID = getWebOrigin(returnURL)
			else { return false }

		switch req.type {
		case .register:
			// TODO: support?
			return false
		case .sign:
			let req = try! JSONDecoder().decode(U2FSignRequest.self, from: data)

			let key = req.registeredKeys![0]
			let appID = key.appID ?? req.appID ?? facetID

			guard
				let appIDURL = URL(string: appID),
				let appIDOrigin = getWebOrigin(appIDURL),
				appIDOrigin == facetID
				else { return false }

			print((try! TLDExtract()).parse(appIDURL)!.rootDomain!)

			// TODO: allow for a trusted facet list

			let clientData = try! JSONEncoder().encode(ClientData(type: .sign, challenge: req.challenge, origin: facetID))
			let keyHandle = key.keyHandle.data

			(window?.rootViewController as? ViewController)?.handleAuthenticate(appID: appID, clientData: clientData, keyHandle: keyHandle, callback: { (signature) in
				let data = U2FSignResponseData(keyHandle: key.keyHandle, signatureData: Base64URLData(signature), clientData: Base64URLData(clientData))
				let response = U2FResponse(type: .sign, responseData: .sign(data), requestID: req.requestID)
				let json = try! String(data: JSONEncoder().encode(response), encoding: .utf8)

				var comps = URLComponents(url: returnURL, resolvingAgainstBaseURL: false)!
				comps.percentEncodedFragment = "chaldt=\(json!.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!)"

				UIApplication.shared.open(comps.url!)
			})

			return true
		}
	}

	func loadTrustedFacetList(_ appID: URL, completionHandler: @escaping (U2FTrustedFacetsResponse?) -> Void) {
		let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

		let task = session.dataTask(with: appID, completionHandler: { (data, response, error) in
			guard
				error == nil,
				let response = response as? HTTPURLResponse,
				response.statusCode >= 200,
				response.statusCode < 300,
				response.mimeType == "application/fido.trusted-apps+json",
				let data = data,
				let result = try? JSONDecoder().decode(U2FTrustedFacetsResponse.self, from: data)
				else {
					completionHandler(nil)
					return
			}

			completionHandler(result)
		})

		task.resume()
	}
}

extension AppDelegate: URLSessionTaskDelegate {
	func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
		for header in response.allHeaderFields {
			if (header.key as! String).lowercased() == "FIDO-AppID-Redirect-Authorized" && (header.value as! String) == "true" {
				completionHandler(request)
				return
			}
		}

		completionHandler(nil)
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

func getWebOrigin(_ url: URL) -> String? {
	guard
		url.scheme == "https", // TODO: maybe allow `ios:bundle-id:...` facet IDs?
		let host = url.host,
		host != ""
		else { return nil }

	var comps = URLComponents()

	comps.scheme = url.scheme
	comps.host = url.host
	comps.port = url.port

	return comps.url!.absoluteString
}

struct ClientData: Codable {
	let type: AssertionType
	let challenge: String
	let cidPubkey: String = "unused"
	let origin: String

	private enum CodingKeys: String, CodingKey {
		case type = "typ", challenge, cidPubkey = "cid_pubkey", origin
	}

	enum AssertionType: String, Codable {
		case register = "navigator.id.finishEnrollment"
		case sign = "navigator.id.getAssertion"
	}
}

struct U2FTrustedFacetsResponse: Codable {
	let trustedFacets: [U2FTrustedFacets]
}

struct U2FTrustedFacets: Codable {
	let version: Version
	let ids: [String]

	struct Version: Codable {
		let major: UInt16
		let minor: UInt16
	}
}
