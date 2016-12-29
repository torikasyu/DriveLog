//
//  PhotoDetailView.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2016/05/08.
//  Copyright © 2016年 TANAKAHiroki. All rights reserved.
//

import UIKit

class PhotoDetailViewController : UIViewController {

    var photoid:String?
    var photoImage:UIImage?
    var myPin:MyAnnotation?
    var address:String?
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var labelPhotoid: UILabel!
    @IBOutlet weak var labelAddress: UILabel!
    
    @IBAction func btnDelete(_ sender: UIButton) {
        
    }
    @IBAction func btnTweet(_ sender: AnyObject) {        
        Util.doTweet(address!, imageData: UIImageJPEGRepresentation(photoImage!,100.0), location: nil)
    }
    @IBAction func btnSaveCameraRoll(_ sender: UIButton) {
        UIImageWriteToSavedPhotosAlbum(self.imageView.image!, self, nil, nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.image = photoImage
        labelPhotoid.text = photoid
        labelAddress.text = address
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
