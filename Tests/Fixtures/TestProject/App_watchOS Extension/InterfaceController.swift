//
//  InterfaceController.swift
//  App_watchOS Extension
//
//  Created by Yonas Kolb on 30/1/18.
//

import WatchKit
import Foundation
import Alamofire

class InterfaceController: WKInterfaceController {

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        let method = HTTPMethod.get
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
