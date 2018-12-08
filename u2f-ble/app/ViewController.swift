//
//  ViewController.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//  Copyright © 2018 James Billingham. All rights reserved.
//

import CommonCrypto
import UIKit
import os.log

func sha256(_ data: Data) -> Data {
	var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
	data.withUnsafeBytes({
		_ = CC_SHA256($0, CC_LONG(data.count), &hash)
	})
	return Data(bytes: hash)
}

class ViewController: UIViewController {
	@IBOutlet fileprivate weak var stateLabel: UILabel!
	@IBOutlet fileprivate weak var nameLabel: UILabel!

	fileprivate lazy var bluetoothManager: BluetoothManager = {
		let manager = BluetoothManager()
		manager.onStateChanged = self.handleStateChanged
		manager.onDebugMessage = self.handleDebugMessage
		manager.onReceivedAPDU = self.handleReceivedAPDU
		return manager
	}()
	fileprivate var currentAPDU: APDUType? = nil
	fileprivate var authenticateCallback: ((_ signature: Data) -> Void)? = nil

	func handleAuthenticate(appID: String, clientData: Data, keyHandle: Data, callback: @escaping (_ signature: Data) -> Void) {
		self.authenticateCallback = callback

		let chal = sha256(clientData)
		let appParam = sha256(appID.data(using: .utf8)!)

		if let apdu = AuthenticateAPDU(challenge: chal, applicationParameter: appParam, keyHandle: keyHandle) {
			apdu.onDebugMessage = self.handleAPDUMessage
			currentAPDU = apdu
			bluetoothManager.scanForDevice()
		} else {
			appendLogMessage("Unable to build AUTHENTICATE APDU")
		}
	}

	// MARK: BluetoothManager

	fileprivate func handleStateChanged(_ manager: BluetoothManager, state: BluetoothManagerState) {
		updateUI()

		switch state {
		case .Connected:
			guard
				let data = currentAPDU?.buildRequest()
				else { return }
			bluetoothManager.exchangeAPDU(data)
		case .Disconnected:
			currentAPDU = nil
		default:
			return
		}
	}

	fileprivate func handleDebugMessage(_ manager: BluetoothManager, message: String) {
		appendLogMessage(message)
	}

	fileprivate func handleReceivedAPDU(_ manager: BluetoothManager, data: Data) {
		if let apdu = currentAPDU, apdu.parseResponse(data) {
			appendLogMessage("Successfully parsed APDU response of kind \(apdu)")

			switch apdu {
			case let apdu as AuthenticateAPDU:
				let dw = DataWriter()
				dw.writeNextUInt8(apdu.userPresenceFlag!)
				dw.writeNextBigEndianUInt32(apdu.counter!)
				dw.writeNextData(apdu.signature!)
				self.authenticateCallback?(dw.data)
			default:
				return
			}
		} else {
			appendLogMessage("Failed to parse APDU response of kind \(type(of: currentAPDU as APDUType?))")
		}
		if bluetoothManager.state == .Connecting || bluetoothManager.state == .Connected || bluetoothManager.state == .Scanning {
			bluetoothManager.stopSession()
		}
	}

	// MARK: APDU

	fileprivate func handleAPDUMessage(_ APDU: APDUType, message: String) {
		appendLogMessage(message)
	}

	// MARK: User interface

	fileprivate func appendLogMessage(_ message: String) {
		os_log("%{public}@", message)
	}

	fileprivate func updateUI() {
		stateLabel.text = bluetoothManager.state.rawValue
		nameLabel.isHidden = bluetoothManager.state != .Connected
		nameLabel.text = bluetoothManager.deviceName
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		updateUI()
	}
}
