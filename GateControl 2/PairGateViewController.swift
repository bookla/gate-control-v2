//
//  PairGateViewController.swift
//  GateControl 2
//
//  Created by Book Lailert on 13/2/20.
//  Copyright © 2020 Book Lailert. All rights reserved.
//

import UIKit
import Firebase

class PairGateViewController: UIViewController {
    
    let firestore = Firestore.firestore()
    var pairing = false
    @IBOutlet var gateNotPairedText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        signOutButton.isHidden = true
        gateNotPairedText.isHidden = true
        if UserDefaults.standard.bool(forKey: "forcePair") {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
            signOutButton.isHidden = false
            gateNotPairedText.isHidden = false
            self.listenForShare()
        }
        UserDefaults.standard.set(false, forKey: "forcePair")
        // Do any additional setup after loading the view.
    }
    
    func listenForShare() {
        firestore.collection("userData").document(currentUser!.uid).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            guard let data = document.data() else {
                print("Document data was empty.")
                return
            }
            if data.keys.contains("pairedGates") {
                if (data["pairedGates"] as! [String]).count > 0 {
                    let alert = UIAlertController(title: "Gate Shared", message: "Someone has just shared a gate with you", preferredStyle: .alert)
                    let viewAction = UIAlertAction(title: "View Now", style: .default) { (action) in
                        alert.dismiss(animated: true) {
                            self.performSegue(withIdentifier: "manualPairSuccess", sender: self)
                        }
                    }
                    alert.addAction(viewAction)
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    @IBAction func manualPair(_ sender: Any) {
        let alert = UIAlertController(title: "Pair Gate", message: "Enter Gate ID and passcode written on the label at the bottom of the gate controller device below.", preferredStyle: .alert)
        alert.addTextField { (idField) in
            idField.placeholder = "Gate ID"
        }
        alert.addTextField { (passcodeField) in
            passcodeField.placeholder = "Passcode"
        }
        
        let enterAction = UIAlertAction(title: "Pair", style: .default) { (optionOne) in
            alert.dismiss(animated: true) {
                self.registerDevice(pairingCode: alert.textFields![0].text! + ":" + alert.textFields![1].text!)
            }
        }
        
        alert.addAction(enterAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
        self.present(alert, animated: true, completion: nil)
        
    }
    
    @IBOutlet var signOutButton: UIButton!
    
    @IBAction func signOut(_ sender: Any) {
        do {
          try Auth.auth().signOut()
        } catch let signOutError as NSError {
          print ("Error signing out: %@", signOutError)
        }
        UserDefaults.standard.set(false, forKey: "signedIn")
        self.performSegue(withIdentifier: "signOutPair", sender: nil)
    }
    
    func registrationFailure(sheet: UIAlertController, title: String, description: String) {
        sheet.dismiss(animated: true) {
            let noGateAlert = UIAlertController(title:title, message: description, preferredStyle: .actionSheet)
            let dismissOption = UIAlertAction(title: "OK", style: .cancel) { (option) in
                self.pairing = false
            }
            noGateAlert.addAction(dismissOption)
            self.present(noGateAlert, animated: true, completion: nil)
        }
    }
    
    
    func requestRegister(pairingCode:String, waitingSheet: UIAlertController, gateExists:Bool) {
        
        let gateID = String(pairingCode.split(separator: ":")[0])
        let gatePassword = String(pairingCode.split(separator: ":")[1])
        
        if !gateExists {
            self.registrationFailure(sheet: waitingSheet, title: "Invalid QR Code", description: "The gate doesn't exist. Please check the QR code and try again")
            return
        }
        
        waitingSheet.message = "Registering the gate to your account, this may take some time."
        
        if currentUser == nil {
            self.registrationFailure(sheet: waitingSheet, title: "Error Occured", description: "You're not logged in. Please log in again.")
            return
        }
        
        
        firestore.collection("pairingRequest").document(currentUser!.uid).setData([gateID:gatePassword]) { (error) in
            if let error = error {
                print(error)
                self.registrationFailure(sheet: waitingSheet, title: "Request Failed", description: "The app was not able to connect to the server, please check your internet connection.")
                return
            }
        }
        
        
        firestore.collection("pairingRequest").document(currentUser!.uid).addSnapshotListener { documentSnapshot, error in
                   guard let document = documentSnapshot else {
                       print(error)
                       self.registrationFailure(sheet: waitingSheet, title: "Registration Failed", description: "Failed to send request to the server.")
                       return
                   }
                   if !document.exists {
                       return
                   }
                   guard let data = document.data() else {
                       print("Document data was empty.")
                       return
                   }
                   
                   if !data.keys.contains("fail") {
                       return
                   }
                   
                   if (data["fail"] as! Bool) {
                       waitingSheet.dismiss(animated: true) {
                           self.registrationFailure(sheet: waitingSheet, title: "Registration Failed", description: "The code was incorrect")
                            return
                       }
                   }
                   
               }
        
        firestore.collection("userData").document(currentUser!.uid).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print(error)
                self.registrationFailure(sheet: waitingSheet, title: "Registration Failed", description: "Please try again later.")
                return
            }
            if !document.exists {
                return
            }
            guard let data = document.data() else {
                print("Document data was empty.")
                return
            }
            
            if !data.keys.contains("pairedGates") {
                return
            }
            
            if (data["pairedGates"] as! [String]).contains(gateID) {
                waitingSheet.message = "Registered Sucessfully"
                waitingSheet.dismiss(animated: true) {
                    self.performSegue(withIdentifier: "manualPairSuccess", sender: nil)
                }
            }
            
        }
    }
    
    
    func getExists(pairingCode: String, waitingSheet: UIAlertController) {
        let gateID = String(pairingCode.split(separator: ":")[0])
        
        var gateExists = false
        firestore.collection("gates").getDocuments { (snapshot, error) in
            if let error = error{
                print(error)
                self.registrationFailure(sheet: waitingSheet, title: "Unable to connect", description: "The app was not able to connect to the server, please check your internet connection.")
                return
            }
            for document in snapshot!.documents {
                print(document.documentID)
                if document.documentID == gateID {
                    gateExists = true
                }
            }
            self.requestRegister(pairingCode: pairingCode, waitingSheet: waitingSheet, gateExists: gateExists)
        }
    }
    
    
    
    func registerDevice(pairingCode:String){
        pairing = true
        
        let waitingSheet = UIAlertController(title:"Pairing Device", message: "Connecting to server...", preferredStyle: .actionSheet)
        self.present(waitingSheet, animated: true, completion: nil)
        
        let gateID = String(pairingCode.split(separator: ":")[0])
        
        firestore.collection("userData").document(currentUser!.uid).getDocument { documentSnapshot, error in
            guard let document = documentSnapshot else {
                self.registrationFailure(sheet: waitingSheet, title: "Unable to connect", description: "The app was not able to connect to the server, please check your internet connection.")
                return
            }
            if document.exists {
                if let data = document.data() {
                    if (data["pairedGates"] as! [String]).contains(gateID) {
                        self.registrationFailure(sheet: waitingSheet, title: "Gate Already Paired", description: "This gate was already paired to your account.")
                    } else {
                        self.getExists(pairingCode: pairingCode, waitingSheet: waitingSheet)
                    }
                }
            } else {
                self.firestore.collection("userData").document(currentUser!.uid).setData(["pairedGates": []]) { (error) in
                    self.getExists(pairingCode: pairingCode, waitingSheet: waitingSheet)
                }
            }
        }
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
