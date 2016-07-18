//
//  ViewController.swift
//
//  Created by DING FENG on 6/3/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    func buttonClicked1() {
        print("表单上传")
        upload1()
    }
    
    func buttonClicked2() {
        print("分块上传")
        upload2()
    }
    
    
    override func viewDidLoad() {
        let button1:UIButton = UIButton(frame: CGRectMake(100, 100, 100, 50))
        button1.setTitle("表单上传", forState: UIControlState.Normal)
        button1.backgroundColor = UIColor.grayColor();
        button1.addTarget(self, action:#selector(self.buttonClicked1), forControlEvents: .TouchUpInside)
        self.view.addSubview(button1)
        
        let button2:UIButton = UIButton(frame: CGRectMake(100, 400, 100, 50))
        button2.setTitle("分块上传", forState: UIControlState.Normal)
        button2.backgroundColor = UIColor.grayColor();
        button2.addTarget(self, action:#selector(self.buttonClicked2), forControlEvents: .TouchUpInside)
        self.view.addSubview(button2)
    }
}



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













