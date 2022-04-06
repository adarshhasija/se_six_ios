//
//  ModesTableViewController.swift
//  HandPose
//
//  Created by Adarsh Hasija on 02/11/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import UIKit

class ContentTableViewController : UITableViewController {
    
    let contentList = [
        //Spelling content
        //Content(text: "Enter name"),
        //Content(text: "SIGN KARO"),
        //Content(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        //Content(text: "ASIA"),
        //Content(text: "CUBBON PARK"),
        //
        Content(text: "HOLI", isFingerspelling: true),
        //Content(text: "NBA", isFingerspelling: true),
        //Content(text: "NFL", isFingerspelling: true),
        Content(text: "Yes"),
        //Content(text: "No"), //working but not well
        Content(text: "Ambulance", modelObservationsNeeded: 30),
        Content(text: "Easter", modelObservationsNeeded: 30, maximumHandCount: 2),
        Content(text: "Later"),
        Content(text: "Bathroom"),
        Content(text: "Goodbye"),
        Content(text: "Milk"),
        Content(text: "CODA", isFingerspelling: true),
        //Content(text: "Christmas"), working but not well
        //Content(text: "USA", isFingerspelling: true),
        //Content(text: "Which"), //works but needs 2 hands
        //Content(text: "Car"), //Not yet done
        //Content(text: "YourWelcome"), //too reactive at 1. not working at 0.5
        Content(text: "Where", isFingerspelling: false), //not working
        Content(text: "I Love You", isPose: true), 
        //Content(text: "Come", signLangType: "ISL"),
        //Content(text: "Go", signLangType: "ISL"), //Not working
        //Content(text: "Walk", signLangType: "ISL"),
        //Content(text: "Onam", signLangType: "ISL")
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
        return contentList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : MyTableViewCell = tableView.dequeueReusableCell(withIdentifier: "ModeCell", for: indexPath) as! MyTableViewCell

        if indexPath.row == 0 && contentList[indexPath.row].text.contains("name") {
            cell.accessoryType = .disclosureIndicator
        }
        let content = contentList[indexPath.row]
        cell.title.text = content.text
        //cell.textLabel?.text = mode.text //if default cell type
        if content.signLangType.uppercased() == "ISL" {
            let fileName = "india_flag"
            let newImage : UIImage? = UIImage(named: fileName)
            cell.leadingImageView.image = newImage
            
            cell.signLangType.isHidden = false
            cell.signLangType.text = content.signLangType
        }
        else {
            let fileName = "ASL_" + content.text
            let newImage : UIImage? = UIImage(named: fileName)
            cell.leadingImageView.image = newImage
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && contentList[indexPath.row].text.contains("name") {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let secondViewController = storyboard.instantiateViewController(withIdentifier: "CustomTextView") as! CustomTextViewController
            secondViewController.delegateCameraView = self.delegateCameraView
            self.navigationController?.pushViewController(secondViewController, animated: true)
        }
        else {
            self.delegateCameraView?.newContentReceived(content: contentList[indexPath.row])
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
    }
    
    
}

