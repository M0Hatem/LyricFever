//
//  IDToColor.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa.
//

import Foundation
import CoreData

@objc(IDToColor)
public class IDToColor: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<IDToColor> {
        return NSFetchRequest<IDToColor>(entityName: "IDToColor")
    }

    @NSManaged public var id: String?
    @NSManaged public var songColor: Int32
}
