//
//  ModesTableViewController.swift
//  HandPose
//
//  Created by Adarsh Hasija on 02/11/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import UIKit

class ModesTableViewController : UITableViewController {
    
    struct Mode {
        var name: String
    }
    
    let modes = [
        //Spelling content
        //Content(text: "Enter name"),
        //Content(text: "SIGN KARO"),
        //Content(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        //Content(text: "ASIA"),
        //Content(text: "CUBBON PARK"),
        //
        Content(text: "Yes", isFingerspelling: false, isPose: false),
        Content(text: "No", isFingerspelling: false, isPose: false), //working but not well
        Content(text: "Later", isFingerspelling: false, isPose: false), //Not working
        Content(text: "Bathroom", isFingerspelling: false, isPose: false),
        Content(text: "Goodbye", isFingerspelling: false, isPose: false),
        Content(text: "Milk", isFingerspelling: false, isPose: false),
        Content(text: "Christmas", isFingerspelling: false, isPose: false),
        //Content(text: "USA", isFingerspelling: true, isPose: true),
        //Content(text: "Which", isFingerspelling: false, isPose: false), //works but needs 2 hands
        //Content(text: "Car", isFingerspelling: false, isPose: false), //Not yet done
        //Content(text: "YourWelcome", isFingerspelling: false, isPose: false), //too reactive
        Content(text: "Where", isFingerspelling: false, isPose: false), //not working
        //Content(text: "I Love You", isFingerspelling: false, isPose: true), //works but possibly awkward
        //Content(text: "Come", isFingerspelling: false, isPose: false, signLangType: "Indian Sign Language"),
        //Content(text: "Go", isFingerspelling: false, isPose: false, signLangType: "Indian Sign Language"), //Not working
        //Content(text: "Walk", isFingerspelling: false, isPose: false, signLangType: "Indian Sign Language"),
        //Content(text: "Onam", isFingerspelling: false, isPose: false, signLangType: "Indian Sign Language")
    ]
    
    var delegateCameraView : CameraViewControllerProtocol? = nil
    
    @objc func close(){
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        let closeBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(close))
        self.navigationItem.rightBarButtonItem  = closeBarButtonItem
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return modes.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : MyTableViewCell = tableView.dequeueReusableCell(withIdentifier: "ModeCell", for: indexPath) as! MyTableViewCell

        if indexPath.row == 0 && modes[indexPath.row].text.contains("name") {
            cell.accessoryType = .disclosureIndicator
        }
        let mode = modes[indexPath.row]
        cell.title.text = mode.text
        //cell.textLabel?.text = mode.text //if default cell type
        if mode.signLangType != nil {
            cell.signLangType.isHidden = false
            cell.signLangType.text = mode.signLangType
        }
        else if mode.signLangType?.uppercased() == "INDIAN SIGN LANGUAGE" {
            let fileName = "india_flag"
            let newImage : UIImage? = UIImage(named: fileName)
            cell.leadingImageView.image = newImage
        }
        else {
            let fileName = "ASL_" + mode.text
            let newImage : UIImage? = UIImage(named: fileName)
            cell.leadingImageView.image = newImage
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && modes[indexPath.row].text.contains("name") {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let secondViewController = storyboard.instantiateViewController(withIdentifier: "CustomTextView") as! CustomTextViewController
            secondViewController.delegateCameraView = self.delegateCameraView
            self.navigationController?.pushViewController(secondViewController, animated: true)
        }
        else {
            self.delegateCameraView?.newContentReceived(content: modes[indexPath.row])
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
    }
    
    
}

