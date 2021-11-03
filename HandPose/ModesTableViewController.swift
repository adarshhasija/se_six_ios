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
        Mode(name: "Enter name"),
        Mode(name: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        Mode(name: "JZAECMINOSYT")
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "ModeCell", for: indexPath)

        if indexPath.row == 0 {
            cell.accessoryType = .disclosureIndicator
        }
        let mode = modes[indexPath.row]
        cell.textLabel?.text = mode.name

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let secondViewController = storyboard.instantiateViewController(withIdentifier: "CustomTextView") as! CustomTextViewController
            secondViewController.delegateCameraView = self.delegateCameraView
            self.navigationController?.pushViewController(secondViewController, animated: true)
        }
        else {
            self.delegateCameraView?.newTextReceived(text: modes[indexPath.row].name)
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
    }
    
    
}

