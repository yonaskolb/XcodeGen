//
//  main.swift
//  EndpointSecurity
//
//  Created by Vlad Gorlov on 18.06.21.
//

import Foundation
import EndpointSecurity

var client: OpaquePointer?

// Create the client
let res = es_new_client(&client) { (client, message) in
    // Do processing on the message received
}

if res != ES_NEW_CLIENT_RESULT_SUCCESS {
    exit(EXIT_FAILURE)
}

dispatchMain()
