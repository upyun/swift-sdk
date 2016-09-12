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
    
    override func viewDidLoad() {
        let button1:UIButton = UIButton(frame: CGRectMake(100, 100, 100, 50))
        button1.setTitle("表单上传", forState: UIControlState.Normal)
        button1.backgroundColor = UIColor.grayColor();
        button1.addTarget(self, action:#selector(self.buttonClicked1), forControlEvents: .TouchUpInside)
        self.view.addSubview(button1)
    }
}



func upload1() -> Void {
    guard let path = NSBundle.mainBundle().pathForResource("video", ofType:"mov"), data = NSData(contentsOfFile: path) else {
        print("没有文件!")
        return
    }
    let up = UPFormUploader()
    up.upload(data,
              fileName: "test",
              formAPIKey: "vcVus6Xo+nn51sJmGjqsW8rTpKs=",
              bucketName: "test86400",
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
                
                //for test:http://stackoverflow.com/questions/39409357/nsurlsession-http-2-memory-leak?noredirect=1#comment66210660_39409357
               
                if(completedBytesCount >= 100) {
                    up.cancel();
                }
    })
}








