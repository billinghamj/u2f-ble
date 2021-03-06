//
//  U2FFacets.swift
//  u2f-ble
//
//  Created by James Billingham on 09/12/2018.
//  Copyright © 2018 James Billingham. All rights reserved.
//

import Foundation
import TLDExtract

private struct U2FTrustedFacetsResponse: Codable {
	let trustedFacets: [U2FTrustedFacetList]
}

private struct U2FTrustedFacetList: Codable {
	let version: Version
	let ids: [String]

	struct Version: Codable {
		let major: UInt16
		let minor: UInt16
	}
}

struct U2FFacets {
	static func genFacetID(_ url: URL) -> String? {
		guard
			url.scheme == "https",
			let host = url.host,
			host != ""
			else { return nil }

		var comps = URLComponents()

		comps.scheme = url.scheme
		comps.host = url.host
		comps.port = url.port

		return comps.url!.absoluteString
	}

	static func loadTrustedFacetList(_ appID: URL, completionHandler: @escaping ([String]?) -> Void) {
		let session = URLSession(configuration: .default, delegate: urlSessionDelegate, delegateQueue: nil)

		guard
			let tldExtractor = try? TLDExtract(),
			let appIDDomain = tldExtractor.parse(appID)?.rootDomain
			else {
				completionHandler(nil)
				return
		}

		let task = session.dataTask(with: appID, completionHandler: { (data, response, error) in
			guard
				error == nil,
				let response = response as? HTTPURLResponse,
				response.statusCode >= 200,
				response.statusCode < 300,
				response.mimeType == "application/fido.trusted-apps+json",
				let data = data,
				let result = try? JSONDecoder().decode(U2FTrustedFacetsResponse.self, from: data),
				let list = result.trustedFacets.first(where: { $0.version.major == 1 && $0.version.minor == 0 })
				else {
					completionHandler(nil)
					return
			}

			let ids = list.ids
				.map({ (id) -> String? in
					guard
						let url = URL(string: id)
						else { return nil }

					switch url.scheme {
					case "https":
						guard
							let facetIDDomain = tldExtractor.parse(url)?.rootDomain,
							facetIDDomain.lowercased() == appIDDomain.lowercased() || (
								// https://padlock.argh.in/2018/08/25/u2f-firefox-google.html
								facetIDDomain == "google.com" && (
									appID.absoluteString == "https://www.gstatic.com/securitykey/origins.json" ||
									appID.absoluteString == "https://www.gstatic.com/securitykey/a/google.com/origins.json"
								)
							),
							let facetID = genFacetID(url)
							else { return nil }
						return facetID
					case "ios":
						return id
					default:
						return nil
					}
				})
				.filter({ $0 != nil })
				.map({ $0! })

			completionHandler(ids.count > 0 ? ids : nil)
		})

		task.resume()
	}
}

private let urlSessionDelegate = U2FTrustedFacetURLSessionDelegate()

private class U2FTrustedFacetURLSessionDelegate: NSObject, URLSessionTaskDelegate {
	func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
		for header in response.allHeaderFields {
			guard
				let key = (header.key as? String),
				let val = (header.value as? String),
				key.lowercased() == "FIDO-AppID-Redirect-Authorized".lowercased(),
				val == "true"
				else { continue }

			completionHandler(request)
			return
		}

		completionHandler(nil)
	}
}
