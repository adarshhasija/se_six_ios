//
//  Content.swift
//  HandPose
//
//  Created by Adarsh Hasija on 02/01/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation

class Content {
    
    enum SignLanguageType {
        case ASL
        case ISL
    }
    
    var text : String
    var isFingerspelling : Bool = false //If yes, the user is meant to go letter by letter
    var isPose : Bool =  false
    var maximumHandCount: Int = 1
    var modelObservationsNeeded : Int = 15 //0.5s. Maybe more for longer actions
    var signLangType : SignLanguageType = SignLanguageType.ASL
    var links : [String] = []
    
    init(text : String) {
        self.text = text
    }
    
    init(text : String, isFingerspelling : Bool) {
        self.text = text
        self.isFingerspelling = isFingerspelling
    }
    
    //fingerspelling false
    //Most words have actions as signs
    //But in some cases, the word has a pose as a sign
    //eg: I Love You
    init(text : String, isPose : Bool) {
        self.text = text
        self.isPose = isPose
    }
    
    init(text : String, modelObservationsNeeded : Int) {
        self.text = text
        self.modelObservationsNeeded = modelObservationsNeeded
    }
    
    init(text : String, modelObservationsNeeded : Int, links : [String]) {
        self.text = text
        self.modelObservationsNeeded = modelObservationsNeeded
        self.links.append(contentsOf: links)
    }
    
    init(text : String, modelObservationsNeeded : Int, maximumHandCount : Int) {
        self.text = text
        self.modelObservationsNeeded = modelObservationsNeeded
        self.maximumHandCount = maximumHandCount
    }
    
    init(text : String, modelObservationsNeeded : Int, maximumHandCount : Int, signLangType: SignLanguageType) {
        self.text = text
        self.modelObservationsNeeded = modelObservationsNeeded
        self.maximumHandCount = maximumHandCount
        self.signLangType = signLangType
    }
    
    init(text : String, modelObservationsNeeded : Int, maximumHandCount : Int, links : [String]) {
        self.text = text
        self.modelObservationsNeeded = modelObservationsNeeded
        self.maximumHandCount = maximumHandCount
        self.links.append(contentsOf: links)
    }
    
    init(text : String, isFingerspelling : Bool, isPose : Bool) {
        self.text = text
        self.isFingerspelling = isFingerspelling
        self.isPose = isPose
    }
    
    init(text : String, signLangType: SignLanguageType) {
        self.text = text
        self.signLangType = signLangType
    }
}
