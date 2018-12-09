//
//  U2FRequest.swift
//  u2f-ble
//
//  Created by James Billingham on 08/12/2018.
//  Copyright © 2018 James Billingham. All rights reserved.
//

import Foundation

enum U2FRequestType: String, Codable {
	case register = "u2f_register_request"
	case sign = "u2f_sign_request"
}

struct U2FRegisteredKey: Codable {
	let version: String
	let keyHandle: Base64URLData
	let transports: [Transport]?
	let appID: String? // type isn't URL because parsing could change the value

	private enum CodingKeys: String, CodingKey {
		case version, keyHandle, transports, appID = "appId"
	}

	enum Transport: String, Codable {
		case bt, ble, nfc, usb
		case usbInternal = "usb-internal"
	}
}

struct U2FRequest: Codable {
	let type: U2FRequestType
	let appID: String? // type isn't URL because parsing could change the value
	let timeoutSeconds: UInt64?
	let requestID: UInt64?

	private enum CodingKeys: String, CodingKey {
		case type, appID = "appId", timeoutSeconds, requestID = "requestId"
	}
}

struct U2FRegisterRequest: Codable {
	let type: U2FRequestType = .register
	let appID: String? // type isn't URL because parsing could change the value
	let timeoutSeconds: UInt64?
	let requestID: UInt64?

	let registerRequests: [Request]
	let registeredKeys: [U2FRegisteredKey]

	private enum CodingKeys: String, CodingKey {
		case type, appID = "appId", timeoutSeconds, requestID = "requestId", registerRequests, registeredKeys
	}

	struct Request: Codable {
		let version: String
		let challenge: String // type isn't Base64URLData because ClientData needs it as a String
	}
}

struct U2FSignRequest: Codable {
	let type: U2FRequestType = .sign
	let appID: String? // type isn't URL because parsing could change the value
	let timeoutSeconds: UInt64?
	let requestID: UInt64?

	let challenge: String // type isn't Base64URLData because ClientData needs it as a String
	let registeredKeys: [U2FRegisteredKey]?

	private enum CodingKeys: String, CodingKey {
		case type, appID = "appId", timeoutSeconds, requestID = "requestId", challenge, registeredKeys
	}
}
