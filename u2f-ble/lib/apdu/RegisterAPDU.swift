//
//  RegisterAPDURequest.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 16/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation

final class RegisterAPDU: APDUType {
	fileprivate static let reservedByte: UInt8 = 0x05
	fileprivate static let derSeqByte: UInt8 = 0x30
	fileprivate static let derLen1Byte: UInt8 = 0x81
	fileprivate static let derLen2Byte: UInt8 = 0x82

	let challenge: Data
	let applicationParameter: Data
	var onDebugMessage: ((APDUType, String) -> Void)?
	fileprivate(set) var publicKey: Data?
	fileprivate(set) var keyHandle: Data?
	fileprivate(set) var certificate: Data?
	fileprivate(set) var signature: Data?

	init?(challenge: Data, applicationParameter: Data) {
		guard challenge.count == 32 && applicationParameter.count == 32 else { return nil }

		self.challenge = challenge
		self.applicationParameter = applicationParameter
	}

	func buildRequest() -> Data {
		let writer = DataWriter()
		writer.writeNextUInt8(0x00) // cla
		writer.writeNextUInt8(0x01) // ins
		writer.writeNextUInt8(0x00) // p1
		writer.writeNextUInt8(0x00) // p2
		writer.writeNextUInt8(0x00) // 00
		writer.writeNextUInt8(0x00) // l1
		writer.writeNextUInt8(0x40) // l2
		writer.writeNextData(challenge)
		writer.writeNextData(applicationParameter)
		writer.writeNextUInt8(0x00) // le1
		writer.writeNextUInt8(0x00) // le2

		onDebugMessage?(self, "Building REGISTER APDU request...")
		onDebugMessage?(self, "Got challenge = \(challenge)")
		onDebugMessage?(self, "Got application parameter = \(applicationParameter)")
		return writer.data
	}

	func parseResponse(_ data: Data) -> Bool {
		let reader = DataReader(data: data)

		// public key
		guard
			let reservedByte = reader.readNextUInt8(),
			let publicKey = reader.readNextDataOfLength(65),
			reservedByte == type(of: self).reservedByte
			else {
				return false
		}

		// key handle
		guard
			let keyHandleLength = reader.readNextUInt8(),
			let keyHandle = reader.readNextDataOfLength(Int(keyHandleLength))
			else {
				return false
		}

		// certificate
		guard let derSequence1 = reader.readNextUInt8(), derSequence1 == type(of: self).derSeqByte else { return false }
		guard let derCertificateLengthKind = reader.readNextUInt8() else { return false }

		var certificateLength = 0
		if derCertificateLengthKind == type(of: self).derLen1Byte {
			guard let readLength = reader.readNextUInt8() else { return false }
			certificateLength = Int(readLength)
		}
		else if derCertificateLengthKind == type(of: self).derLen2Byte {
			guard let readLength = reader.readNextBigEndianUInt16() else { return false }
			certificateLength = Int(readLength)
		}
		else {
			return false
		}

		guard
			let certificate = reader.readNextDataOfLength(certificateLength)
			else {
				return false
		}
		let writer = DataWriter()
		writer.writeNextUInt8(derSequence1)
		writer.writeNextUInt8(derCertificateLengthKind)
		if derCertificateLengthKind == type(of: self).derLen1Byte {
			writer.writeNextUInt8(UInt8(certificateLength))
		}
		else if derCertificateLengthKind == type(of: self).derLen2Byte {
			writer.writeNextBigEndianUInt16(UInt16(certificateLength))
		}
		writer.writeNextData(certificate)
		let finalCertificate = writer.data

		// signature
		guard let derSequence2 = reader.readNextUInt8(), derSequence2 == type(of: self).derSeqByte else { return false }
		guard
			let signatureLength = reader.readNextUInt8(),
			let signature = reader.readNextDataOfLength(Int(signatureLength))
			else {
				return false
		}
		var finalSignature = Data()
		finalSignature.append([derSequence2], count: 1)
		finalSignature.append([signatureLength], count: 1)
		finalSignature.append(signature)

		self.publicKey = publicKey
		self.keyHandle = keyHandle
		self.certificate = finalCertificate
		self.signature = finalSignature

		onDebugMessage?(self, "Building REGISTER APDU response...")
		onDebugMessage?(self, "Got public key = \(publicKey)")
		onDebugMessage?(self, "Got key handle = \(keyHandle)")
		onDebugMessage?(self, "Got certificate = \(finalCertificate)")
		onDebugMessage?(self, "Got signature = \(finalSignature)")

		return true
	}
}
