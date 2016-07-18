//
//  UPFormUploader.swift
//
//  Created by DING FENG on 6/5/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

import Foundation


class UPFormUploader {
    var httpClient:UPHTTPClient?
    

    /*取消上传*/
    func cancel() -> Void {
        httpClient?.cancel()
    }
    
    /*表单上传接口
     参数  data:            上传文件数据
     参数  fileName:        上传文件名
     参数  formAPIKey:      表单密钥
     参数  bucketName:      上传空间名
     参数  saveKey:         上传文件的保存路径, 例如：“/2015/0901/file1.jpg”。可用占位符，参考：http://docs.upyun.com/api/form_api/#note1
     参数  otherParameters: 可选的其它参数可以为nil. 参考文档：表单-API-参数http://docs.upyun.com/api/form_api/#api_1
     参数  success:         上传成功回调
     参数  failure:         上传失败回调
     参数  progress:        上传进度回调
     */
    func upload(data: NSData?,
                fileName: String,
                formAPIKey: String,
                bucketName: String,
                saveKey: String,
                otherParameters:[String: String]?,
                success: UPSuccessHandler,
                failure: UPFailureHandler,
                progress: UPProgressHandler?) -> Void {
        
        var upYunformApiParametersDict = ["bucket": bucketName, "save-key": saveKey]
        if let otherParameters = otherParameters {
            for (key, value) in otherParameters {
                upYunformApiParametersDict[key] = value
            }
        }
        let expirationDate = NSDate(timeIntervalSinceNow:DEFAULT_UPYUN_FORM_API_EXPIRATION)
        
        upYunformApiParametersDict["expiration"] = String(Int(expirationDate.timeIntervalSince1970))
        
        let policy = getPolicyFromFormParameters(upYunformApiParametersDict)
        let signature = getSignatureFromPolicy(policy, apiKey: formAPIKey)
        
        upload(data,
               fileName: fileName,
               policy: policy,
               signature: signature,
               success: success,
               failure: failure,
               progress: progress)
    }
    
    /*表单上传接口，上传策略和签名可以是从服务器获取
     参数  data:            上传的数据
     参数  fileName:        上传文件名
     参数  policy:          上传策略
     参数  signature:       上传策略签名
     参数  success:         上传成功回调
     参数  failure:         上传失败回调
     参数  progress:        上传进度回调
     */
    func upload(data: NSData?,
                fileName: String,
                policy: String,
                signature: String,
                success: UPSuccessHandler,
                failure: UPFailureHandler,
                progress: UPProgressHandler?) -> Void {
        
        var policyDict:[String:String]?
        if let policyDecodedData = NSData(base64EncodedString: policy, options: NSDataBase64DecodingOptions(rawValue: 0)) {
            do {
                if let jsonResult = try NSJSONSerialization.JSONObjectWithData(policyDecodedData, options: []) as? [String:String] {
                    policyDict = jsonResult
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        
        var url: String = DEFAULT_UPYUN_FORM_API_DOMAIN
        
        if let bucketName = policyDict?["bucket"] {
            url = DEFAULT_UPYUN_FORM_API_DOMAIN + "/" + bucketName
        }
        
        let formParameters:[String: String] = ["policy": policy, "signature": signature]
        
        let uPHTTPClient = UPHTTPClient()
        httpClient = uPHTTPClient
        
        // httpClient 进度处理
        let progressHandler: UPHTTPTaskProgressHandler = { (progressResult) in
            if let progress = progress {
                dispatch_async(dispatch_get_main_queue(), {
                    progress(completedBytesCount: progressResult.completedUnitCount, totalBytesCount: progressResult.totalUnitCount)
                });
            }
        }
        // httpClient 结果处理
        let completionHandler: UPHTTPTaskCompletionHandler = { (data, response, error) in
            guard error == nil else {
                dispatch_async(dispatch_get_main_queue(), {
                    failure(error: error!, response: response, responseObject: nil)
                });
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "UPFormUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "no data return"])
                
                dispatch_async(dispatch_get_main_queue(), {
                    failure(error: error, response: response, responseObject: nil)
                });
                return
            }
            
            var resultDict: NSDictionary?
            do {
                if let dict = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? NSDictionary {
                    resultDict = dict
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
            
            guard let resultDict_ = resultDict else {
                let error = NSError(domain: "UPFormUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "data JSONSerialization result error"])
                print("\(String(data: data, encoding: NSUTF8StringEncoding))")
                
                dispatch_async(dispatch_get_main_queue(), {
                    failure(error: error, response: response, responseObject: nil)
                });
                return
            }
            
            guard let response_ = response else {
                print("may never happen!")
                let error = NSError(domain: "UPFormUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "no response return"])
                
                dispatch_async(dispatch_get_main_queue(), {
                    failure(error: error, response: response, responseObject: resultDict)
                });
                return
            }
            
            guard response_.statusCode >= 200 && response_.statusCode <= 300 else {
                let error = NSError(domain: "UPFormUploader", code: response_.statusCode, userInfo: [NSLocalizedDescriptionKey: "upload error"])
                dispatch_async(dispatch_get_main_queue(), {
                    failure(error: error, response: response, responseObject: resultDict)
                });
                
                return
            }
            dispatch_async(dispatch_get_main_queue(), {
                success(response: response, responseObject: resultDict_)
            });
        }
        
        // httpClient 发起请求
        uPHTTPClient.POST(url,
                          parameter: formParameters,
                          formName: "file",
                          fileName: fileName,
                          mimeType: "application/octet-stream",
                          data: data,
                          progressHandler:progressHandler,
                          completionHandler:completionHandler)
        
    }
    
}

