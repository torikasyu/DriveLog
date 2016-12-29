//
//  Photo+CoreDataProperties.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2016/05/05.
//  Copyright © 2016年 TANAKAHiroki. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Photo {

    @NSManaged var address: String?
    @NSManaged var image: Data?
    @NSManaged var latitude: NSNumber?
    @NSManaged var longiture: NSNumber?
    @NSManaged var memo: String?
    @NSManaged var photoid: String?
    @NSManaged var date: Date?

}
