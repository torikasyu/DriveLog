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
    var timer:Timer!
    var remainSecond = 5.0
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textboxTweet: UITextField!
    @IBOutlet weak var labelRemainTime: UILabel!
    
    @IBAction func btnSave_tapped(_ sender: Any) {
        //unwind action
        
        // Main(ViewController)に設定したManual Unwind Segue
        self.performSegue(withIdentifier: "UnwindActionFromPreviewSegue", sender: self)
        
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
        
        self.labelRemainTime.text = "あと\(String(format:"%g",remainSecond))秒で確定します"
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer.fire()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        //self.navigationController?.setNavigationBarHidden(true, animated: false)

        timer.invalidate()
    }
    
    func update()
    {
        remainSecond = remainSecond - 1.0
        print(remainSecond)
        
        self.labelRemainTime.text = "あと\(String(format:"%g",remainSecond))で確定します"

        if(remainSecond < 0)
        {
            // Main(ViewController)に設定したManual Unwind Segue
            self.performSegue(withIdentifier: "UnwindActionFromPreviewSegue", sender: self)
        }
        
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
