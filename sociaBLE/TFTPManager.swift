//
//  TFTPManager.swift
//  sociaBLE
//
//  Created by James Choi on 2021/04/14.
//

import Foundation
import UIKit

class TFTPManager: NSObject, FileManagerDelegate {

    let fileManager = FileManager.default
    let url: URL?
    var justSent: UInt16?
    var sendQueue: [DataPacket] = []
    var receivedData = Data()
    var newMessage: TFTPMessage!

    var writeTarget: URL?

    override init() {
        url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let image1 = UIImage(named: "test1")
            let data1 = image1?.pngData()
            if let target1 = url?.appendingPathComponent("test1.png") {
                try data1?.write(to: target1)
            }
            let image2 = UIImage(named: "test2")
            let data2 = image2?.pngData()
            if let target2 = url?.appendingPathComponent("test2.png") {
                try data2?.write(to: target2)
            }
            let image3 = UIImage(named: "test3")
            let data3 = image3?.jpegData(compressionQuality: 0.8)
            if let target3 = url?.appendingPathComponent("test3.jpeg") {
                try data3?.write(to: target3)
            }
        } catch {
            print("Error")
        }
    }

    func receiveCommand(commands: [Substring]) -> TFTPMessage {
        let commandError = StringMessage(string:
                                            "Invalid command, type \"TFTP help\" in order to see the list of commands")
        if commands[0] == "TFTP" && commands.count > 1 {
            switch commands[1] {
            case "help",
                 "list",
                 "open",
                 "clear":
                return showSystemMessage(commands: commands)
            case "read",
                 "write":
                if commands.count == 3 {
                    let packet = RequestPacket(opCode: commands[1] == "read" ? 1 : 2,
                                               fileName: String(commands[2]),
                                               mode: "octet")
                    return sendPacket(packet: packet)
                } else {
                    return commandError
                }
            default:
                return commandError
            }
        } else {
            return commandError
        }
    }

    func showSystemMessage(commands: [Substring]) -> TFTPMessage {
        switch commands[1] {
        case "help":
            return StringMessage(string: """
                TFTP commands:
                TFTP help : list services provided by TFTP
                TFTP list : list files on current device
                TFTP clear: delete all files on current device
                TFTP open fileName : open the file with its name equal to fileName
                TFTP read . : request for the list of files from another device
                TFTP read fileName : request to download the file with fileName from another device
                TFTP write fileName : request to upload the file with fileName to another device
                """)
        case "list":
            do {
                if let url = url {
                    let contents = try fileManager.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: [],
                                                                       options: .skipsHiddenFiles)
                    if contents.count == 0 {
                        return StringMessage(string: "No files found")
                    } else {
                        var list = ""
                        for content in contents {
                            list.append(fileManager.displayName(atPath: content.path) + "\n")
                        }
                        return StringMessage(string: list)
                    }
                }
            } catch {
                return StringMessage(string: "Error")
            }
        case "open":
            do {
                if let url = url {
                    let contents = try fileManager.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: [],
                                                                       options: .skipsHiddenFiles)
                    var target: URL?
                    for content in contents {
                        if fileManager.displayName(atPath: content.path) == commands[2] {
                            target = content
                            break
                        }
                    }
                    if let target = target, let data = fileManager.contents(atPath: target.path) {
                        return OpenImageMessage(imageData: data)
                    } else {
                        return StringMessage(string: "No such file found on this device")
                    }
                }
            } catch {
                return StringMessage(string: "Error")
            }
        case "clear":
            do {
                if let url = url {
                    let contents = try fileManager.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: [],
                                                                       options: .skipsHiddenFiles)
                    for content in contents {
                        try fileManager.removeItem(at: content)
                    }
                    return StringMessage(string: "All your files are deleted")
                }
            } catch {
                return StringMessage(string: "Error")
            }
        default:
            return StringMessage(string: "Invalid command, type \"TFTP help\" in order to see the list of commands")
        }
        return StringMessage(string: "Error")
    }

    func sendPacket(packet: TFTPPacket) -> TFTPMessage {
        let opCode = packet.opCode
        switch opCode {
        case 1:
            let requestPacket = packet as? RequestPacket
            return sendRead(packet: requestPacket!)
        case 2:
            let requestPacket = packet as? RequestPacket
            return sendWrite(packet: requestPacket!)
        case 3:
            let dataPacket = packet as? DataPacket
            return sendData(packet: dataPacket!)
        case 4:
            let ackPacket = packet as? ACKPacket
            return sendACK(packet: ackPacket!)
        default:
            return StringMessage(string: "Invalid packet")
        }
    }

    func receivePacket(packet: TFTPPacket) {
        let opCode = packet.opCode
        switch opCode {
        case 1:
            let requestPacket = packet as? RequestPacket
            receiveRead(packet: requestPacket!)
        case 2:
            let requestPacket = packet as? RequestPacket
            receiveWrite(packet: requestPacket!)
        case 3:
            let dataPacket = packet as? DataPacket
            receiveData(packet: dataPacket!)
        case 4:
            let ackPacket = packet as? ACKPacket
            receiveACK(packet: ackPacket!)
        default:
            print("Invalid packet")
        }
    }

    func sendRead(packet: RequestPacket) -> TFTPMessage {
        return PacketMessage(packetData: packet.toData())
    }

    func sendWrite(packet: RequestPacket) -> TFTPMessage {
        do {
            if let url = url {
                let contents = try fileManager.contentsOfDirectory(at: url,
                                                                   includingPropertiesForKeys: [],
                                                                   options: .skipsHiddenFiles)
                var target: URL!
                for content in contents {
                    if packet.fileName == fileManager.displayName(atPath: content.path) {
                        target = content
                        break
                    }
                }
                if target == nil {
                    return StringMessage(string: "Error: file not found")
                } else {
                    let data = fileManager.contents(atPath: target.path)!
                    var packets = TFTPPacket.makeDataPackets(data)
                    while !packets.isEmpty {
                        sendQueue.append(packets.removeFirst())
                    }
                    return PacketMessage(packetData: packet.toData())
                }
            }
        } catch {
            return StringMessage(string: "Error")
        }
        return StringMessage(string: "Error")
    }

    func sendData(packet: DataPacket) -> TFTPMessage {
        justSent = packet.blockNumber
        return PacketMessage(packetData: packet.toData())
    }

    func sendACK(packet: ACKPacket) -> TFTPMessage {
        return PacketMessage(packetData: packet.toData())
    }

    func receiveRead(packet: RequestPacket) {
        if packet.fileName == "." {
            do {
                if let url = url {
                    let contents = try fileManager.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: [],
                                                                       options: .skipsHiddenFiles)
                    if contents.count == 0 {
                        newMessage = SendTextMessage(text: "No files found")
                        return
                    } else {
                        var list = ""
                        for content in contents {
                            list.append(fileManager.displayName(atPath: content.path) + "\n")
                        }
                        newMessage = SendTextMessage(text: list)
                        return
                    }
                }
            } catch {
                newMessage = SendTextMessage(text: "Error")
                return
            }
        } else {
            if let fileName = packet.fileName, let mode = packet.mode {
                newMessage = sendWrite(packet: RequestPacket(opCode: UInt16(2),
                                                             fileName: fileName,
                                                             mode: mode))
            }
        }
    }

    func receiveWrite(packet: RequestPacket) {
        if let fileName = packet.fileName {
            writeTarget = url?.appendingPathComponent(fileName)
            newMessage = sendACK(packet: ACKPacket(opCode: 4, blockNumber: UInt16(0)))
        }
    }

    func receiveData(packet: DataPacket) {
        if let contentData = packet.contentData, let blockNumber = packet.blockNumber {
            receivedData.append(contentData)
            newMessage = sendACK(packet: ACKPacket(opCode: 4, blockNumber: blockNumber))
            if contentData.count < DATAMAXLEN {
                finishedReceivingData()
            }
        }
    }

    func receiveACK(packet: ACKPacket) {
        if packet.blockNumber == 0 || packet.blockNumber == justSent {
            newMessage = sendFromQueue()
        } else {
            newMessage = StringMessage(string: "Wrong ACK received")
        }
    }

    func sendFromQueue() -> TFTPMessage {
        if !sendQueue.isEmpty {
            let packet = sendQueue.removeFirst()
            return sendData(packet: packet)
        }
        return StringMessage(string: "Transfer complete")
    }

    func finishedReceivingData() {
        do {
            if let writeTarget = writeTarget {
                try receivedData.write(to: writeTarget)
                receivedData = Data()
            }
        } catch {
            print("Error")
        }
    }
}

class TFTPMessage {
    var opCode: UInt8 // 1 = string, 2 = packet, 3 = open image, 4 = sendText

    init(opCode: UInt8) {
        self.opCode = opCode
    }
}

class StringMessage: TFTPMessage {
    var string: String?

    init(string: String) {
        super.init(opCode: 1)
        self.string = string
    }
}

class PacketMessage: TFTPMessage {
    var packetData: Data?

    init(packetData: Data) {
        super.init(opCode: 2)
        self.packetData = packetData
    }
}

class OpenImageMessage: TFTPMessage {
    var imageData: Data?

    init(imageData: Data) {
        super.init(opCode: 3)
        self.imageData = imageData
    }
}

class SendTextMessage: TFTPMessage {
    var text: String?

    init(text: String) {
        super.init(opCode: 4)
        self.text = text
    }
}
