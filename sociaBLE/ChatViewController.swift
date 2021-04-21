//
//  ChatViewController.swift
//  sociaBLE
//
//  Created by James Choi on 2021/04/08.
//

import UIKit
import MessageKit
import InputBarAccessoryView

class ChatViewController: MessagesViewController,
                          MessagesDataSource,
                          MessagesLayoutDelegate,
                          MessagesDisplayDelegate,
                          InputBarAccessoryViewDelegate {

    var imageViewController: ChatImageViewController?

    var currentUser = Sender(senderId: "self", displayName: "userName")
    var otherUser = Sender(senderId: "other", displayName: "userName")

    var messages = [MessageType]()
    var messageID = 0
    var userID: String?

    func getID () -> Int {
        messageID += 1
        return messageID
    }

    lazy var bleManager = BLECentralManager.centralManager

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(title: "Home", style: .plain, target: self, action: #selector(back))
        self.navigationItem.leftBarButtonItem = newBackButton

        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        scrollsToLastItemOnKeyboardBeginsEditing = true
        maintainPositionOnKeyboardFrameChanged = true

        bleManager.updateChat = {(_ str: String) -> Void in
            self.messages.append(Message(sender: self.otherUser,
                                         messageId: "\(self.getID())",
                                         sentDate: Date(),
                                         kind: .text(str)))
            self.messagesCollectionView.reloadData()
        }

        bleManager.showImage = {(_ data: Data) -> Void in
            let image = UIImage(data: data)
            self.performSegue(withIdentifier: "SegueToChatImage", sender: self)
            self.imageViewController?.image = image
        }

        // remove Avatars for our chat, we don't need them
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.textMessageSizeCalculator.incomingAvatarSize = .zero
        }
    }

    @objc func back(sender: UIBarButtonItem) {
        bleManager.exitingChat()
        self.navigationController?.popViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is ChatImageViewController {
            imageViewController = segue.destination as? ChatImageViewController
        }
    }

    func currentSender() -> SenderType {
        return currentUser
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }

    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }

    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        messages.append(Message(sender: currentUser,
                                messageId: "\(getID())",
                                sentDate: Date(),
                                kind: .text(text)))
        let tokens = text.split(separator: " ")
        if tokens[0] == "TFTP" {
            let tftpMessage = bleManager.tftpManager.receiveCommand(commands: tokens)
            bleManager.handleTFTPMessage(tftpMessage)
        } else {
            bleManager.sendData(text)
        }
        messagesCollectionView.reloadData()
        inputBar.inputTextView.text = ""
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
