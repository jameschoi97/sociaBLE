//
//  HomeViewController.swift
//  sociaBLE
//
//  Created by James Choi on 2021/04/08.
//

import UIKit
import CoreBluetooth

var periCount = 0

class HomeViewController: UIViewController, UITextFieldDelegate {

    // MARK: Properties
    lazy var bleManager = BLECentralManager.centralManager
    lazy var blePManager = BLEPeripheralManager.peripheralManager
    var tableController: DeviceTableViewController?
    var userID: String?
    @IBOutlet weak var status: UITextView!
    @IBOutlet weak var idField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "sociaBLE"
        idField.delegate = self

        bleManager.updateStatus = {
            if self.bleManager.isSwitchedOn {
                self.status.text = "Bluetooth is switched on"
                self.status.textColor = .green
            } else {
                self.status.text = "Bluetooth is NOT switched on"
                self.status.textColor = .red
            }
        }

        bleManager.showErrorMessage = {
            let alert = UIAlertController(title: "Error",
                                          message: "Your selected device does not support sociaBLE",
                                          preferredStyle: .alert)

            // add an action (button)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

            // show the alert
            self.present(alert, animated: true, completion: nil)

            // deselect row
            self.tableController?.tableView.deselectRow(at: (self.tableController?.tableView.indexPathForSelectedRow)!,
                                                        animated: false)
        }

        bleManager.moveToChat = {
            self.performSegue(withIdentifier: "SegueToChat", sender: self)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        userID = textField.text
        self.view.endEditing(true)
        resignFirstResponder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textFieldDidEndEditing(textField)
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is DeviceTableViewController {
            tableController = segue.destination as? DeviceTableViewController
        }
        if segue.destination is PChatViewController {
            let PChatController = segue.destination as? PChatViewController
            PChatController?.userID = idField.text
        }
    }

    // MARK: Actions

    @IBAction func scanButton(_ sender: UIButton) {
        bleManager.peripherals = []
        bleManager.updateDevices = {(_ peripherals: [(String?, CBPeripheral)]) -> Void in
            for peripheral in peripherals {
                self.tableController?.devices = []
                let data = (name: peripheral.0 ?? "Anonymous User", peripheral: peripheral.1)
                self.tableController?.devices.append(data)
                self.tableController?.tableView.reloadData()
            }
        }
        bleManager.myCentral?.scanForPeripherals(withServices: [bleManager.myUUID], options: nil)
    }

    @IBAction func createRoomButton(_ sender: UIButton) {
        performSegue(withIdentifier: "SegueToPChat", sender: self)
        blePManager.startAdvertising(userID ?? "Anonymous User")
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
