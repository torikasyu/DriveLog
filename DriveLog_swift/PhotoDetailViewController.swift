//
//  PhotoDetailView.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2016/05/08.
//  Copyright © 2016年 TANAKAHiroki. All rights reserved.
//

import UIKit

class PhotoDetailViewController : UIViewController {

    var mp:MyPhoto?
    var myPin:MyAnnotation?
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var labelAddress: UILabel!
    
    @IBAction func btnDelete(_ sender: UIButton) {
        
    }
    @IBAction func btnTweet(_ sender: AnyObject) {        
        Util.doTweet((mp?.address!)!, imageData: mp?.image, location: nil)
    }
    @IBAction func btnSaveCameraRoll(_ sender: UIButton) {
        UIImageWriteToSavedPhotosAlbum(self.imageView.image!, self, nil, nil)
    }
    @IBAction func btnBack(_ sender: Any) {
        //self.dismiss(animated: true, completion: nil)
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.image = UIImage(data: (mp?.image)!)
        labelAddress.text = mp?.address
    }
 
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
