//
//  PreviewViewController.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2017/01/04.
//  Copyright © 2017年 TANAKAHiroki. All rights reserved.
//

import UIKit

class PreviewViewController: UIViewController {
    
    var photoImage:UIImage?
    var tweetText:String = ""

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textboxTweet: UITextField!
    @IBOutlet weak var switchTweet: UISwitch!
    

    @IBAction func btnSave_tapped(_ sender: Any) {
        //unwind action
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let t = photoImage {
            self.imageView.image = t
        }
        self.textboxTweet.text = tweetText
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
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
