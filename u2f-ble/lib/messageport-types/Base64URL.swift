//
//  Shared.swift
//  u2f-ble
//
//  Created by James Billingham on 08/12/2018.
//  Copyright © 2018 Cuvva. All rights reserved.
//

import Foundation

struct Base64URLData: Codable {
	let data: Data

	init(_ data: Data) {
		self.data = data
	}

	init(from decoder: Decoder) throws {
		let b64URL = try String.init(from: decoder)

		data = Data(base64Encoded: b64URLToB64(b64URL))!
	}
}

func b64ToB64URL(_ b64: String) -> String {
	return b64
		.replacingOccurrences(of: "+", with: "-")
		.replacingOccurrences(of: "/", with: "_")
		.replacingOccurrences(of: "=", with: "")
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
