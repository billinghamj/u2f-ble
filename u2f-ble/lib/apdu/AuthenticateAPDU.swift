//
//  AuthenticateAPDU.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 17/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation

final class AuthenticateAPDU: APDUType {
	fileprivate static let derSeqByte: UInt8 = 0x30

	let challenge: Data
	let applicationParameter: Data
	let keyHandle: Data
	let registerAPDU: RegisterAPDU
	var onDebugMessage: ((APDUType, String) -> Void)?
	fileprivate(set) var userPresenceFlag: UInt8?
	fileprivate(set) var counter: UInt32?
	fileprivate(set) var signature: Data?

	init?(registerAPDU: RegisterAPDU, challenge: Data, applicationParameter: Data, keyHandle: Data) {
		guard challenge.count == 32 && applicationParameter.count == 32 else { return nil }

		self.registerAPDU = registerAPDU
		self.challenge = challenge
		self.applicationParameter = applicationParameter
		self.keyHandle = keyHandle
	}

	func buildRequest() -> Data {
		let writer = DataWriter()
		writer.writeNextUInt8(0x00) // cla
		writer.writeNextUInt8(0x02) // ins
		writer.writeNextUInt8(0x03) // p1
		writer.writeNextUInt8(0x00) // p2
		writer.writeNextUInt8(0x00) // 00
		writer.writeNextUInt8(0x00) // l1
		writer.writeNextUInt8(UInt8(0x41) + UInt8(keyHandle.count)) // l2
		writer.writeNextData(challenge)
		writer.writeNextData(applicationParameter)
		writer.writeNextUInt8(UInt8(keyHandle.count))
		writer.writeNextData(keyHandle)
		writer.writeNextUInt8(0x00) // le1
		writer.writeNextUInt8(0x00) // le2

		onDebugMessage?(self, "Building AUTHENTICATE APDU request...")
		onDebugMessage?(self, "Got challenge = \(challenge)")
		onDebugMessage?(self, "Got application parameter = \(applicationParameter)")
		onDebugMessage?(self, "Got key handle = \(keyHandle)")
		return writer.data
	}

	func parseResponse(_ data: Data) -> Bool {
		let reader = DataReader(data: data)

		// flags
		guard
			let userPresenceFlag = reader.readNextUInt8(),
			let counter = reader.readNextBigEndianUInt32()
			else {
				return false
		}

		// signature
		guard let derSequence = reader.readNextUInt8(), derSequence == type(of: self).derSeqByte else { return false }
		guard
			let signatureLength = reader.readNextUInt8(),
			let signature = reader.readNextDataOfLength(Int(signatureLength))
			else {
				return false
		}
		var finalSignature = Data()
		finalSignature.append([derSequence], count: 1)
		finalSignature.append([signatureLength], count: 1)
		finalSignature.append(signature)

		self.signature = finalSignature
		self.counter = counter
		self.userPresenceFlag = userPresenceFlag

		onDebugMessage?(self, "Building AUTHENTICATE APDU response...")
		onDebugMessage?(self, "Got counter = \(counter)")
		onDebugMessage?(self, "Got user presence flag = \(userPresenceFlag)")
		onDebugMessage?(self, "Got signature = \(finalSignature)")

		return true
	}
}
