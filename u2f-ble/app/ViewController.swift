//
//  ViewController.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
	@IBOutlet fileprivate weak var loadingIndicator: UIActivityIndicatorView!
	@IBOutlet fileprivate weak var scanButton: UIButton!
	@IBOutlet fileprivate weak var stopButton: UIButton!
	@IBOutlet fileprivate weak var stateLabel: UILabel!
	@IBOutlet fileprivate weak var nameLabel: UILabel!
	@IBOutlet fileprivate weak var textView: UITextView!
	@IBOutlet var actionButtons: [UIButton]!

	fileprivate lazy var bluetoothManager: BluetoothManager = {
		let manager = BluetoothManager()
		manager.onStateChanged = self.handleStateChanged
		manager.onDebugMessage = self.handleDebugMessage
		manager.onReceivedAPDU = self.handleReceivedAPDU
		return manager
	}()
	fileprivate var useInvalidApplicationParameter = true
	fileprivate var useInvalidKeyHandle = true
	fileprivate var currentAPDU: APDUType? = nil
	fileprivate var registerAPDU: RegisterAPDU? = nil

	// MARK: Actions

	@IBAction func scanForDevice() {
		bluetoothManager.scanForDevice()
	}

	@IBAction func stopSession() {
		bluetoothManager.stopSession()
	}

	@IBAction func sendRegister() {
		var challenge: [UInt8] = []
		var applicationParameter: [UInt8] = []

		for i in 0..<32 {
			challenge.append(UInt8(i))
			applicationParameter.append(UInt8(i) | 0x80)
		}
		let challengeData = Data(bytes: challenge)
		let applicationParameterData = Data(bytes: applicationParameter)

		if let APDU = RegisterAPDU(challenge: challengeData, applicationParameter: applicationParameterData) {
			APDU.onDebugMessage = self.handleAPDUMessage
			let data = APDU.buildRequest()
			bluetoothManager.exchangeAPDU(data)
			currentAPDU = APDU
		}
		else {
			appendLogMessage("Unable to build REGISTER APDU")
		}
	}

	@IBAction func sendAuthenticate() {
		guard
			let registerAPDU = registerAPDU,
			let originalKeyHandle = registerAPDU.keyHandle else {
				appendLogMessage("Unable to build AUTHENTICATE APDU, not yet REGISTERED")
				return
		}

		var challenge: [UInt8] = []
		var applicationParameter: [UInt8] = []
		let keyHandleData: Data

		for i in 0..<32 {
			challenge.append(UInt8(i) | 0x10)
			applicationParameter.append(UInt8(i) | 0x80)
		}
		if useInvalidApplicationParameter {
			applicationParameter[0] = 0xFF
		}
		if useInvalidKeyHandle {
			var data = originalKeyHandle
			data.replaceSubrange(0..<2, with: [0xFF, 0xFF] as [UInt8], count: 2)
			data.replaceSubrange((data.count - 1)..<data.count, with: [0xFF] as [UInt8], count: 1)
			keyHandleData = data
		}
		else {
			keyHandleData = originalKeyHandle
		}
		let challengeData = Data(bytes: challenge)
		let applicationParameterData = Data(bytes: applicationParameter)

		if let APDU = AuthenticateAPDU(registerAPDU: registerAPDU, challenge: challengeData, applicationParameter: applicationParameterData, keyHandle: keyHandleData) {
			APDU.onDebugMessage = self.handleAPDUMessage
			let data = APDU.buildRequest()
			bluetoothManager.exchangeAPDU(data)
			currentAPDU = APDU
		}
		else {
			appendLogMessage("Unable to build AUTHENTICATE APDU")
		}
	}

	@IBAction func toggleApplicationParameter() {
		useInvalidApplicationParameter = !useInvalidApplicationParameter
		appendLogMessage("Use invalid application parameter = \(useInvalidApplicationParameter)")
	}

	@IBAction func toggleKeyHandle() {
		useInvalidKeyHandle = !useInvalidKeyHandle
		appendLogMessage("Use invalid key handle = \(useInvalidKeyHandle)")
	}

	@IBAction func clearLogs() {
		textView.text = ""
	}

	// MARK: BluetoothManager

	fileprivate func handleStateChanged(_ manager: BluetoothManager, state: BluetoothManagerState) {
		updateUI()

		if state == .Disconnected {
			currentAPDU = nil
		}
	}

	fileprivate func handleDebugMessage(_ manager: BluetoothManager, message: String) {
		appendLogMessage(message)
	}

	fileprivate func handleReceivedAPDU(_ manager: BluetoothManager, data: Data) {
		if let success = currentAPDU?.parseResponse(data), success {
			appendLogMessage("Successfully parsed APDU response of kind \(currentAPDU as APDUType?)")
			if currentAPDU is RegisterAPDU {
				registerAPDU = currentAPDU as? RegisterAPDU
			}
		}
		else {
			appendLogMessage("Failed to parse APDU response of kind \(type(of: currentAPDU as APDUType?))")
		}
		currentAPDU = nil
	}

	// MARK: APDU

	fileprivate func handleAPDUMessage(_ APDU: APDUType, message: String) {
		appendLogMessage(message)
	}

	// MARK: User interface

	fileprivate func appendLogMessage(_ message: String) {
		textView.text = textView.text + "- \(message)\n"
		let range = NSMakeRange(textView.text.count - 1, 1)
		UIView.setAnimationsEnabled(false)
		textView.scrollRangeToVisible(range)
		UIView.setAnimationsEnabled(true)
	}

	fileprivate func updateUI() {
		bluetoothManager.state == .Scanning ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
		stateLabel.text = bluetoothManager.state.rawValue
		scanButton.isEnabled = bluetoothManager.state == .Disconnected
		stopButton.isEnabled = bluetoothManager.state == .Connecting || bluetoothManager.state == .Connected || bluetoothManager.state == .Scanning
		nameLabel.isHidden = bluetoothManager.state != .Connected
		nameLabel.text = bluetoothManager.deviceName
		actionButtons.forEach() { $0.isEnabled = bluetoothManager.state == .Connected }
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		textView.layoutManager.allowsNonContiguousLayout = false
		updateUI()
		toggleApplicationParameter()
		toggleKeyHandle()
	}
}
