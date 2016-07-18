//
//  UPBlockUploader.swift
//
//  Created by DING FENG on 6/19/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

import Foundation


class UPBlockUploader {
    var fileMD5: String?
    var fileSize: UInt64?
    var lastUploadStatus: NSDictionary?
    var httpClient:UPHTTPClient?
    var _fileInfo: [String: Any]? = nil
    var bucketName: String = ""
    var fileHandle: NSFileHandle? = nil
    var cancelled: Bool = false
    
    /*取消上传*/
    func cancel() -> Void {
        cancelled = true
        httpClient?.cancel()
    }
    
    /*分块上传接口
     参数  filePath:        文件路径
     参数  fileName:        文件名
     参数  apiKey:          表单密钥
     参数  bucketName:      上传空间名
     参数  saveKey:         文件上传的保存路径, 例如：“/2015/0901/file1.jpg”。可用占位符，参考：http://docs.upyun.com/api/form_api/#note1
     参数  otherParameters: 可选的其它参数可以为nil. 参考文档：表单-API-参数http://docs.upyun.com/api/form_api/#api_1
     参数  success:         上传成功回调
     参数  failure:         上传失败回调
     参数  progress:        上传进度回调
     */
    func upload(filePath: String,
                fileName: String,
                apiKey: String,
                bucketName: String,
                saveKey: String,
                otherParameters:[String: String]?,
                success: UPSuccessHandler,
                failure: UPFailureHandler,
                progress: UPProgressHandler?) -> Void {
        
        
        let expirationDate = NSDate(timeIntervalSinceNow:DEFAULT_UPYUN_FORM_API_EXPIRATION)
        var policyDict = ["bucket": bucketName, "path": saveKey, "expiration": String(Int(expirationDate.timeIntervalSince1970))]
        if let otherParameters = otherParameters {
            for (key, value) in otherParameters {
                policyDict[key] = value
            }
        }
        
        let _fileInfo = fileInfo(filePath)
        guard _fileInfo != nil else {
            let error = NSError(domain: "UPBlockUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "no _fileInfo"])
            failure(error: error, response: nil, responseObject: nil)
            return;
        }
        self._fileInfo = _fileInfo
        let file_blocks_array = _fileInfo!["blocks"] as! [Any]
        let file_blocks_len = file_blocks_array.count
        policyDict["file_blocks"] = String(file_blocks_len)
        policyDict["file_hash"] = _fileInfo!["fileMD5"] as? String
        policyDict["file_size"] = String(_fileInfo!["fileSize"] as! UInt64)
        
        let policy = getPolicyFromFormParameters(policyDict)
        let signature = getSignatureFromPolicy(policy, apiKey: apiKey)
        
        self.upload(filePath,
                    policy: policy,
                    signature: signature,
                    success: success,
                    failure: failure,
                    progress: progress)
    }
    
    /*表单上传接口，上传策略和签名可以是从服务器获取
     参数  filePath:        文件路径
     参数  policy:          上传策略
     参数  signature:       上传策略签名
     参数  success:         上传成功回调
     参数  failure:         上传失败回调
     参数  progress:        上传进度回调
     */
    func upload(filePath: String,
                policy: String,
                signature: String,
                success: UPSuccessHandler,
                failure: UPFailureHandler,
                progress: UPProgressHandler?) -> Void {
        
        
        if self._fileInfo == nil {
            self._fileInfo = fileInfo(filePath)
        }
        
        guard self._fileInfo != nil else {
            let error = NSError(domain: "UPBlockUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "no _fileInfo"])
            failure(error: error, response: nil, responseObject: nil)
            return;
        }
        
        uploadInitialize(policy,
                         signature: signature,
                         success: success,
                         failure: failure,
                         progress: progress) {
                            
                            self.uploadFileBlocks(self._fileInfo!["blocks"] as! [Any],
                                                  success: success,
                                                  failure: failure,
                                                  progress: progress,
                                                  done: {
                                                    
                                                    self.combineBlocks(success,
                                                        failure: failure,
                                                        progress: progress)
                            })
        }
    }

    
    private func uploadFileBlockAtIndex(blockInfo:[String: Any],
                                        success: UPSuccessHandler,
                                        failure: UPFailureHandler,
                                        progress: UPProgressHandler?,
                                        done: () -> Void) {
        
        if cancelled {
            let error = NSError(domain: "UPBlockUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "cancelled"])
            failure(error: error, response: nil, responseObject: nil)
            return;
        }
        
        let block_index = blockInfo["block_index"] as! UInt64
        let completedBytesCount: UInt64 =  block_index * UPYUN_FILE_BLOCK_SIZE
        let expirationDate = NSDate(timeIntervalSinceNow:DEFAULT_UPYUN_FORM_API_EXPIRATION)
        
        var  save_token = ""
        if let lastUploadStatus = self.lastUploadStatus,
            saveToken = lastUploadStatus["save_token"] ,
            saveToken_s = saveToken as? String  {
            save_token = saveToken_s
        }
        
        var  token_secret = ""
        if let lastUploadStatus = self.lastUploadStatus,
            tokenSecret = lastUploadStatus["token_secret"] ,
            tokenSecret_s = tokenSecret as? String  {
            token_secret = tokenSecret_s
        }

        let policyDict:[String:String] = ["save_token": save_token,
                                          "block_hash": blockInfo["block_hash"] as! String,
                                          "block_index": String(block_index),
                                          "expiration": String(Int(expirationDate.timeIntervalSince1970))]
        
        let policy = getPolicyFromFormParameters(policyDict)
        let signature = getSignatureFromPolicy(policy, apiKey: token_secret)
        let url = DEFAULT_UPYUN_BLOCKS_API_DOMAIN + "/" + self.bucketName
        let parameters:[String: String] = ["policy": policy, "signature": signature]
        
        guard self.fileHandle != nil else {
            let error = NSError(domain: "UPBlockUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "no fileHandle"])
            failure(error: error, response: nil, responseObject: nil)
            return;
        }
        
        let fileHandler = self.fileHandle!
        let blockRange = blockInfo["block_range"] as! NSRange
        fileHandler.seekToFileOffset(UInt64(blockRange.location))
        let data = fileHandler.readDataOfLength(blockRange.length)

        
        let uPHTTPClient = UPHTTPClient()
        httpClient = uPHTTPClient
        
        // httpClient 进度处理
        let progressHandler: UPHTTPTaskProgressHandler = { (progressResult) in
            if let progress = progress {
                
                var totalSize: Int64 = 0;
                
                if let fileSize = self.fileSize  {
              
                    totalSize = Int64(fileSize)
                }
                
                
                dispatch_async(dispatch_get_main_queue(), {
                    progress(completedBytesCount: progressResult.completedUnitCount + Int64(completedBytesCount), totalBytesCount: totalSize)
                });
            }
        }
        // httpClient 结果处理
        let completionHandler: UPHTTPTaskCompletionHandler = { (data, response, error) in

            
            if let retDict = self.commonCompletionHandlerFilter(success,
                                                                failure: failure,
                                                                data: data,
                                                                response: response,
                                                                error: error) {
                dispatch_async(dispatch_get_main_queue(), {
                    self.lastUploadStatus = retDict;
                    done()
                });
            }
        }
        
        // httpClient 发起请求
        uPHTTPClient.POST(url,
                          parameter: parameters,
                          formName: "file",
                          fileName: "fileName",
                          mimeType: "application/octet-stream",
                          data: data,
                          progressHandler:progressHandler,
                          completionHandler:completionHandler)
    }
    
    private func uploadFileBlocks(blocksInfo: [Any],
                                  success: UPSuccessHandler,
                                  failure: UPFailureHandler,
                                  progress: UPProgressHandler?,
                                  done: () -> Void){
        
        var statusArray = []
        if let statusArray_o = self.lastUploadStatus?["status"]{
            statusArray = statusArray_o as! NSArray
        }
        if statusArray.count < 1 {
            let error = NSError(domain: "UPBlockUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "no statusArray"])
            failure(error: error, response: nil, responseObject: nil)
            return;
        }
        
        for index in 0...statusArray.count - 1 {
            if let ret = statusArray[index] as? Int {
                if ret == 0 {
                    uploadFileBlockAtIndex(blocksInfo[index] as! [String: Any],
                                           success: success,
                                           failure: failure,
                                           progress: progress,
                                           done: {
                                            // 尝试上传余下的 block
                                            self.uploadFileBlocks(self._fileInfo!["blocks"] as! [Any],
                                                success: success,
                                                failure: failure,
                                                progress: progress,
                                                done:done)
                    })
                    return;
                }
            }
        }
        // 所有 block 上传结束
        done();
    }
    
    private func uploadInitialize(policy: String,
                                  signature: String,
                                  success: UPSuccessHandler,
                                  failure: UPFailureHandler,
                                  progress: UPProgressHandler?,
                                  initialized: () -> Void) {
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
        
        var url: String = DEFAULT_UPYUN_BLOCKS_API_DOMAIN
        if let bucketName = policyDict?["bucket"] {
            url = DEFAULT_UPYUN_BLOCKS_API_DOMAIN + "/" + bucketName
            self.bucketName = bucketName
        }
        
        
        let formParameters:[String: String] = ["policy": policy, "signature": signature]
        
        let uPHTTPClient = UPHTTPClient()
        httpClient = uPHTTPClient
        
        // httpClient 结果处理
        let completionHandler: UPHTTPTaskCompletionHandler = { (data, response, error) in
            if let retDict = self.commonCompletionHandlerFilter(success,
                                                                failure: failure,
                                                                data: data,
                                                                response: response,
                                                                error: error) {
                dispatch_async(dispatch_get_main_queue(), {
                    self.lastUploadStatus = retDict;
                    initialized()
                });
            }
        }
        // httpClient 发起请求
        uPHTTPClient.POST(url,
                          parameter: formParameters,
                          completionHandler: completionHandler)

    }
    
    private func combineBlocks(success: UPSuccessHandler,
                               failure: UPFailureHandler,
                               progress: UPProgressHandler?) {
        
        var  save_token = ""
        if let lastUploadStatus = self.lastUploadStatus,
            saveToken = lastUploadStatus["save_token"] ,
            saveToken_s = saveToken as? String  {
            save_token = saveToken_s
        }
        
        var  token_secret = ""
        if let lastUploadStatus = self.lastUploadStatus,
            tokenSecret = lastUploadStatus["token_secret"] ,
            tokenSecret_s = tokenSecret as? String  {
            token_secret = tokenSecret_s
        }

        
        
        let expirationDate = NSDate(timeIntervalSinceNow:DEFAULT_UPYUN_FORM_API_EXPIRATION)
        let policyDict:[String:String] = ["save_token": save_token,
                                          "expiration": String(Int(expirationDate.timeIntervalSince1970))]
        let policy = getPolicyFromFormParameters(policyDict)
        let signature = getSignatureFromPolicy(policy, apiKey: token_secret)
        let url = DEFAULT_UPYUN_BLOCKS_API_DOMAIN + "/" + self.bucketName
        let parameters:[String: String] = ["policy": policy, "signature": signature]

        
        let uPHTTPClient = UPHTTPClient()
        httpClient = uPHTTPClient
        
        // httpClient 结果处理
        let completionHandler: UPHTTPTaskCompletionHandler = { (data, response, error) in
            
            
            if let retDict = self.commonCompletionHandlerFilter(success,
                                                                failure: failure,
                                                                data: data,
                                                                response: response,
                                                                error: error) {
                dispatch_async(dispatch_get_main_queue(), {
                    success(response: response, responseObject: retDict)
                });
            }
        }
        // httpClient 发起请求
        uPHTTPClient.POST(url,
                          parameter: parameters,
                          completionHandler: completionHandler)
    }
    
    
    private func fileInfo(path: String) -> [String: Any]? {
        let handle = NSFileHandle(forReadingAtPath: path)
        guard handle != nil else {
            return nil
        }
        
        self.fileHandle = handle
        self.fileSize = handle!.seekToEndOfFile()
        self.fileMD5 = md5File(path)
        
        guard self.fileSize != nil && self.fileMD5 != nil else {
            return nil
        }
        
        var fileInfo:[String: Any] = [:]
        
        fileInfo["fileSize"] = self.fileSize
        
        var blockCount: UInt64 = self.fileSize! / UPYUN_FILE_BLOCK_SIZE
        let blockRemainder: UInt64 = self.fileSize! % UPYUN_FILE_BLOCK_SIZE
        
        if (blockRemainder > 0) {
            blockCount = blockCount + 1;
        }
        
        
        var blocks:[Any] = []
        for index in 0...blockCount - 1 {
            
            autoreleasepool {
                var loc: UInt64 = index * UPYUN_FILE_BLOCK_SIZE
                var len: UInt64 = UPYUN_FILE_BLOCK_SIZE
                
                if (index == blockCount - 1) {
                    len = self.fileSize! - loc;
                }
                
                let rang: NSRange = NSMakeRange(Int(loc), Int(len))
                handle!.seekToFileOffset(loc)
                let blockData: NSData = handle!.readDataOfLength(Int(len))
                let blockMD5: String = md5Data(blockData)
                
                let blockInfo: [String: Any] = ["block_index": index, "block_range": rang, "block_hash": blockMD5]
                blocks.append(blockInfo)
                loc = loc + len

            }
        }
        
        fileInfo["blocks"] = blocks
        fileInfo["fileSize"] = self.fileSize!
        fileInfo["fileMD5"] = self.fileMD5!
        return fileInfo
    }
    
    private func commonCompletionHandlerFilter(success: UPSuccessHandler,
                                               failure: UPFailureHandler,
                                               data: NSData?,
                                               response: NSHTTPURLResponse?,
                                               error: NSError?)  -> NSDictionary?{
        
        guard error == nil else {
            dispatch_async(dispatch_get_main_queue(), {
                failure(error: error!, response: response, responseObject: nil)
            });
            return nil
        }
        
        guard let data = data else {
            let error = NSError(domain: "UPBlockUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "no data return"])
            
            dispatch_async(dispatch_get_main_queue(), {
                failure(error: error, response: response, responseObject: nil)
            });
            return nil
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
            let error = NSError(domain: "UPBlockUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "data JSONSerialization result error"])
            print("\(String(data: data, encoding: NSUTF8StringEncoding))")
            
            dispatch_async(dispatch_get_main_queue(), {
                failure(error: error, response: response, responseObject: nil)
            });
            return nil
        }
        
        guard let response_ = response else {
            print("may never happen!")
            let error = NSError(domain: "UPBlockUploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "no response return"])
            dispatch_async(dispatch_get_main_queue(), {
                failure(error: error, response: response, responseObject: resultDict)
            });
            return nil
        }
        
        guard response_.statusCode >= 200 && response_.statusCode <= 300 else {
            let error = NSError(domain: "UPBlockUploader", code: response_.statusCode, userInfo: [NSLocalizedDescriptionKey: "upload error"])
            dispatch_async(dispatch_get_main_queue(), {
                failure(error: error, response: response, responseObject: resultDict)
            });
            return nil

        }
        return resultDict_
    }
}



