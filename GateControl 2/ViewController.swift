//
//  ViewController.swift
//  GateControl 2
//
//  Created by Book Lailert on 9/1/20.
//  Copyright © 2020 Book Lailert. All rights reserved.
//

import UIKit
import Firebase

var currentUser:User?

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet var signInButton: UIButton!
    @IBOutlet var cover: UIVisualEffectView!
    @IBOutlet var background: UIView!
    
    @objc func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if self.traitCollection.userInterfaceStyle == .dark {
            signInButton.backgroundColor = UIColor(red: 52.0/255, green: 91.0/255, blue: 219.0/255, alpha: 1.0)
            self.view.backgroundColor = UIColor.darkGray
         } else {
            signInButton.backgroundColor = UIColor(red: 126.0/255, green: 230/255, blue: 98.0/255, alpha: 1.0)
            self.view.backgroundColor = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1.0)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
         if self.traitCollection.userInterfaceStyle == .dark {
            signInButton.backgroundColor = UIColor(red: 52.0/255, green: 91.0/255, blue: 219.0/255, alpha: 1.0)
            self.view.backgroundColor = UIColor.darkGray
         } else {
            signInButton.backgroundColor = UIColor(red: 126.0/255, green: 230/255, blue: 98.0/255, alpha: 1.0)
            self.view.backgroundColor = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1.0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.set(false, forKey: "forcePair")
        usernameField.delegate = self
        passwordField.delegate = self
        background.layer.cornerRadius = 24
        background.clipsToBounds = true
        signInButton.layer.cornerRadius = 7
        
        
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        
        signInButton.clipsToBounds = true
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        

        if UserDefaults.standard.bool(forKey: "signedIn") {
            self.cover.isHidden = false
        }
        
        if Auth.auth().currentUser != nil {
            if UserDefaults.standard.bool(forKey: "autoSignIn") {
                currentUser = Auth.auth().currentUser
                generator.impactOccurred()
                signInSucess()
            } else {
                self.cover.isHidden = true
                do {
                  try Auth.auth().signOut()
                } catch let signOutError as NSError {
                  print ("Error signing out: %@", signOutError)
                }
            }
        } else {
            self.cover.isHidden = true
            if UserDefaults.standard.bool(forKey: "signedIn") {
                let errorImpact = UINotificationFeedbackGenerator()
                errorImpact.notificationOccurred(.error)
                let alert = UIAlertController(title: "You've been logged out", message: "Please sign in again", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(alert, animated: true)
                UserDefaults.standard.set(false, forKey: "signedIn")
            }
        }
        // Do any additional setup after loading the view.
    }
    
    func signInSucess() {
        
        let firestore = Firestore.firestore()
        
        firestore.collection("userData").document(currentUser!.uid).getDocument { documentSnapshot, error in
            guard let document = documentSnapshot else {
                return
            }
            if document.exists {
                if let data = document.data() {
                    if ((data["pairedGates"] as? [String]) != nil) && (data["pairedGates"] as! [String]).count > 0 {
                        self.performSegue(withIdentifier: "loginWithGate", sender: self)
                    }
                }
            }
            UserDefaults.standard.set(true, forKey: "forcePair")
            self.performSegue(withIdentifier: "loginNoGate", sender: self)
        }
    }
    
    @IBOutlet var usernameField: UITextField!
    @IBOutlet var passwordField: UITextField!
    
    
    
    @IBAction func signIn(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        let signInImpact = UIImpactFeedbackGenerator(style: .medium)
        signInImpact.prepare()
        if usernameField.text != nil && passwordField.text != nil{
            Auth.auth().signIn(withEmail: usernameField.text!, password: passwordField.text!) { [weak self] authResult, error in
                if authResult == nil {
                    let errorImpact = UINotificationFeedbackGenerator()
                    errorImpact.notificationOccurred(.error)
                    let alert = UIAlertController(title: "Sign In Failed", message: "The email or password entered was incorrect", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self?.present(alert, animated: true, completion: nil)
                } else {
                    if !UserDefaults.standard.bool(forKey: "signedIn") {
                        UserDefaults.standard.set(true, forKey: "autoSignIn")
                    }
                    currentUser = authResult?.user
                    Firestore.firestore().collection("emailData").document(self!.usernameField.text!.lowercased()).setData(["uid": currentUser?.uid as Any])
                    UserDefaults.standard.set(true, forKey: "signedIn")
                    signInImpact.impactOccurred()
                    self?.signInSucess()
                }
            }
        }
    }
    
}

