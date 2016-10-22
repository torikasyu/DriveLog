//
//  MyAnnotation.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2016/05/04.
//  Copyright © 2016年 TANAKAHiroki. All rights reserved.
//

import Foundation
import MapKit

class MyAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate : CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    var identity: String?
    
    init(location coord:CLLocationCoordinate2D) {
        self.coordinate = coord
        super.init()
    }
}