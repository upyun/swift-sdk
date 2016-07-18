//
//  UPUtils.swift
//
//  Created by DING FENG on 6/27/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

import Foundation


typealias  UPSuccessHandler = (response: NSHTTPURLResponse?, responseObject: NSDictionary) -> Void
typealias  UPFailureHandler = (error: NSError, response: NSHTTPURLResponse?, responseObject: NSDictionary?) -> Void
typealias  UPProgressHandler = (completedBytesCount: Int64, totalBytesCount: Int64) -> Void

let DEFAULT_UPYUN_FORM_API_DOMAIN = "https://v0.api.upyun.com"
let DEFAULT_UPYUN_FORM_API_EXPIRATION: Double = 600


let DEFAULT_UPYUN_BLOCKS_API_DOMAIN = "https://m0.api.upyun.com"
let UPYUN_FILE_BLOCK_SIZE: UInt64 = 1024 * 1024
let UPYUN_FILE_MD5_CHUNK_SIZE = 1024 * 64


func getSignatureFromPolicy(policy: String?, apiKey: String?) -> String {
    if let policy = policy, apiKey = apiKey{
        return md5(policy + "&" + apiKey)
    }
    return ""
}

func getPolicyFromFormParameters(dict: Dictionary<String, String>) -> String {
    do {
        let jsonData = try NSJSONSerialization.dataWithJSONObject(dict, options: NSJSONWritingOptions.PrettyPrinted)
        let policy:String = jsonData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        return policy
        
    } catch let error as NSError {
        print(error)
        return ""
    }
}

func md5Data(data: NSData) -> String {
    let context = UnsafeMutablePointer<CC_MD5_CTX>.alloc(1)
    var digest = Array<UInt8>(count:Int(CC_MD5_DIGEST_LENGTH), repeatedValue:0)
    CC_MD5_Init(context)
    CC_MD5_Update(context, data.bytes,
                  CC_LONG(data.length))
    CC_MD5_Final(&digest, context)
    context.dealloc(1)
    var digestHex = ""
    for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
        digestHex += String(format: "%02x", digest[index])
    }
    return digestHex
}

func md5File(path: String) -> String? {
    let handle = NSFileHandle(forReadingAtPath: path)
    guard handle != nil else {
        return nil
    }
    let context = UnsafeMutablePointer<CC_MD5_CTX>.alloc(1)
    var digest = Array<UInt8>(count:Int(CC_MD5_DIGEST_LENGTH), repeatedValue:0)
    CC_MD5_Init(context)
    var done: Bool = false
    
    while(!done) {
        let fileData = handle!.readDataOfLength(UPYUN_FILE_MD5_CHUNK_SIZE)
        CC_MD5_Update(context, fileData.bytes,
                      CC_LONG(fileData.length))
        if(fileData.length == 0) {
            done = true
        }
    }
    CC_MD5_Final(&digest, context)
    context.dealloc(1)
    var digestHex = ""
    for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
        digestHex += String(format: "%02x", digest[index])
    }
    return digestHex
}

func md5(string: String) -> String {
    var digest = [UInt8](count: Int(CC_MD5_DIGEST_LENGTH), repeatedValue: 0)
    if let data = string.dataUsingEncoding(NSUTF8StringEncoding) {
        CC_MD5(data.bytes, CC_LONG(data.length), &digest)
    }
    var digestHex = ""
    for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
        digestHex += String(format: "%02x", digest[index])
    }
    return digestHex
}



