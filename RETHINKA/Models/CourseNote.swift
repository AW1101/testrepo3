//
//  CourseNote.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
//

import Foundation
import SwiftData

@Model
//pretty basic, just used for setup page, might not be needed, could be integrated elsewhere
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
