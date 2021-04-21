//
//  BLEManager.swift
//  sociaBLE
//
//  Created by James Choi on 2021/04/08.
//

import Foundation
import CoreBluetooth

class BLEPeripheralManager: NSObject, CBPeripheralManagerDelegate {
    // MARK: Singleton
    static let peripheralManager = BLEPeripheralManager()
    // MARK: Properties
    var myPManager: CBPeripheralManager?
    var subscribing: CBCentral?
    var myCharacteristic: CBMutableCharacteristic?
    var updatePChat: ((String) -> Void)?
    let myUUID = CBUUID(string: "B40C03E0-74A0-486C-A82F-3CEC63931823")
    var userID: String?
    var showImage: ((Data) -> Void)?
    var tftpManager = TFTPManager()
    var packets: [Packet] = []
    var tftpPackets: [Packet] = []
    var packetQueue: [Packet] = []

    private override init() {
        super.init()
        myPManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        return
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        subscribing = central
        myPManager?.stopAdvertising()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        startAdvertising(self.userID ?? "Anonymous User")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        myPManager?.respond(to: requests[0], withResult: CBATTError.success)
        if let data = requests[0].value {
            readData(data)
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendFromQueue()
    }

    func startAdvertising(_ userID: String) {
        self.userID = userID
        print("Advertising with \(userID)")
        myCharacteristic = CBMutableCharacteristic(type: myUUID,
                                                    properties: [.notify, .read, .write, .writeWithoutResponse],
                                                    value: nil,
                                                    permissions: [.readable, .writeable])
        let advertisingService = CBMutableService(type: myUUID, primary: true)
        if let myCharacteristic = myCharacteristic {
            advertisingService.characteristics = [myCharacteristic]
            myPManager?.add(advertisingService)
            myPManager?.startAdvertising([CBAdvertisementDataLocalNameKey: userID,
                                         CBAdvertisementDataServiceUUIDsKey: [myUUID]])
        }
    }

    func exitingChat() {
        if myPManager?.isAdvertising ?? false {
            myPManager?.stopAdvertising()
        }
        myPManager?.removeAllServices()
    }

    func sendData(_ str: String) {
        var packets = Packet.makePackets(str)
        while !packets.isEmpty {
            packetQueue.append(packets.removeFirst())
        }
        sendFromQueue()
    }

    func sendData(_ data: Data) {
        var packets = Packet.makePackets(data)
        while !packets.isEmpty {
            packetQueue.append(packets.removeFirst())
        }
        sendFromQueue()
    }

    func sendFromQueue() {
        while !packetQueue.isEmpty {
            let packet = packetQueue.removeFirst()
            let data: Data = packet.toData()
            if let myCharacteristic = myCharacteristic, let subscribing = subscribing {
                let sent = myPManager?.updateValue(data, for: myCharacteristic, onSubscribedCentrals: [subscribing]) ?? false
                if !sent {
                    packetQueue.insert(packet, at: 0)
                    return
                }
            }
        }
    }

    func readData(_ data: Data) {
        let packet = Packet(data: data)
        if packet.payloadType == 1 {
            self.packets.append(packet)
            if packet.totalPackets == packet.transactionNumber {
                let str = packetsToString(self.packets)
                self.packets = []
                updatePChat?(str)
            }
        } else if packet.payloadType == 3 {
            self.tftpPackets.append(packet)
            if packet.totalPackets == packet.transactionNumber {
                let tftpPacket = packetstoTFTPPacket(self.tftpPackets)
                self.tftpPackets = []
                tftpManager.receivePacket(packet: tftpPacket)
                handleTFTPMessage(tftpManager.newMessage)
            }
        }
    }

    func packetsToString(_ packets: [Packet]) -> String {
        var data = Data()
        for packet in packets {
            data.append(packet.payload)
        }
        return String(decoding: data, as: UTF8.self)
    }

    func packetstoTFTPPacket(_ packets: [Packet]) -> TFTPPacket {
        var data = Data()
        for packet in packets {
            data.append(packet.payload)
        }
        return TFTPPacket.makePacketFromData(data: data)!
    }

    func handleTFTPMessage(_ message: TFTPMessage) {
        switch message.opCode {
        case 1:
            if let stringMessage = message as? StringMessage {
                if let string = stringMessage.string {
                    updatePChat?(string)
                }
            }
        case 2:
            if let packetMessage = message as? PacketMessage, let _ = subscribing {
                if let packetData = packetMessage.packetData {
                    sendData(packetData)
                }
            }
        case 3:
            if let openImageMessage = message as? OpenImageMessage {
                if let imageData = openImageMessage.imageData {
                    showImage?(imageData)
                }
            }
        case 4:
            if let sendTextMessage = message as? SendTextMessage {
                if let text = sendTextMessage.text {
                    sendData(text)
                }
            }
        default:
            print("nothing")
        }
    }
}
