//
//  MyNavigationViewController.swift
//  HandPose
//
//  Created by Adarsh Hasija on 02/11/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import UIKit

class MyNavigationController : UINavigationController {
    
    var delegateCamera : CameraViewControllerProtocol? = nil
    
    override func viewDidAppear(_ animated: Bool) {
        delegateCamera?.modalLoaded()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        delegateCamera?.modalDismissed()
    }
}
