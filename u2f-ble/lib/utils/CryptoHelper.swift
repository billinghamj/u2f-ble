//
//  CryptoHelper.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 17/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation
import Security

@objc final class CryptoHelper: NSObject {
	static func verifyRegisterSignature(_ APDU: RegisterAPDU) ->  Bool {
		guard
			let certificate = APDU.certificate,
			let signature = APDU.signature,
			let keyHandle = APDU.keyHandle,
			let publicKey = APDU.publicKey,
			let extractedSignaturePoints = extractPointsFromSignature(signature)
			else {
				return false
		}

		// extract certificate publickey
		var trustRef: SecTrust? = nil
		let policy = SecPolicyCreateBasicX509()
		guard
			let certificateRef = SecCertificateCreateWithData(nil, certificate as CFData),
			SecTrustCreateWithCertificates(certificateRef, policy, &trustRef) == errSecSuccess &&
				trustRef != nil
			else {
				return false
		}
		let key = SecTrustCopyPublicKey(trustRef!)
		let certificatePublicKey = getPublicKeyBitsFromKey(key)

		// check signature
		let crypto = GMEllipticCurveCrypto(forKey: certificatePublicKey)
		var data = Data()
		data.append([0x00] as [UInt8], count: 1)
		data.append(APDU.applicationParameter)
		data.append(APDU.challenge)
		data.append(keyHandle)
		data.append(publicKey)
		var extractedSignature = Data()
		extractedSignature.append(extractedSignaturePoints.r)
		extractedSignature.append(extractedSignaturePoints.s)
		return crypto!.hashSHA256AndVerifySignature(extractedSignature, for: data)
	}

	static func verifyAuthenticateSignature(_ APDU: AuthenticateAPDU) ->  Bool {
		guard
			let publicKey = APDU.registerAPDU.publicKey,
			let userPresenceFlag = APDU.userPresenceFlag,
			let counter = APDU.counter,
			let signature = APDU.signature,
			let extractedSignaturePoints = extractPointsFromSignature(signature)
			else {
				return false
		}

		// check signature
		let crypto = GMEllipticCurveCrypto(forKey: publicKey)
		let writer = DataWriter()
		writer.writeNextData(APDU.applicationParameter)
		writer.writeNextUInt8(userPresenceFlag)
		writer.writeNextBigEndianUInt32(counter)
		writer.writeNextData(APDU.challenge)
		var extractedSignature = Data()
		extractedSignature.append(extractedSignaturePoints.r)
		extractedSignature.append(extractedSignaturePoints.s)
		return crypto!.hashSHA256AndVerifySignature(extractedSignature, for: writer.data)
	}

	static func extractPointsFromSignature(_ signature: Data) -> (r: Data, s: Data)? {
		let reader = DataReader(data: signature)
		guard
			let _ = reader.readNextUInt8(), // 0x30
			let _ = reader.readNextUInt8(), // length
			let _ = reader.readNextUInt8(), // 0x20
			let rLength = reader.readNextUInt8(),
			var r = reader.readNextDataOfLength(Int(rLength)),
			let _ = reader.readNextUInt8(), // 0x20
			let sLength = reader.readNextUInt8(),
			var s = reader.readNextDataOfLength(Int(sLength))
			else {
				return nil
		}
		r.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Void in
			if bytes[0] == 0x00 {
				r.removeFirst()
			}
		})
		s.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Void in
			if bytes[0] == 0x00 {
				s.removeFirst()
			}
		})
		return (r, s)
	}
}
