//
//  DataReader.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 11/02/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//  Copyright © 2018 James Billingham. All rights reserved.
//

import Foundation

final class DataReader {
	fileprivate var internalData: Data

	var remainingBytesLength: Int {
		return internalData.count
	}

	// MARK: Read methods

	func readNextInt8() -> Int8? {
		return readNextInteger()
	}

	func readNextUInt8() -> UInt8? {
		return readNextInteger()
	}

	func readNextBigEndianUInt16() -> UInt16? {
		return readNextInteger(bigEndian: true)
	}

	func readNextLittleEndianUInt16() -> UInt16? {
		return readNextInteger(bigEndian: false)
	}

	func readNextBigEndianInt16() -> Int16? {
		return readNextInteger(bigEndian: true)
	}

	func readNextLittleEndianInt16() -> Int16? {
		return readNextInteger(bigEndian: false)
	}

	func readNextBigEndianUInt32() -> UInt32? {
		return readNextInteger(bigEndian: true)
	}

	func readNextLittleEndianUInt32() -> UInt32? {
		return readNextInteger(bigEndian: false)
	}

	func readNextBigEndianInt32() -> Int32? {
		return readNextInteger(bigEndian: true)
	}

	func readNextLittleEndianInt32() -> Int32? {
		return readNextInteger(bigEndian: false)
	}

	func readNextBigEndianUInt64() -> UInt64? {
		return readNextInteger(bigEndian: true)
	}

	func readNextLittleEndianUInt64() -> UInt64? {
		return readNextInteger(bigEndian: false)
	}

	func readNextBigEndianInt64() -> Int64? {
		return readNextInteger(bigEndian: true)
	}

	func readNextLittleEndianInt64() -> Int64? {
		return readNextInteger(bigEndian: false)
	}

	func readNextAvailableData() -> Data? {
		return readNextDataOfLength(remainingBytesLength)
	}

	func readNextDataOfLength(_ length: Int) -> Data? {
		guard
			length > 0
			else { return nil }

		guard
			internalData.count >= length
			else { return nil }

		let data = internalData.subdata(in: 0..<length)
		internalData.removeSubrange(0..<length)
		return data
	}

	// MARK: Internal methods

	fileprivate func readNextInteger<T: BinaryInteger>() -> T? {
		guard
			let data = readNextDataOfLength(MemoryLayout<T>.size)
			else { return nil }

		return data.withUnsafeBytes({ $0.pointee })
	}

	fileprivate func readNextInteger<T: FixedWidthInteger>(bigEndian: Bool) -> T? {
		guard
			let data = readNextDataOfLength(MemoryLayout<T>.size)
			else { return nil }

		let value: T = data.withUnsafeBytes({ $0.pointee })
		return bigEndian ? value.bigEndian : value.littleEndian
	}

	// MARK: Initialization

	init(data: Data) {
		self.internalData = data
	}
}
