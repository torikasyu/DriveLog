//
//  ConfigViewController.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2016/04/30.
//  Copyright © 2016年 TANAKAHiroki. All rights reserved.
//

import UIKit
import Social
import Accounts

class ConfigViewController: UIViewController {

    var accountStore = ACAccountStore()
    //var twName:String?
    //var twAccount:ACAccount?
    
    @IBOutlet weak var distRangeSegCon: UISegmentedControl!
    @IBOutlet weak var switchRelationTwitter: UISwitch!
    
    @IBOutlet weak var labelTwitterID: UILabel!
    @IBOutlet weak var labelAccountID: UILabel!
    
    @IBAction func btnDistRangeSegCon(sender: UISegmentedControl) {

        let ud = NSUserDefaults()
        ud.setInteger(sender.selectedSegmentIndex, forKey: "TweetRange")
    }

    @IBAction func switchRelationTwitterChange(sender: UISwitch) {
        let ud = NSUserDefaults()
        ud.setBool(sender.on, forKey: "RelationTwitter")
        
        if(sender.on)
        {
            self.configureTwitter()
        }
    }
    
    @IBAction func btnTwitterDisconnect(sender: AnyObject) {
        
        let ud = NSUserDefaults()
        ud.setObject(nil, forKey: "TwitterAcName")
        ud.setObject(nil, forKey: "TwitterAcId")
        
        self.labelTwitterID.text = "連動なし"
        self.labelAccountID.text = "";
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let ud = NSUserDefaults()
        
        if let t:Int = ud.integerForKey("TweetRange")
        {
            distRangeSegCon.selectedSegmentIndex = t
        }
        if let t:Bool = ud.boolForKey("RelationTwitter")
        {
            switchRelationTwitter.on = t
        }
        if let t:String = ud.stringForKey("TwitterAcName")
        {
            labelTwitterID.text = t
        }
        else
        {
            labelTwitterID.text = "連動なし"
        }
        
        if let t:String = ud.stringForKey("TwitterAcId")
        {
            labelAccountID.text = t
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Twitter関連Methods
    // MARK: Twitterアカウントセットアップ
    func configureTwitter()
    {
        var isError = false
        var errMsg = ""
        
        if(SLComposeViewController.isAvailableForServiceType(SLServiceTypeTwitter))
        {
            let accountType = accountStore.accountTypeWithAccountTypeIdentifier(ACAccountTypeIdentifierTwitter)
            
            accountStore.requestAccessToAccountsWithType(accountType, options: nil) { (granted:Bool, error:NSError?) -> Void in
                if error != nil {
                    // エラー処理
                    print("error! \(error)")
                    //return
                    isError = true
                    errMsg = "本体の「設定」でTwitterアカウントを設定してください"
                }
                else if !granted {
                    print("error! Twitterアカウントの利用が許可されていません")
                    //return
                    isError = true
                    errMsg = "本体の「設定」でTwitterアカウントの利用を許可してください"
                }
                else
                {
                    // 設定されているTwitterアカウントを取得
                    let accounts = self.accountStore.accountsWithAccountType(accountType) as! [ACAccount]
                    
                    if accounts.count == 0 {
                        print("error! 設定画面からアカウントを設定してください")
                        return
                    }
                    
                    // 保存されたusernameが存在すればそれを使用してアカウントを選択
                    //if(self.twName != nil)
                    //{
                    //    for account in accounts{
                    //        if account.username == self.twName
                    //        {
                    //            self.twAccount = account
                    //        }
                    //    }
                    //}

                    if(accounts.count > 1)
                    {
                        self.showAccountSelectSheet(accounts)
                    }
                    else
                    {
                        let ud = NSUserDefaults()
                        ud.setObject(accounts[0].username, forKey: "TwitterAcName")
                        ud.setObject(accounts[0].identifier, forKey: "TwitterAcId")
                        
                        self.labelTwitterID.text = accounts[0].username
                        self.labelAccountID.text = accounts[0].identifier
                    }
                    
                }
            }
        }
        else
        {
            isError = true
            errMsg = "「設定」でTwitterアカウントを設定してください"
        }
        
        if(isError)
        {
            let alert = UIAlertController(title:"Twitter",message: errMsg,preferredStyle:UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert,animated:true,completion:nil)
            
            isError = false
        }
    }
    
    // MARK: Twitterアカウントが複数設定されている時に選択させる
    private func showAccountSelectSheet(accounts: [ACAccount]) {
        
        let alert = UIAlertController(title: "Twitter",
                                      message: "アカウントを選択してください",
                                      preferredStyle: .ActionSheet)
        
        // アカウント選択のActionSheetを表示するボタン
        for account in accounts {
            alert.addAction(UIAlertAction(title: account.username,
                style: .Default,
                handler: { (action) -> Void in
                    //
                    print("your select account is \(account)")
                    //self.twAccount = account
                    
                    let ud = NSUserDefaults()
                    ud.setObject(account.username, forKey:"TwitterAcName")
                    ud.setObject(account.identifier, forKey:"TwitterAcId")
                    
                    self.labelTwitterID.text = account.username
                    self.labelAccountID.text = account.identifier
            }))
        }
        
        // キャンセルボタン
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        // 表示する
        self.presentViewController(alert, animated: true, completion: nil)
    }
}
