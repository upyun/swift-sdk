//
//  HTTPClient.swift
//
//  Created by DING FENG on 6/4/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

import Foundation

typealias  UPHTTPTaskCompletionHandler = (data: NSData?, response: NSHTTPURLResponse?, error: NSError?) -> Void
typealias  UPHTTPTaskProgressHandler = (progress: NSProgress) -> Void

class UPHTTPClient: NSObject {
    var completionHandler: UPHTTPTaskCompletionHandler?
    var progressHandler: UPHTTPTaskProgressHandler?
    var nSURLSessionTask: NSURLSessionTask?
    var nSURLSession: NSURLSession?
    var didReceiveData: NSMutableData?
    var didReceiveResponse: NSURLResponse?
    
    func cancel() {
        self.nSURLSessionTask?.cancel()
    }

    func complete() {
        self.nSURLSession?.finishTasksAndInvalidate();
        self.nSURLSession = nil;
        self.progressHandler = nil;
        self.completionHandler = nil;
        self.nSURLSessionTask = nil;
        self.didReceiveData = nil;
        self.didReceiveResponse = nil;
    }
    //urlencoded
    func POST(urlString:String,
              parameter:Dictionary<String, String>,
              completionHandler: UPHTTPTaskCompletionHandler?) {
        
        let sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        sessionConfiguration.URLCache = nil;
        sessionConfiguration.URLCredentialStorage = nil;
        sessionConfiguration.requestCachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData;
        let session = NSURLSession.init(configuration: sessionConfiguration,
                                        delegate: nil,
                                        delegateQueue: nil)
        self.nSURLSession = session;
        let request: NSMutableURLRequest
        if let url = NSURL.init(string: urlString) {
            request = NSMutableURLRequest.init(URL: url)
            request.HTTPMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("HTTPClient", forHTTPHeaderField: "User-Agent")
            
            var postParameterString = ""
            for key in parameter.keys {
                postParameterString += "&"
                postParameterString += key
                postParameterString += "="
                postParameterString += parameter[key]!
            }
            if (postParameterString.characters.count > 0) {
                let index = postParameterString.startIndex.advancedBy(1)
                postParameterString = postParameterString.substringFromIndex(index)
            }
            let data = postParameterString.dataUsingEncoding(NSUTF8StringEncoding)
            request.HTTPBody = data
        } else {
            request = NSMutableURLRequest.init()
        }
        
        let sessionTask = session.dataTaskWithRequest(request) { (data, response, error) in
            if let handler = completionHandler {
                handler(data: data, response: response as? NSHTTPURLResponse , error: error)
            }
            self.complete()
        }
        self.nSURLSessionTask = sessionTask
        self.completionHandler = completionHandler
        sessionTask.resume()
    }
    
}

extension UPHTTPClient: NSURLSessionDelegate {
    //multipart/form-data
    func POST(urlString: String,
              parameter: Dictionary<String, String>,
              formName: String,
              fileName: String,
              mimeType: String,
              data: NSData?,
              progressHandler: UPHTTPTaskProgressHandler?,
              completionHandler: UPHTTPTaskCompletionHandler?) {
        
        let boundary = "UpYunSDKFormBoundarySwiftD201606V101"
        let body = NSMutableData.init()
        
        for key in parameter.keys {
            let data_boundary: NSData? = ("--" + boundary + "\r\n").dataUsingEncoding(NSUTF8StringEncoding)
            let data_key: NSData? = ("Content-Disposition: form-data; name=\"" + key + "\"\r\n\r\n").dataUsingEncoding(NSUTF8StringEncoding)
            let data_value: NSData? = (parameter[key]! + "\r\n").dataUsingEncoding(NSUTF8StringEncoding)
            
            if let data_boundary = data_boundary, data_key = data_key, data_value = data_value {
                body.appendData(data_boundary)
                body.appendData(data_key)
                body.appendData(data_value)
            }
        }
        
        if let data = data  {
            let data_boundary: NSData? = ("--" + boundary + "\r\n").dataUsingEncoding(NSUTF8StringEncoding)
            let data_fileName: NSData? = ("Content-Disposition: form-data; name=\"" + formName + "\"; filename=\"" + fileName + "\"\r\n").dataUsingEncoding(NSUTF8StringEncoding)
            let data_mimeType: NSData? = ("Content-Type: " + mimeType + "\r\n\r\n").dataUsingEncoding(NSUTF8StringEncoding)
            let data_rn: NSData? = ("\r\n").dataUsingEncoding(NSUTF8StringEncoding)
            if let data_boundary = data_boundary, data_fileName = data_fileName, data_mimeType  = data_mimeType, data_rn = data_rn {
                body.appendData(data_boundary)
                body.appendData(data_fileName)
                body.appendData(data_mimeType)
                body.appendData(data)
                body.appendData(data_rn)
            }
        }
        
        let data_end_boundary: NSData? = ("--" + boundary + "--\r\n").dataUsingEncoding(NSUTF8StringEncoding)
        body.appendData(data_end_boundary!)
        
        let request: NSMutableURLRequest
        if let url = NSURL.init(string: urlString) {
            request = NSMutableURLRequest.init(URL: url)
            request.HTTPMethod = "POST"
            request.HTTPBody = body
            request.setValue("HTTPClient", forHTTPHeaderField: "User-Agent")
        } else {
            request = NSMutableURLRequest.init()
        }
        
        let sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        sessionConfiguration.URLCache = nil;
        sessionConfiguration.URLCredentialStorage = nil;
        sessionConfiguration.requestCachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData;
        sessionConfiguration.HTTPAdditionalHeaders = ["Accept": "application/json",
                                                      "Content-Type": ("multipart/form-data; boundary=" + boundary)]
        
        let session = NSURLSession.init(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        self.nSURLSession = session;
        let sessionTask = session.dataTaskWithRequest(request)
        self.nSURLSessionTask = sessionTask
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
        sessionTask.resume()
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        let progress = NSProgress.init()
        progress.totalUnitCount = totalBytesExpectedToSend
        progress.completedUnitCount = totalBytesSent
        self.progressHandler?(progress: progress)
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        self.completionHandler?(data: self.didReceiveData, response: self.didReceiveResponse as? NSHTTPURLResponse, error: error)
        self.complete()
    }
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        completionHandler(.Allow);
        self.didReceiveResponse = response
    }
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        if self.didReceiveData == nil {
            self.didReceiveData = NSMutableData.init()
        }
        self.didReceiveData?.appendData(data)
    }
}

