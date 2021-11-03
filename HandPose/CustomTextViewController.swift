//
//  CustomTextViewController.swift
//  HandPose
//
//  Created by Adarsh Hasija on 02/11/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import UIKit

class CustomTextViewController : UIViewController {
    
    var delegateCameraView : CameraViewControllerProtocol? = nil
    
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    
    @objc func done(){
        if textField?.text?.isEmpty == false {
            let text = textField!.text!.uppercased()
            let lettersAndSpacesCharacterSet = CharacterSet.letters.union(.whitespaces).inverted
            let letters = CharacterSet.letters.inverted
             let testValid1 = text.rangeOfCharacter(from: letters) == nil
             if testValid1 == true {
                 self.delegateCameraView?.newTextReceived(text: text)
                 self.navigationController?.dismiss(animated: true, completion: nil)
             }
             else {
                errorLabel.text = "Text should only contain letters. No numbers, spaces or special characters"
                animateErrorLabel()
             }
         }
        else {
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
        
    }
    
    func animateErrorLabel() {
        errorLabel?.transform = CGAffineTransform(translationX: 20, y: 0)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.2, initialSpringVelocity: 1, options: .curveEaseInOut, animations: {
            self.errorLabel?.transform = CGAffineTransform.identity
                }, completion: nil)
    }
    
    override func viewDidLoad() {
        instructionLabel.text = "Enter the name of a person or a place. Letters only. Max 10 characters."
        textField.placeholder = "eg: Rohan"
        textField.delegate = self
        
        let doneBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(done))
        self.navigationItem.rightBarButtonItem  = doneBarButtonItem
    }

}

extension CustomTextViewController : UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxLength = 10
        let currentString: NSString = (textField.text ?? "") as NSString
        let newString: NSString =
                currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
}
