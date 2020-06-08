//
//  OneTimeViewController.swift
//  GateControl 2
//
//  Created by Book Lailert on 14/2/20.
//  Copyright © 2020 Book Lailert. All rights reserved.
//

import UIKit
import Firebase

class OneTimeViewController: UIViewController {
    
    let baseLink:String = "www.bkpgroup.net/gatecontroller.html"

    override func viewDidLoad() {
        super.viewDidLoad()
        linkDisplay.text = baseLink
        codeDisplay.text = "Generating Code..."
        let start = UserDefaults.standard.object(forKey: "startTime") as? NSDate
        validFrom.text = stringFromDate(start! as Date)
        let end = UserDefaults.standard.object(forKey: "endTime") as? NSDate
        validTo.text = stringFromDate(end! as Date)
        let limitVal = UserDefaults.standard.integer(forKey: "limit")
        limit.text = String(limitVal)
        let targetGate = UserDefaults.standard.string(forKey: "selectedGate")
        registerOneTime(start: start!, end: end!, limitTrigger: limitVal, target: targetGate!)
        shareButton.isEnabled = false
        // Do any additional setup after loading the view.
    }
    
    @IBOutlet var shareButton: UIButton!
    
    func failureNotification(title:String, description:String) {
        let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    
    func generateQR(identifier:String) {
        let link = baseLink + "?code=" + identifier
        
        let data = link.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 15, y: 15)

            if let output = filter.outputImage?.transformed(by: transform) {
                codeDisplay.text = identifier
                qrDisplay.image? = UIImage(ciImage: output)
            } else {
                self.failureNotification(title: "QR Code Generation Failed", description: "Enter the code manually or retry later.")
            }
        } else {
            self.failureNotification(title: "QR Code Generation Failed", description: "Enter the code manually or retry later.")
        }
        shareButton.isEnabled = true
    }
    
    
    func waitRegister(identifier:String) {
        Firestore.firestore().collection("oneTimeAddRequest").document(currentUser!.uid).addSnapshotListener { (snapshot, error) in
            if let error = error {
                self.failureNotification(title: "Failed to generate QR code", description: "Unable to access request")
                print(error)
                self.navigationController?.popViewController(animated: true)
            } else {
                if let document = snapshot {
                    if let data = document.data() {
                        if data.keys.contains("success")  {
                            if (data["success"] as? Bool)! {
                                self.cover.isHidden = true
                                self.generateQR(identifier: identifier)
                                document.reference.delete()
                            } else {
                                self.failureNotification(title: "Failed to generate QR code", description: "Insufficient Permission")
                                self.navigationController?.popViewController(animated: true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func registerOneTime(start:NSDate, end:NSDate, limitTrigger:Int, target:String) {
        let identifier = randomString(length: 10)
        Firestore.firestore().collection("oneTimeAddRequest").document(currentUser!.uid).setData(["start": start as Any, "end": end as Any, "limit": limitTrigger as Any, "target": target, "identifier": identifier]) { (error) in
            if let error = error {
                self.failureNotification(title: "Failed to generate QR code", description: "Please try again later.")
                print(error)
                self.navigationController?.popViewController(animated: true)
            } else {
                self.waitRegister(identifier: identifier)
            }
        }
        
    }
    
    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    func stringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HH:mm" //yyyy
        return formatter.string(from: date)
    }
    
    @IBOutlet var validFrom: UILabel!
    @IBOutlet var validTo: UILabel!
    @IBOutlet var limit: UILabel!
    @IBOutlet var qrDisplay: UIImageView!
    @IBOutlet var codeDisplay: UILabel!
    @IBOutlet var linkDisplay: UILabel!
    @IBOutlet var cover: UIVisualEffectView!
    
    @IBAction func share(_ sender: Any) {
        let firstActivityItem = NSURL(string: linkDisplay.text! + "?code=" + codeDisplay.text!)
        let image : UIImage? = qrDisplay.image!

        if image != nil {
            let activityViewController : UIActivityViewController = UIActivityViewController(activityItems: [firstActivityItem as Any, image as Any], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = (sender as! UIButton)

            // This line remove the arrow of the popover to show in iPad
            activityViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.down
            activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 150, y: 150, width: 0, height: 0)

            // Anything you want to exclude
            activityViewController.excludedActivityTypes = [
                UIActivity.ActivityType.postToWeibo,
                UIActivity.ActivityType.print,
                UIActivity.ActivityType.saveToCameraRoll,
                UIActivity.ActivityType.assignToContact,
                UIActivity.ActivityType.addToReadingList,
                UIActivity.ActivityType.postToFlickr,
                UIActivity.ActivityType.postToVimeo,
                UIActivity.ActivityType.postToTencentWeibo
            ]

            self.present(activityViewController, animated: true, completion: nil)
        }

        // This lines is for the popover you need to show in iPad
        
        
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
