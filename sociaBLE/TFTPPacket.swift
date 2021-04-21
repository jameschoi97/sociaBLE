//
//  TFTPPacket.swift
//  sociaBLE
//
//  Created by James Choi on 2021/04/13.
//

import Foundation

let TFTPMAXLEN = 512
let DATAMAXLEN = TFTPMAXLEN - 4

class TFTPPacket {
    var opCode: UInt16?

    init(opCode: UInt16) {
        self.opCode = opCode
    }

    func toData() -> Data {
        return Data(bytes: &opCode, count: MemoryLayout<UInt16>.size)
    }

    static func makePacketFromData(data: Data) -> TFTPPacket? {
        let index = data.index(data.startIndex, offsetBy: MemoryLayout<UInt16>.size)
        let opCodeData = data[..<index]
        let i16array = opCodeData.withUnsafeBytes {
            Array($0.bindMemory(to: UInt16.self)).map(UInt16.init(littleEndian:))
        }
        let opCode = i16array[0]
        let newData = data.dropFirst(2)
        switch opCode {
        case 1,
             2:
            var indices: [Int] = []
            for (byteIndex, byte) in newData.enumerated() where byte == 0 {
                indices.append(byteIndex)
            }
            let ix2 = newData.index(newData.startIndex, offsetBy: indices[0])
            let ix3 = newData.index(newData.startIndex, offsetBy: indices[0]+1)
            let ix4 = newData.index(newData.startIndex, offsetBy: indices[1])
            let fileNameData = newData[..<ix2]
            let modeData = newData[ix3..<ix4]
            let fileName = String(decoding: fileNameData, as: UTF8.self)
            let mode = String(decoding: modeData, as: UTF8.self)
            return RequestPacket(opCode: opCode, fileName: fileName, mode: mode)
        case 3:
            let ix2 = newData.index(newData.startIndex, offsetBy: MemoryLayout<UInt16>.size)
            let blockNumberData = newData[..<ix2]
            let i16array = blockNumberData.withUnsafeBytes {
                Array($0.bindMemory(to: UInt16.self)).map(UInt16.init(littleEndian:))
            }
            let blockNumber = i16array[0]
            let packetData = newData[ix2...]
            return DataPacket(opCode: opCode, blockNumber: blockNumber, data: packetData)
        case 4:
            let i16array = newData.withUnsafeBytes {
                Array($0.bindMemory(to: UInt16.self)).map(UInt16.init(littleEndian:))
            }
            let blockNumber = i16array[0]
            return ACKPacket(opCode: opCode, blockNumber: blockNumber)
        default:
            return nil
        }
    }

    static func makeDataPackets(_ data: Data) -> [DataPacket] {
        let totalLen = data.count
        let numberOfPackets = totalLen/DATAMAXLEN + 1
        var packets: [DataPacket] = []
        for blockNumber in 1...numberOfPackets {
            let contentLen = min(totalLen-(blockNumber-1)*DATAMAXLEN, DATAMAXLEN)
            let index = data.index(data.startIndex, offsetBy: (blockNumber-1)*DATAMAXLEN)
            let index2 = data.index(index, offsetBy: contentLen)
            let content = data[index..<index2]
            packets.append(DataPacket(opCode: 3, blockNumber: UInt16(blockNumber), data: content))
        }
        return packets
    }
}

class RequestPacket: TFTPPacket {
    var fileName: String?
    let empty = Data([0x00])
    var mode: String?
    let empty2 = Data([0x00])

    init(opCode: UInt16, fileName: String, mode: String) {
        super.init(opCode: opCode)
        self.fileName = fileName
        self.mode = mode
    }

    override func toData() -> Data {
        var data = super.toData()
        if let fileName = fileName, let mode = mode {
            data.append(fileName.data(using: .utf8)!)
            data.append(empty)
            data.append(mode.data(using: .utf8)!)
            data.append(empty)
        }
        return data
    }
}

class DataPacket: TFTPPacket {
    var blockNumber: UInt16?
    var contentData: Data?
    init(opCode: UInt16, blockNumber: UInt16, data: Data) {
        super.init(opCode: opCode)
        self.blockNumber = UInt16(blockNumber)
        self.contentData = data
    }

    override func toData() -> Data {
        var data = super.toData()
        if var blockNumber = blockNumber, let contentData = contentData {
            data.append(Data(bytes: &blockNumber, count: MemoryLayout<UInt16>.size))
            data.append(contentData)
        }
        return data
    }
}

class ACKPacket: TFTPPacket {
    var blockNumber: UInt16?

    init(opCode: UInt16, blockNumber: UInt16) {
        super.init(opCode: opCode)
        self.blockNumber = UInt16(blockNumber)
    }

    override func toData() -> Data {
        var data = super.toData()
        if var blockNumber = blockNumber {
            data.append(Data(bytes: &blockNumber, count: MemoryLayout<UInt16>.size))
        }
        return data
    }
}
