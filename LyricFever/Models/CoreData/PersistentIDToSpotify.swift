//
//  PersistentIDToSpotify.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa.
//

import Foundation
import CoreData

@objc(PersistentIDToSpotify)
public class PersistentIDToSpotify: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersistentIDToSpotify> {
        return NSFetchRequest<PersistentIDToSpotify>(entityName: "PersistentIDToSpotify")
    }

    @NSManaged public var persistentID: String?
    @NSManaged public var spotifyID: String?
}
