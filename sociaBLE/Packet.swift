//
//  Packet.swift
//  sociaBLE
//
//  Created by James Choi on 2021/04/12.
//

import Foundation

let MAXLEN = 182

class Packet {
    let payloadLen: UInt8
    var totalPackets: UInt16
    var transactionNumber: UInt16
    let payloadType: UInt8
    let payload: Data

    init(payloadLen: Int, totalPackets: Int, transactionNumber: Int, payloadType: Int, payload: Data) {
        self.payloadLen = UInt8(payloadLen)
        self.totalPackets = UInt16(totalPackets)
        self.transactionNumber = UInt16(transactionNumber)
        self.payloadType = UInt8(payloadType)
        self.payload = payload
    }

    init(data: Data) {
        let ix1 = data.index(data.startIndex, offsetBy: MemoryLayout<UInt8>.size)
        let ix2 = data.index(ix1, offsetBy: MemoryLayout<UInt16>.size)
        let ix3 = data.index(ix2, offsetBy: MemoryLayout<UInt16>.size)
        let ix4 = data.index(ix3, offsetBy: MemoryLayout<UInt8>.size)
        let payloadLenData = data[..<ix1]
        let totalPacketsData = data[ix1..<ix2]
        let transactionNumberData = data[ix2..<ix3]
        let payloadTypeData = data[ix3..<ix4]
        var payloadLenHolder: UInt8 = 0
        payloadLenData.copyBytes(to: &payloadLenHolder, count: MemoryLayout<UInt8>.size)
        self.payloadLen = payloadLenHolder
        let i16array = totalPacketsData.withUnsafeBytes {
            Array($0.bindMemory(to: UInt16.self)).map(UInt16.init(littleEndian:))
        }
        self.totalPackets = i16array[0]
        let i16array2 = transactionNumberData.withUnsafeBytes {
            Array($0.bindMemory(to: UInt16.self)).map(UInt16.init(littleEndian:))
        }
        self.transactionNumber = i16array2[0]
        var payloadTypeHolder: UInt8 = 0
        payloadTypeData.copyBytes(to: &payloadTypeHolder, count: MemoryLayout<UInt8>.size)
        self.payloadType = payloadTypeHolder
        self.payload = data[ix4...]
    }

    static func makePackets(_ str: String) -> [Packet] {
        if let data: Data = str.data(using: .utf8) {
            let totalLen = data.count
            let dataSize = MAXLEN-6
            let totalPackets = (totalLen-1)/dataSize + 1
            var packets: [Packet] = []
            for packetNumber in 1...totalPackets {
                let payloadLen = min(totalLen-(packetNumber-1)*dataSize, dataSize) + 1
                let index = data.index(data.startIndex, offsetBy: (packetNumber-1)*dataSize)
                let index2 = data.index(index, offsetBy: payloadLen-1)
                let payload = data[index..<index2]
                packets.append(Packet(payloadLen: payloadLen,
                                      totalPackets: totalPackets,
                                      transactionNumber: packetNumber,
                                      payloadType: 1,
                                      payload: payload))
            }
            return packets
        } else {
            return []
        }
        
    }

    static func makePackets(_ data: Data) -> [Packet] {
        let totalLen = data.count
        let dataSize = MAXLEN-6
        let totalPackets = (totalLen-1)/dataSize + 1
        var packets: [Packet] = []
        for packetNumber in 1...totalPackets {
            let payloadLen = min(totalLen-(packetNumber-1)*dataSize, dataSize) + 1
            let index = data.index(data.startIndex, offsetBy: (packetNumber-1)*dataSize)
            let index2 = data.index(index, offsetBy: payloadLen-1)
            let payload = data[index..<index2]
            packets.append(Packet(payloadLen: payloadLen,
                                  totalPackets: totalPackets,
                                  transactionNumber: packetNumber,
                                  payloadType: 3,
                                  payload: payload))
        }
        return packets
    }

    func toData() -> Data {
        var data = Data()
        data.append(self.payloadLen)
        data.append(Data(bytes: &self.totalPackets, count: MemoryLayout<UInt16>.size))
        data.append(Data(bytes: &self.transactionNumber, count: MemoryLayout<UInt16>.size))
        data.append(self.payloadType)
        data.append(self.payload)
        return data
    }
}
