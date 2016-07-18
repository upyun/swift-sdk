# UPYUN Swift SDK
UPYUN Swift SDK 集成:
 [又拍云存储表单上传接口](http://docs.upyun.com/api/form_api/) 
 和
 [又拍云存储分块上传接口](http://docs.upyun.com/api/multipart_upload/)

## 运行环境
- Apple Swift version 2.2
- 支持 iOS 8.0 及以上版本 


## SDK 说明：

 使用时直接在工程中引入 `UpYunSwiftSDK` 文件夹	
 
  __注意:__  `md5` 计算使用了 `Object-C` 模块中的方法，所以需要在 `Bridging-Header` 文件中 引入 `#import <CommonCrypto/CommonCrypto.h>`
  
[在 Swift 工程中添加 Bridging Header](http://stackoverflow.com/questions/24002369/how-to-call-objective-c-code-from-swift/24005242#24005242)
  
   
SDK结构
 
 ```
├── UpYunSwiftSDK
│   ├── UPBlockUploader.swift //分块上传实现
│   ├── UPFormUploader.swift  //表单上传实现
│   ├── UPHTTPClient.swift    //封装了 “urlencoded” 和 “multipart” 两种 POST 请求(基于 NSURLSession)
│   └── UPUtils.swift         //policy 签名，md5 哈希等通用函数

```   

 
## SDK 接口及参数说明
 - 表单上传接口 
 
 ``` 
 
    /*取消上传*/
    func cancel() -> Void 
    
    
    /*表单上传接口，上传策略和签名由本地计算生成
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
                progress: UPProgressHandler?) -> Void
                
                
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
                progress: UPProgressHandler?) -> Void
    
    
 
 ```
 
  - 分块上传接口 
  
  ```    
  
    /*取消上传*/
    func cancel() -> Void
    
    /*分块上传接口，传策略和签名由本地计算生成
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
                progress: UPProgressHandler?) -> Void
  
  
  
    /*分块上传接口，上传策略和签名可以是从服务器获取
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
                progress: UPProgressHandler?) -> Void
  
  ```

 
 
## 代码示例:


 ```
 
 //表单上传

 func upload1() -> Void {
    guard let path = NSBundle.mainBundle().pathForResource("test1", ofType:"jpg"), data = NSData(contentsOfFile: path) else {
        print("没有文件!")
        return
    }
    
    let up = UPFormUploader()
    up.upload(data,
              fileName: "test",
              formAPIKey: "vcVus6Xo+nn51sJmGjqsW8rTpKs=",
              bucketName: "***testBucketName***",
              saveKey: "swifttest1.jpg",
              otherParameters: nil,
              success: { (response, responseObject) in
                print("success: \(responseObject)")
        },
              failure: { (error, response, responseObject) in
                print("failure: \(error)")
                print("failure: \(responseObject)")
        },
              progress: { (completedBytesCount, totalBytesCount) in
                print("progress: \(completedBytesCount) | \(totalBytesCount)")
    })
}




 //分块上传
 
func upload2() -> Void {
    guard let path = NSBundle.mainBundle().pathForResource("test2", ofType:"png") else {
        print("没有文件!")
        return
    }
    let up = UPBlockUploader()
    up.upload(path,
              fileName: "test",
              apiKey: "vcVus6Xo+nn51sJmGjqsW8rTpKs=",
              bucketName: "***testBucketName***",
              saveKey: "swifttest2.png",
              otherParameters:nil,
              success: { (response, responseObject) in
                print("success: \(responseObject)")
        },
              failure: { (error, response, responseObject) in
                print("failure: \(error)")
                print("failure: \(responseObject)")
        },
              progress: { (completedBytesCount, totalBytesCount) in
                print("progress: \(completedBytesCount) | \(totalBytesCount)")
    })
}

 
 
 
  
 ```  
 
 
 
 
 
## 反馈与建议
欢迎直接提 issue, 提 PR。

 
 
