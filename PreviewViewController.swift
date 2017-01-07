//
//  PreviewViewController.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2017/01/04.
//  Copyright © 2017年 TANAKAHiroki. All rights reserved.
//

import UIKit

class PreviewViewController: UIViewController {
    
    //var photoImage:UIImage?
    //var tweetText:String = ""

    var mp:MyPhoto?
    var isAutoConfirm = false
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textboxTweet: UITextField!
    
    @IBAction func btnSave_tapped(_ sender: Any) {
        //unwind action
    }
    @IBAction func btnCancel_tapped(_ sender: Any) {
        //unwind action
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let t = mp?.image {
            self.imageView.image = UIImage(data: t)
        }
        self.textboxTweet.text = mp?.address
        if(isAutoConfirm)
        {
            self.textboxTweet.text = self.textboxTweet.text! + "[Auto Mode]"
        }
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
