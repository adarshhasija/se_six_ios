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
    
    var contentList = [
        //Spelling content
        //Content(text: "Enter name"),
        //Content(text: "SIGN KARO"),
        //Content(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        //Content(text: "ASIA"),
        //Content(text: "CUBBON PARK"),
        //
        //Content(text: "NBA", isFingerspelling: true),
        //Content(text: "NFL", isFingerspelling: true),
        Content(text: "Yes"),
        //Content(text: "No", modelObservationsNeeded: 30), //not working
        //Content(text: "No"), //working but not well
        //Content(text: "Monday", modelObservationsNeeded: 30, links: ["Days_Of_Week"]),
        //Content(text: "Tuesday", modelObservationsNeeded: 30, links: ["Days_Of_Week"]),
        //Content(text: "Wednesday", modelObservationsNeeded: 30, links: ["Days_Of_Week"]),
        //Content(text: "Thursday", modelObservationsNeeded: 30, links: ["Days_Of_Week"]),
        //Content(text: "Friday", modelObservationsNeeded: 30, links: ["Days_Of_Week"]),
        //Content(text: "Saturday", modelObservationsNeeded: 30, links: ["Days_Of_Week"]),
        //Content(text: "Sunday", modelObservationsNeeded: 30, maximumHandCount: 2, links: ["Days_Of_Week"]),
        Content(text: "Thanksgiving", modelObservationsNeeded: 30),
        //Content(text: "Turkey", modelObservationsNeeded: 30), //working horizontally but not vertically
        //Content(text: "Family", modelObservationsNeeded: 60, maximumHandCount: 2), //Not working. Was showing as correct even with both hands in start position and not moving
        Content(text: "Ambulance", modelObservationsNeeded: 30),
        //Content(text: "Judge", modelObservationsNeeded: 30, maximumHandCount: 2), //It is working but cannot find a good graphic for it. So commenting it out
        Content(text: "Halloween", modelObservationsNeeded: 30, maximumHandCount: 2),
        Content(text: "Soccer", modelObservationsNeeded: 30, maximumHandCount: 2),
        Content(text: "Soccer", modelObservationsNeeded: 60, maximumHandCount: 2, signLangType: Content.SignLanguageType.ISL),
        //Content(text: "Library", modelObservationsNeeded: 15), //0.5,1,1.5 all not working
        //Content(text: "Twitter", modelObservationsNeeded: 30), //not working always
        //Content(text: "Now", modelObservationsNeeded: 30, maximumHandCount: 2), //Not working
        Content(text: "Fire", modelObservationsNeeded: 30, maximumHandCount: 2),
        Content(text: "Easter", modelObservationsNeeded: 30, maximumHandCount: 2),
        Content(text: "Teacher", modelObservationsNeeded: 45, maximumHandCount: 2),
        Content(text: "Tennis", modelObservationsNeeded: 45),
        Content(text: "Celebrate", modelObservationsNeeded: 30, maximumHandCount: 2),
        Content(text: "Later"),
        Content(text: "Bathroom"),
        Content(text: "Goodbye"),
        Content(text: "Milk"),
        Content(text: "CODA", isFingerspelling: true),
        Content(text: "HOLI", isFingerspelling: true),
        Content(text: "EID", isFingerspelling: true),
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
    var currentSelectedContent : Content?
    
    @objc func close(){
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        let closeBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(close))
        self.navigationItem.rightBarButtonItem  = closeBarButtonItem
        
        let link1 = currentSelectedContent?.links.first
        var itemsWithLink : [Content] = []
        var itemsWithoutLink : [Content] = []
        if link1 != nil {
            for content in contentList {
                if content.links.contains("Days_Of_Week") {
                    itemsWithLink.append(content)
                }
                else {
                    itemsWithoutLink.append(content)
                }
            }
            contentList.removeAll()
            contentList.append(contentsOf: itemsWithLink)
            contentList.append(contentsOf: itemsWithoutLink)
        }
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
        if content.signLangType == Content.SignLanguageType.ISL {
            let fileName = "india_flag"
            let newImage : UIImage? = UIImage(named: fileName)
            cell.leadingImageView.image = newImage
            
            cell.signLangType.isHidden = false
            cell.signLangType.text = "Indian Sign Language"
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

