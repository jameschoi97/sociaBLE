import Foundation
import CoreBluetooth

class BLECentralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: Singleton
    static let centralManager = BLECentralManager()
    // MARK: Properties
    var myCentral: CBCentralManager?
    var myPeripheral: CBPeripheral?
    var myService: CBService?
    var myCharacteristic: CBCharacteristic?
    var updateStatus: (() -> Void)?
    var showErrorMessage: (() -> Void)?
    var moveToChat: (() -> Void)?
    var updateChat: ((String) -> Void)?
    var updateDevices: (([(String?, CBPeripheral)]) -> Void)?
    var showImage: ((Data) -> Void)?
    let myUUID = CBUUID(string: "B40C03E0-74A0-486C-A82F-3CEC63931823")

    var tftpManager = TFTPManager()
    var packets: [Packet] = []
    var tftpPackets: [Packet] = []
    var packetQueue: [Packet] = []
    var lastSent: Packet?

    @Published var isSwitchedOn = false
    @Published var foundService = false
    @Published var foundChracteristic = false
    @Published var peripherals = [(String?, CBPeripheral)]()
    
    private override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
        } else {
            isSwitchedOn = false
        }
        updateStatus?()
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let pid = advertisementData["kCBAdvDataLocalName"] as? String
        peripherals.append((pid, peripheral))
        updateDevices?(peripherals)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        myCentral?.stopScan()
        myPeripheral = peripheral
        myPeripheral?.delegate = self
        myPeripheral?.discoverServices([myUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let service = myPeripheral?.services?[0] {
            myService = service
            foundService = true
            myPeripheral?.discoverCharacteristics([myUUID], for: service)
        } else {
            showErrorMessage?()
            disconnectFrom(myPeripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristic = myService?.characteristics?[0] {
            myCharacteristic = characteristic
            foundChracteristic = true
            myPeripheral?.setNotifyValue(true, for: characteristic)
            moveToChat?()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error)
        } else {
            sendFromQueue()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let data = characteristic.value
        readData(data!)
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        if let data: Data = lastSent?.toData(), let myCharacteristic = myCharacteristic {
            myPeripheral?.writeValue(data, for: myCharacteristic, type: .withResponse)
        }
    }

    func connectTo(_ peripheral: CBPeripheral) {
        print("trying to connect")
        myCentral?.connect(peripheral, options: nil)
    }

    func disconnectFrom(_ peripheral: CBPeripheral?) {
        if let peripheral = peripheral {
            myCentral?.cancelPeripheralConnection(peripheral)
            myPeripheral = nil
            myService = nil
            myCharacteristic = nil
        }
    }

    func exitingChat() {
        if let myPeripheral = myPeripheral, let _ = myService, let myCharacteristic = myCharacteristic {
            myPeripheral.setNotifyValue(false, for: myCharacteristic)
            disconnectFrom(myPeripheral)
        }
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
        if !packetQueue.isEmpty {
            let packet = packetQueue.removeFirst()
            let data: Data = packet.toData()
            lastSent = packet
            if let myCharacteristic = myCharacteristic {
                myPeripheral?.writeValue(data, for: myCharacteristic, type: .withResponse)
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
                updateChat?(str)
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
                    updateChat?(string)
                }
            }
        case 2:
            if let packetMessage = message as? PacketMessage {
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
