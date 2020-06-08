//
//  ControllerViewController.swift
//  GateControl 2
//
//  Created by Book Lailert on 13/2/20.
//  Copyright © 2020 Book Lailert. All rights reserved.
//

import UIKit
import Firebase

class CircleButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let circlePath = UIBezierPath(ovalIn: self.bounds)
        
        return circlePath.contains(point)
    }
}

class ControllerViewController: UIViewController {
    
    var selectedGate = ""
    var gateList = [String:String]()
    let database = Firestore.firestore()
    var moving = false
    var doorOpened = false
    var requesting = false
    


    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
        self.triggerButton.isEnabled = false
        self.triggerButton.layer.cornerRadius = self.triggerButton.frame.width/2
        self.triggerButton.clipsToBounds = true
        self.view.bringSubviewToFront(buttonText)
        getGateData { (data) in
            self.triggerButton.isEnabled = true
            if let currentGate = UserDefaults.standard.string(forKey: "selectedGate") {
                self.selectedGate = currentGate
            } else {
                self.selectedGate = Array(self.gateList.keys)[0]
                UserDefaults.standard.set(Array(self.gateList.keys)[0], forKey: "selectedGate")
            }
            self.title = self.gateList[self.selectedGate]
            self.initListener()
        }
        // Do any additional setup after loading the view.
    }
    
    
    func initListener() {
        database.collection("gates").document(self.selectedGate).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            guard let data = document.data() else {
                print("Document data was empty.")
                return
            }
            self.handleDataChange(data: data)
        }
    }
    
    func handleDataChange(data:[String:Any]) {
        if let enabled = data["enabled"] as? Bool{
            if enabled{
                self.title = data["friendlyName"] as? String
                self.statusText.text = "Connected"
                triggerButton.isEnabled = true
                doorOpened = data["open"] as! Bool
                moving = data["moving"] as! Bool
                var status = ""
                if let currentStatus = data["status"] as? String {
                    statusText.text = currentStatus
                    status = currentStatus
                }
                
                if data["moving"] as! Bool && data["status"] as! String != "Cancelling..." {
                    buttonText.text = "Stop"
                    triggerButton.setImage(UIImage(named: "Red Cancel"), for: .normal)
                } else if !(data["moving"] as! Bool) && data["open"] as! Bool && !(data["request"] as! Bool) {
                    buttonText.text = "Close Gate"
                    triggerButton.setImage(UIImage(named: "Green Open"), for: .normal)
                    requesting = false
                } else if !(data["moving"] as! Bool) && !(data["open"] as! Bool) && !(data["request"] as! Bool) {
                    buttonText.text = "Open Gate"
                    triggerButton.setImage(UIImage(named: "Green Open"), for: .normal)
                    requesting = false
                } else if status == "Cancelling..." {
                    buttonText.text = "Cancelling"
                    triggerButton.setImage(UIImage(named: "Gray Error"), for: .normal)
                }
                if data["request"] as! Bool && !requesting {
                    buttonText.text = "Busy"
                    statusText.text = "Someone else is operating the gate."
                    triggerButton.setImage(UIImage(named: "Gray Error"), for: .normal)
                }
                if let timedOut = data["timedOut"] as? Bool {
                    if timedOut {
                        failureNotification(title: "Timed out", description: "Request Timed Out")
                    }
                }
            } else {
                statusText.text = "Server not activated"
                triggerButton.setImage(UIImage(named: "Gray Error"), for: .normal)
                statusText.text = "Server not activated"
                triggerButton.isEnabled = false
                buttonText.text = "Disabled"
            }
        }
    }
    
    
    
    
    func failureNotification(title:String, description:String) {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { (timer) in
            let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            self.present(alert, animated: true)
        }
        
    }
    
    func getGateData(completionHandler: @escaping (Data) -> Void) {
        let firestore = Firestore.firestore()
               
        firestore.collection("userData").document(currentUser!.uid).getDocument { documentSnapshot, error in
            guard let document = documentSnapshot else {
                return
            }
            if document.exists {
                if let data = document.data() {
                    let gateIDs = data["pairedGates"] as! [String]
                    for eachGateID in gateIDs {
                        firestore.collection("gates").document(eachGateID).getDocument { (snapshot, friendlyDataError) in
                            if let friendlyDataError = friendlyDataError {
                                print(friendlyDataError)
                                self.failureNotification(title: "Error", description: "Cannot Fetch Friendly Name")
                            }
                            if let document = snapshot {
                                self.gateList[eachGateID] = document["friendlyName"] as? String
                            } else {
                                self.failureNotification(title: "Error", description: "Gate does not exist!")
                            }
                        }
                    }
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (asyncTimer) in
                        if self.gateList.count >= gateIDs.count {
                            completionHandler(Data(count: 0))
                            asyncTimer.invalidate()
                        }
                    }
                } else {
                    self.failureNotification(title: "Error", description: "Cannot fetch gate list.")
                }
            }
        }
    }
    
    @IBOutlet var triggerButton: CircleButton!
    @IBOutlet var buttonText: UILabel!
    @IBOutlet var statusText: UILabel!
    
    
    @IBAction func trigger(_ sender: Any) {
        request()
    }
    
    func cancelRequest() {
         database.collection("controlRequest").document(currentUser!.uid).setData(["type":"abort", "target":self.selectedGate], merge: true) { (error) in
            if error == nil{
                self.buttonText.text = "Stopping..."
                self.triggerButton.setImage(UIImage(named: "Gray Error"), for: .normal)
            } else {
                if let error = error{
                    print(error)
                }
                self.triggerButton.setImage(UIImage(named: "Gray Error"), for: .normal)
            }
        }
    }
    
    func request() {
        requesting = true
        self.triggerButton.setImage(UIImage(named: "Gray Error"), for: .normal)
        self.buttonText.text = "Sending Request"
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        database.collection("controlRequest").document(currentUser!.uid).setData(["type":"request", "data":true, "target":self.selectedGate], merge: true) { (error) in
            if error == nil{
                generator.impactOccurred()
                self.buttonText.text = "Request Sent"
            } else {
                if let error = error {
                    print(error)
                }
            }
        }
    }
    
    
    
    @IBAction func options(_ sender: Any) {
        let optionsController = UIAlertController(title: "Settings", message: "Select the options below", preferredStyle: .actionSheet)
        let signOutOption = UIAlertAction(title: "Sign Out", style: .destructive) { (signOut) in
            do {
              try Auth.auth().signOut()
            } catch let signOutError as NSError {
              print ("Error signing out: %@", signOutError)
            }
            UserDefaults.standard.set(false, forKey: "signedIn")
            self.performSegue(withIdentifier: "signOutController", sender: nil)
        }
        let autoSignInEnabled = UserDefaults.standard.bool(forKey: "autoSignIn")
        var autoSignInText = ""
        if autoSignInEnabled {
            autoSignInText = "Disable Auto Sign In"
        } else {
            autoSignInText = "Enable Auto Sign In"
        }
        let autoSignIn = UIAlertAction(title: autoSignInText, style: .default) { (autoSignIn) in
            UserDefaults.standard.set(!autoSignInEnabled, forKey: "autoSignIn")
        }
        
        optionsController.addAction(signOutOption)
        optionsController.addAction(autoSignIn)
        optionsController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(optionsController, animated: true)
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
