//
//  CBManagerState+Additions.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import CoreBluetooth

extension CBManagerState: CustomStringConvertible {
	public var description: String {
		switch self {
		case .poweredOff: return "poweredOff"
		case .poweredOn: return "poweredOn"
		case .resetting: return "resetting"
		case .unauthorized: return "unauthorized"
		case .unsupported: return "unsupported"
		case .unknown: return "Unknown"
		}
	}
}
