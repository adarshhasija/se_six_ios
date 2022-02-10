//
//  Content.swift
//  HandPose
//
//  Created by Adarsh Hasija on 02/01/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation

class Content {
    
    var text : String
    var isFingerspelling : Bool //If yes, the user is meant to go letter by letter
    var isPose : Bool? //False if its a moving action
    var signLangType : String? //ASL or ISL or other. If nil, it means its ASL
    
    init(text : String) {
        self.text = text
        self.isFingerspelling = true
        self.isPose = nil
    }
    
    init(text : String, isFingerspelling : Bool, isPose : Bool) {
        self.text = text
        self.isFingerspelling = isFingerspelling
        self.isPose = isPose
    }
    
    init(text : String, isFingerspelling : Bool, isPose : Bool, signLangType: String) {
        self.text = text
        self.isFingerspelling = isFingerspelling
        self.isPose = isPose
        self.signLangType = signLangType
    }
}
