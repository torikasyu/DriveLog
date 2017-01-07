//
//  MyPhoto.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2017/01/06.
//  Copyright © 2017年 TANAKAHiroki. All rights reserved.
//

import Foundation

class MyPhoto {

    //値受け渡し用クラス
    //Photo+CoreDataPropertiesと同じ内容にする
    var address: String?
    var image: Data?
    var latitude: NSNumber?
    var longiture: NSNumber?
    var memo: String?
    var photoid: String?
    var date: Date?
}
