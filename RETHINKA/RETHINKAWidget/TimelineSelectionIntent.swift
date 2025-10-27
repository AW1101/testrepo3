//
//  TimelineSelectionIntent.swift
//  RETHINKA
//
//  Created by Aston Walsh on 23/10/2025.
//

import AppIntents
import SwiftData

// Timeline option for the intent
struct TimelineOption: AppEntity {
    let id: String
    let name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timeline"
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static var defaultQuery = TimelineOptionsQuery()
}

// Query to fetch available timelines
struct TimelineOptionsQuery: EntityQuery {
    func entities(for identifiers: [TimelineOption.ID]) async throws -> [TimelineOption] {
        let options = await fetchTimelineOptions()
        return options.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [TimelineOption] {
        return await fetchTimelineOptions()
    }
    
    func defaultResult() async -> TimelineOption? {
        let options = await fetchTimelineOptions()
        return options.first
    }
    
    private func fetchTimelineOptions() async -> [TimelineOption] {
        let schema = Schema([
            ExamTimeline.self,
            QuizQuestion.self,
            CourseNote.self,
            DailyQuiz.self
        ])
        
        let appGroupID = "group.A4.RETHINKA"
        
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return []
        }
        
        let storeURL = appGroupURL.appendingPathComponent("RETHINKA.sqlite")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<ExamTimeline>(
                predicate: #Predicate { $0.isActive },
                sortBy: [SortDescriptor(\.examDate)]
            )
            
            let timelines = try context.fetch(descriptor)
            
            return timelines.map { timeline in
                TimelineOption(
                    id: timeline.id.uuidString,
                    name: timeline.examName
                )
            }
        } catch {
            print("Error fetching timeline options: \(error)")
            return []
        }
    }
}

// Configuration intent
struct SelectTimelineIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Timeline"
    static var description = IntentDescription("Choose which exam timeline to display")
    
    @Parameter(title: "Timeline")
    var timeline: TimelineOption?
    
    init(timeline: TimelineOption?) {
        self.timeline = timeline
    }
    
    init() {
        self.timeline = nil
    }
}
