//
//  ViewController.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//  Copyright © 2018 James Billingham. All rights reserved.
//

import UIKit
import os.log

class ViewController: UIViewController {
	@IBOutlet fileprivate weak var loadingIndicator: UIActivityIndicatorView!
	@IBOutlet fileprivate weak var stateLabel: UILabel!
	@IBOutlet fileprivate weak var nameLabel: UILabel!
	@IBOutlet var actionButtons: [UIButton]!

	fileprivate lazy var bluetoothManager: BluetoothManager = {
		let manager = BluetoothManager()
		manager.onStateChanged = self.handleStateChanged
		manager.onDebugMessage = self.handleDebugMessage
		manager.onReceivedAPDU = self.handleReceivedAPDU
		return manager
	}()
	fileprivate var currentAPDU: APDUType? = nil
	fileprivate var keyHandle: Data? = nil

	// MARK: Actions

	@IBAction func sendRegister() {
		guard
			bluetoothManager.state == .Disconnected
			else { return }

		var challenge: [UInt8] = []
		var applicationParameter: [UInt8] = []

		for i in 0..<32 {
			challenge.append(UInt8(i))
			applicationParameter.append(UInt8(i) | 0x80)
		}
		let challengeData = Data(bytes: challenge)
		let applicationParameterData = Data(bytes: applicationParameter)

		if let apdu = RegisterAPDU(challenge: challengeData, applicationParameter: applicationParameterData) {
			apdu.onDebugMessage = self.handleAPDUMessage
			currentAPDU = apdu
			bluetoothManager.scanForDevice()
		} else {
			appendLogMessage("Unable to build REGISTER APDU")
		}
	}

	@IBAction func sendAuthenticate() {
		guard
			bluetoothManager.state == .Disconnected
			else { return }

		guard
			let keyHandle = keyHandle
			else {
				appendLogMessage("Unable to build AUTHENTICATE APDU, not yet REGISTERED")
				return
		}

		var challenge: [UInt8] = []
		var applicationParameter: [UInt8] = []

		for i in 0..<32 {
			challenge.append(UInt8(i) | 0x10)
			applicationParameter.append(UInt8(i) | 0x80)
		}
		let challengeData = Data(bytes: challenge)
		let applicationParameterData = Data(bytes: applicationParameter)

		if let apdu = AuthenticateAPDU(challenge: challengeData, applicationParameter: applicationParameterData, keyHandle: keyHandle) {
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
		if let success = currentAPDU?.parseResponse(data), success {
			appendLogMessage("Successfully parsed APDU response of kind \(currentAPDU as APDUType?)")
			if let currentAPDU = currentAPDU as? RegisterAPDU {
				keyHandle = currentAPDU.keyHandle
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
		bluetoothManager.state == .Scanning ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
		stateLabel.text = bluetoothManager.state.rawValue
		nameLabel.isHidden = bluetoothManager.state != .Connected
		nameLabel.text = bluetoothManager.deviceName
		actionButtons.forEach() { $0.isEnabled = bluetoothManager.state == .Disconnected }
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		updateUI()
	}
}
