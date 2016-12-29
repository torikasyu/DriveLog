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
    
    @IBAction func btnDistRangeSegCon(_ sender: UISegmentedControl) {

        let ud = UserDefaults()
        ud.set(sender.selectedSegmentIndex, forKey: "TweetRange")
    }

    @IBAction func switchRelationTwitterChange(_ sender: UISwitch) {
        let ud = UserDefaults()
        ud.set(sender.isOn, forKey: "RelationTwitter")
        
        if(sender.isOn)
        {
            self.configureTwitter()
        }
    }
    
    @IBAction func btnTwitterDisconnect(_ sender: AnyObject) {
        
        let ud = UserDefaults()
        ud.set(nil, forKey: "TwitterAcName")
        ud.set(nil, forKey: "TwitterAcId")
        
        self.labelTwitterID.text = "連動なし"
        self.labelAccountID.text = "";
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let ud = UserDefaults()
        
        if let t:Int = ud.integer(forKey: "TweetRange") as Int?
        {
            distRangeSegCon.selectedSegmentIndex = t
        }
        if let t:Bool = ud.bool(forKey: "RelationTwitter") as Bool?
        {
            switchRelationTwitter.isOn = t
        }
        if let t:String = ud.string(forKey: "TwitterAcName")
        {
            labelTwitterID.text = t
        }
        else
        {
            labelTwitterID.text = "連動なし"
        }
        
        if let t:String = ud.string(forKey: "TwitterAcId")
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
        
        if(SLComposeViewController.isAvailable(forServiceType: SLServiceTypeTwitter))
        {
            let accountType = accountStore.accountType(withAccountTypeIdentifier: ACAccountTypeIdentifierTwitter)
            
            //accountStore.requestAccessToAccounts(with: accountType, options: nil) { (granted:Bool, error:NSError?) -> Void in
            accountStore.requestAccessToAccounts(with: accountType, options: nil) { (success:Bool, error:Error?) -> Void in
                if error != nil {
                    // エラー処理
                    print("error! \(error)")
                    //return
                    isError = true
                    errMsg = "本体の「設定」でTwitterアカウントを設定してください"
                }
                else if !success {
                    print("error! Twitterアカウントの利用が許可されていません")
                    //return
                    isError = true
                    errMsg = "本体の「設定」でTwitterアカウントの利用を許可してください"
                }
                else
                {
                    // 設定されているTwitterアカウントを取得
                    let accounts = self.accountStore.accounts(with: accountType) as! [ACAccount]
                    
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
                        let ud = UserDefaults()
                        ud.set(accounts[0].username, forKey: "TwitterAcName")
                        ud.set(accounts[0].identifier, forKey: "TwitterAcId")
                        
                        self.labelTwitterID.text = accounts[0].username
                        self.labelAccountID.text = accounts[0].identifier as String?
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
            let alert = UIAlertController(title:"Twitter",message: errMsg,preferredStyle:UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert,animated:true,completion:nil)
            
            isError = false
        }
    }
    
    // MARK: Twitterアカウントが複数設定されている時に選択させる
    fileprivate func showAccountSelectSheet(_ accounts: [ACAccount]) {
        
        let alert = UIAlertController(title: "Twitter",
                                      message: "アカウントを選択してください",
                                      preferredStyle: .actionSheet)
        
        // アカウント選択のActionSheetを表示するボタン
        for account in accounts {
            alert.addAction(UIAlertAction(title: account.username,
                style: .default,
                handler: { (action) -> Void in
                    //
                    print("your select account is \(account)")
                    //self.twAccount = account
                    
                    let ud = UserDefaults()
                    ud.set(account.username, forKey:"TwitterAcName")
                    ud.set(account.identifier, forKey:"TwitterAcId")
                    
                    self.labelTwitterID.text = account.username
                    self.labelAccountID.text = account.identifier as String?
            }))
        }
        
        // キャンセルボタン
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // 表示する
        self.present(alert, animated: true, completion: nil)
    }
}
