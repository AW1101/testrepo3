//
//  CourseNote.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftData

@Model
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
