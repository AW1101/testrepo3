//
//  CourseNote.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftData

@Model
// Pretty basic, just used it for setup page at one point, either might not be needed or will be reworked to replace exam brief stuff, could be integrated elsewhere?
final class CourseNote {
    var id: UUID
    var title: String
    var content: String
    var dateAdded: Date
    
    init(title: String, content: String) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.dateAdded = Date()
    }
}
