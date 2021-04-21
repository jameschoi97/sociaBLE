//
//  ChatImageViewController.swift
//  sociaBLE
//
//  Created by James Choi on 2021/04/15.
//

import UIKit

class ChatImageViewController: UIViewController {

    @IBOutlet weak var chatImage: UIImageView!

    var image: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        chatImage.image = UIImage(named: "noImage")
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showImage()
    }

    func showImage() {
        chatImage.image = image
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
