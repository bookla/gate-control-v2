//
//  SelectorTableViewController.swift
//  
//
//  Created by Book Lailert on 13/2/20.
//

import UIKit
import Firebase

extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}

extension String {
     struct NumFormatter {
         static let instance = NumberFormatter()
     }

     var doubleValue: Double? {
         return NumFormatter.instance.number(from: self)?.doubleValue
     }

     var integerValue: Int? {
         return NumFormatter.instance.number(from: self)?.intValue
     }
}

class SelectorTableViewController: UITableViewController {
    
    var gateList = [String: [Any]]()
    
    func failureNotification(title:String, description:String) {
        let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    func getGateData(loadingSheet:UIAlertController, completionHandler: @escaping (Data) -> Void) {
           let firestore = Firestore.firestore()
        self.gateList = [String: [Any]]()
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
                                    loadingSheet.dismiss(animated: true) {
                                        self.failureNotification(title: "Error", description: "Cannot Fetch Friendly Name")
                                    }
                               }
                               if let document = snapshot {
                                self.gateList[eachGateID] = [document["friendlyName"] as? String as Any, document["enabled"] as? Bool as Any]
                               } else {
                                    loadingSheet.dismiss(animated: true) {
                                        self.failureNotification(title: "Error", description: "Gate does not exist!")
                                    }
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
                        loadingSheet.dismiss(animated: true) {
                            self.failureNotification(title: "Error", description: "Cannot fetch gate list.")
                        }
                   }
               }
           }
       }
    
    
    func updateData() {
        let loadingAlert = UIAlertController(title: "Please wait...", message: "Getting your gates ready.", preferredStyle: .actionSheet)
        self.present(loadingAlert, animated: true) {
            self.getGateData(loadingSheet: loadingAlert) { (data) in
                loadingAlert.dismiss(animated: true, completion: nil)
                self.tableView.reloadData()
            }
        }
    }
    
    
     override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        let footerView = UIView()
           if self.traitCollection.userInterfaceStyle == .dark {
            tableView.backgroundColor = UIColor.black
           } else {
            tableView.backgroundColor = UIColor(red: 235.0/255, green: 235.0/255, blue: 235.0/255, alpha: 1.0)
           }
        tableView.tableFooterView = footerView
       }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set(false, forKey: "forcePair")
        self.navigationItem.hidesBackButton = false
        let footerView = UIView()
        initListener()
        
        
        if self.traitCollection.userInterfaceStyle == .dark {
            tableView.backgroundColor = UIColor.black
        } else {
            tableView.backgroundColor = UIColor(red: 235.0/255, green: 235.0/255, blue: 235.0/255, alpha: 1.0)
        }
        
        tableView.tableFooterView = footerView
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return gateList.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SelectorTableViewCell
        
        cell.friendlyName.text = gateList[Array(gateList.keys)[indexPath.row]]![0] as? String
        cell.gateID.text = "ID : " + Array(gateList.keys)[indexPath.row]
        if gateList[Array(gateList.keys)[indexPath.row]]![1] as! Bool {
            cell.gateEnabled.textColor = UIColor.green
            cell.gateEnabled.text = "Enabled"
        } else {
            cell.gateEnabled.textColor = UIColor.red
            cell.gateEnabled.text = "Disabled"
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70;
    }
    

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func renameCell(atRow:Int) {
        let renameAlert = UIAlertController(title: "Rename", message: "Change the friendly name of a gate. This name can be seen by anyone who has access to the gate.", preferredStyle: .alert)
        
        renameAlert.addTextField { (renameField) in
            renameField.text = self.gateList[Array(self.gateList.keys)[atRow]]![0] as? String
            renameField.autocorrectionType = .yes
            renameField.autocapitalizationType = .words
        }
        
        let rename = UIAlertAction(title: "Rename", style: .default) { (action) in
            renameAlert.dismiss(animated: true) {
                let renamingAlert = UIAlertController(title: "Renaming", message: "Please wait while we rename the gate", preferredStyle: .actionSheet)
                self.present(renamingAlert, animated: true) {
                    Firestore.firestore().collection("controlRequest").document(currentUser!.uid).setData(["type":"friendlyName", "data": renameAlert.textFields![0].text as Any, "target":Array(self.gateList.keys)[atRow]], merge: true) { (error) in
                        if error == nil{
                            self.updateData()
                            renamingAlert.dismiss(animated: true, completion: nil)
                            self.navigationItem.hidesBackButton = true
                        } else {
                            if let error = error {
                                print(error)
                            }
                        }
                    }
                }
            }
        }
        
        renameAlert.addAction(rename)
        renameAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(renameAlert, animated: true, completion: nil)
    }
    
    func unpair(atRow:Int) {
        let unpairingAlert = UIAlertController(title: "Unpairing", message: "Please wait while we unpair the gate from your account.", preferredStyle: .actionSheet)
        
        self.present(unpairingAlert, animated: true) {
            Firestore.firestore().collection("unpairRequest").document(currentUser!.uid).setData(["target": Array(self.gateList.keys)[atRow]]) { (error) in
                if let error = error {
                    print(error)
                    unpairingAlert.dismiss(animated: true) {
                        self.failureNotification(title: "Unpairing Failed", description: "Please check your internet connection.")
                    }
                    return
                }
            }
            
            
            Firestore.firestore().collection("userData").document(currentUser!.uid).addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print(error)
                    unpairingAlert.dismiss(animated: true) {
                        self.failureNotification(title: "Unpairing Failed", description: "Unable to connect to server.")
                    }
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
                
                if !((data["pairedGates"] as! [String]).contains(Array(self.gateList.keys)[atRow])) {
                    unpairingAlert.message = "Unpaired Sucessfully"
                    unpairingAlert.dismiss(animated: true) {
                        if self.gateList.count == 1 {
                            self.performSegue(withIdentifier: "pairGate", sender: self)
                            UserDefaults.standard.set(true, forKey: "forcePair")
                        } else {
                            self.updateData()
                            self.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    func promptUnpair(atRow:Int) {
    
        let renameAlert = UIAlertController(title: "Unpair?", message: "Are you sure that you want to unpair the gate?", preferredStyle: .alert)
        
        let yesAction = UIAlertAction(title: "Unpair", style: .destructive) { (action) in
            renameAlert.dismiss(animated: true) {
                self.unpair(atRow: atRow)
            }
        }
        renameAlert.addAction(yesAction)
        renameAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(renameAlert, animated: true, completion: nil)
    }
    
    
    func waitShare(to_uid:String, target_gate:String, workingSheet: UIAlertController) {
        Firestore.firestore().collection("userData").document(to_uid).addSnapshotListener { (snapshot, error) in
            if let snapshot = snapshot {
                if let data = snapshot.data(){
                    if (data.keys.contains("pairedGates")) {
                        if (data["pairedGates"] as! [String]).contains(target_gate) {
                            workingSheet.message = "Sharing Complete"
                            workingSheet.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            } else {
                print("No Data")
            }
        }
    }
    
    
    func share(atRow: Int, toEmail: String) {
        let workingSheet = UIAlertController(title: "Sharing", message: "Looking for user", preferredStyle: .actionSheet)
        self.present(workingSheet, animated: true, completion: nil)
        Firestore.firestore().collection("emailData").getDocuments { (snapshots, error) in
            var exists = false
            if let snapshots = snapshots {
                for eachDocument in snapshots.documents {
                    if eachDocument.documentID == toEmail {
                        exists = true
                        workingSheet.message = "Registering the gate to the user"
                        let from_uid = currentUser?.uid
                        let to_uid = eachDocument.data()["uid"]
                        let gate_id = Array(self.gateList.keys)[atRow]
                        Firestore.firestore().collection("userData").document(to_uid as! String).getDocument { (snapshot, error) in
                            if let error = error {
                                workingSheet.dismiss(animated: true) {
                                    self.failureNotification(title: "Unable to share", description: "There was a problem while sharing the gate, please try again later")
                                    print(error)
                                }
                                return
                            } else {
                                if let data = snapshot?.data() {
                                    if (data["pairedGates"] as! [String]).contains(gate_id) {
                                        workingSheet.dismiss(animated: true) {
                                            self.failureNotification(title: "Gate Already Paired", description: "The recipeint has already paired the gate.")
                                        }
                                        return
                                    }
                                } else {
                                    
                                }
                            }
                        }
                        Firestore.firestore().collection("sharingRequest").document(from_uid!).setData(["recipient" : to_uid as Any, "target": gate_id as Any]) { (error) in
                            if let error = error {
                                workingSheet.dismiss(animated: true) {
                                    self.failureNotification(title: "Unable to share", description: "There was a problem while sharing the gate, please try again later")
                                    print(error)
                                }
                                return
                            } else {
                                workingSheet.message = "Waiting for the server to respond"
                                self.waitShare(to_uid: to_uid as! String, target_gate: gate_id, workingSheet: workingSheet)
                            }
                        }
                    }
                }
                if !exists {
                    workingSheet.dismiss(animated: true) {
                        self.failureNotification(title: "User Not Found", description: "No user was registered under the email address provided.")
                    }
                    return
                }
            }
        }
    }
    
    
    func addUser(atRow: Int) {
        let emailRequest = UIAlertController(title: "Add People", message: "Please enter the email address of the person you would like to share the gate with. They will be able to access the gate until they unpair the gate. Use one-time code to add guest users.", preferredStyle: .alert)
        emailRequest.addTextField { (emailField) in
            emailField.placeholder = "Email Address"
        }
        let submitAction = UIAlertAction(title: "Share", style: .default) { (action) in
            emailRequest.dismiss(animated: true) {
                if emailRequest.textFields![0].text != nil {
                    self.share(atRow: atRow, toEmail: emailRequest.textFields![0].text!.lowercased())
                }
            }
        }
        emailRequest.addAction(submitAction)
        emailRequest.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(emailRequest, animated: true, completion: nil)
    }
    
    func oneTimeSharePrompt() {
        let alert = UIAlertController(title: "One-Time Share", message: "Please input the parameters for the one-time sharing below.", preferredStyle: .alert)
        alert.addTextField { (hourTextField) in
            hourTextField.placeholder = "Validity in hours"
            hourTextField.keyboardType = .numbersAndPunctuation
        }
        alert.addTextField { (limitField) in
            limitField.placeholder = "Usage limit"
            limitField.keyboardType = .numberPad
        }
        let shareAction = UIAlertAction(title: "Share", style: .default) { (action) in
            if alert.textFields![0].text == nil || alert.textFields![1].text == nil || !alert.textFields![1].text!.isNumber {
                alert.dismiss(animated: true) {
                    self.failureNotification(title: "Unable to share", description: "Incorrect input type")
                }
            } else {
                if Double(alert.textFields![0].text!) == nil {
                    self.failureNotification(title: "Unable to share", description: "Incorrect input type")
                    return
                }
                let hoursVal = Double(alert.textFields![0].text!)
                let limitVal = Int(alert.textFields![1].text!)
                UserDefaults.standard.set(NSDate(), forKey: "startTime")
                UserDefaults.standard.set(NSDate().addingTimeInterval(TimeInterval(hoursVal!*60*60)), forKey: "endTime")
                UserDefaults.standard.set(limitVal!, forKey: "limit")
                alert.dismiss(animated: true) {
                    self.performSegue(withIdentifier: "showOneTime", sender: self)
                }
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(shareAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    func sharePrompt(atRow: Int) {
        let shareAlert = UIAlertController(title: "Share", message: "Choose the method you would like to share the gate.", preferredStyle: .actionSheet)
        let addAction = UIAlertAction(title: "Add People", style: .default) { (action) in
            shareAlert.dismiss(animated: true) {
                self.addUser(atRow: atRow)
            }
        }
        let oneTimeAction = UIAlertAction(title: "Generate One-Time Code", style: .default) { (action) in
            shareAlert.dismiss(animated: true) {
                self.oneTimeSharePrompt()
            }
        }
        shareAlert.addAction(addAction)
        shareAlert.addAction(oneTimeAction)
        shareAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(shareAlert, animated: true, completion: nil)
    }
    
    func initListener() {
        Firestore.firestore().collection("gates").addSnapshotListener { (snapshot, error) in
            guard let document = snapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            guard document.documents.count > 0 else {
                print("Document data was empty.")
                return
            }
            self.updateData()
        }
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let shareAction = UIContextualAction(style: .normal, title:  "Share", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            self.sharePrompt(atRow: indexPath.row)
            success(true)
        })
        shareAction.image = UIImage(systemName: "person.badge.plus")
        shareAction.backgroundColor = view.tintColor
        return UISwipeActionsConfiguration(actions: [shareAction])

    }
    
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let update = UIContextualAction(style: .normal, title:  "Rename", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            self.renameCell(atRow: indexPath.row)
            success(true)
        })
        update.backgroundColor = .lightGray
        update.image = UIImage(systemName: "text.cursor")

        let delete = UIContextualAction(style: .normal, title:  "Unpair", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            self.promptUnpair(atRow: indexPath.row)
            success(true)
        })
        delete.image = UIImage(systemName: "xmark")
        delete.backgroundColor = .red


        return UISwipeActionsConfiguration(actions: [delete, update])
    }
    
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaults.standard.set(Array(self.gateList.keys)[indexPath.row], forKey: "selectedGate")
        self.performSegue(withIdentifier: "selectedGate", sender: self)
    }
    

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
