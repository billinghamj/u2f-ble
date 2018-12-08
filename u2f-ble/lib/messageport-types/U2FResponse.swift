//
//  U2FResponse.swift
//  u2f-ble
//
//  Created by James Billingham on 08/12/2018.
//  Copyright © 2018 Cuvva. All rights reserved.
//

import Foundation

enum U2FResponseType: String, Codable {
	case register = "u2f_register_response"
	case sign = "u2f_sign_response"
}

struct U2FResponse: Encodable {
	let type: U2FResponseType
	let responseData: U2FResponseData
	let requestID: UInt64?

	private enum CodingKeys: String, CodingKey {
		case type, requestID = "requestId"
	}
}

enum U2FResponseData {
	case error(U2FErrorResponseData)
	case register(U2FRegisterResponseData)
	case sign(U2FSignResponseData)
}

struct U2FErrorResponseData: Codable {
	let errorCode: ErrorCode
	let errorMessage: String?

	enum ErrorCode: UInt16, Codable {
		case ok = 0
		case otherError = 1
		case badRequest = 2
		case configurationUnsupported = 3
		case deviceIneligible = 4
		case timeout = 5
	}
}

struct U2FRegisterResponseData: Codable {
	let version: String
	let registrationData: Base64URLData
	let clientData: Base64URLData
}

struct U2FSignResponseData: Codable {
	let keyHandle: Base64URLData
	let signatureData: Base64URLData
	let clientData: Base64URLData
}
