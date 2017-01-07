//
//  Util.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2016/04/26.
//  Copyright © 2016年 TANAKAHiroki. All rights reserved.
//

import Foundation
import CoreLocation
import Accounts
import Social

class Util
{

    /*
     enum DistRange
    {
        case M50
        case M100
        case M500
        case M1000
        
        var toMeter : Int! {
            switch self
            {
                case M50: return 50
                case M100: return 100
                case M500: return 500
                default: return 1000
            }
        }
    }

    func a()
    {
        var distRange:[Int] = []
        distRange.append(<#T##newElement: Element##Element#>)
    
    }
 */
    
    static func DistRangeIdxToMeter(_ idx:Int) -> Int!
    {
        switch idx {
        case 0:
            return 50
        case 1:
            return 100
        case 2:
            return 500
        case 3:
            return 1000
        case 4:
            return 1
        default:
            return 50
        }
    }
    
    //static func doTweet(status:String,imageData:NSData?,twAccount:ACAccount,location:CLLocationCoordinate2D?)
    static func doTweet(_ status:String,imageData:Data?,location:CLLocationCoordinate2D?)
    {
        // アカウントを取得する
        let defaults = UserDefaults()
        var twAccount:ACAccount?;

        let acs = ACAccountStore()
        if let t = defaults.string(forKey: "TwitterAcId")
        {
            twAccount = acs.account(withIdentifier: t)
        }
        
        // 投稿パラメータ設定
        let URL = Foundation.URL(string: "https://api.twitter.com/1.1/statuses/update_with_media.json")
        var params:Dictionary = ["status" : status]
        
        if let t = location {
            params["lat"] = String(t.latitude)
            params["long"] = String(t.longitude)
        }
        
        // リクエストを生成
        let request = SLRequest(forServiceType: SLServiceTypeTwitter,
                                requestMethod: .POST,
                                url: URL,
                                parameters: params as [AnyHashable: Any])
        
        // 取得したアカウントをセット
        if let t = twAccount
        {
            request?.account = t

            if let t = imageData {
                request?.addMultipartData(t, withName:"media[]", type: "image/jpeg", filename: "image.jpg")
            }
            
            // APIコールを実行
            request?.perform { (responseData, urlResponse, error) -> Void in
                
                if error != nil {
                    print("error is \(error)")
                }
                else {
                    // 結果の表示
                    do {
                        let result = try JSONSerialization.jsonObject(with: responseData!, options: .mutableContainers) as! NSDictionary
                        print("result is \(result)")
                        print(params)
                        
                        // エラーが起こらなければ後続の処理...
                    } catch  {
                        // エラーが起こったらここに来るのでエラー処理などをする
                    }
                }
            }
        }
    }
}
