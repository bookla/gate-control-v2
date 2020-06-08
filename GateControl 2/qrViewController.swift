//
//  qrViewController.swift
//  GateControl 2
//
//  Created by Book Lailert on 13/2/20.
//  Copyright © 2020 Book Lailert. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase

class qrViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession:AVCaptureSession = AVCaptureSession()
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var qrCodeFrameView:UIView?
    
    
    let firestore = Firestore.firestore()
    var pairing = false
    
    
    @IBOutlet var messageLabel: UILabel!
    @IBOutlet var blurEffect: UIVisualEffectView!
    
    
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
        
        if !gateExists || !pairingCode.contains(":") {
            self.registrationFailure(sheet: waitingSheet, title: "Invalid QR Code", description: "The gate doesn't exist. Please check the QR code and try again")
            return
        }
        
        let gateID = String(pairingCode.split(separator: ":")[0])
        let gatePassword = String(pairingCode.split(separator: ":")[1])
        
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
                    self.performSegue(withIdentifier: "pairSuccess", sender: nil)
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
    
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if pairing == true {
            return
        }
        
        if metadataObjects.count == 0 {
            messageLabel.text = "Looking for QR code"
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                registerDevice(pairingCode: metadataObj.stringValue!)
            }
        }
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        // Get the back-facing camera for capturing videos
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: AVMediaType.video, position: .back)
         
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
         
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addInput(input)
            captureSession.addOutput(captureMetadataOutput)
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            captureSession.startRunning()
            view.bringSubviewToFront(blurEffect)
            view.bringSubviewToFront(messageLabel)
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        // Do any additional setup after loading the view.
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
