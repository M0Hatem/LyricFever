//
//  SongToLocale.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa.
//

import Foundation
import CoreData

@objc(SongToLocale)
public class SongToLocale: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongToLocale> {
        return NSFetchRequest<SongToLocale>(entityName: "SongToLocale")
    }

    @NSManaged public var id: String?
    @NSManaged public var locale: String?
}
