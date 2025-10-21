//
//  RETHINKAWidget.swift
//  RETHINKAWidget
//
//  Created by Aston Walsh on 11/10/2025.
//

// Still all placeholder, needs to be worked on once main stuff is done

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry
struct QuizEntry: TimelineEntry {
    let date: Date
    let timelines: [TimelineSnapshot]
    let todayQuizzes: [QuizSnapshot]
    let topMistakes: [MistakeSnapshot]
}

// MARK: - Data Snapshots (Codable versions for widget)
struct TimelineSnapshot: Identifiable {
    let id: UUID
    let examName: String
    let examDate: Date
    let daysUntilExam: Int
    let completedQuizzes: Int
    let totalQuizzes: Int
    let progressPercentage: Double
}

struct QuizSnapshot: Identifiable {
    let id: UUID
    let timelineId: UUID
    let timelineName: String
    let topic: String
    let dayNumber: Int
    let isCompleted: Bool
    let score: Double?
    let incorrectCount: Int
}

struct MistakeSnapshot: Identifiable {
    let id: UUID
    let topic: String
    let timelineName: String
    let question: String
    let timesIncorrect: Int
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    var modelContainer: ModelContainer {
        // Use the same container configuration as main app
        let schema = Schema([
            ExamTimeline.self,
            QuizQuestion.self,
            CourseNote.self,
            DailyQuiz.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer for widget: \(error)")
        }
    }
    
    func placeholder(in context: Context) -> QuizEntry {
        QuizEntry(
            date: Date(),
            timelines: [
                TimelineSnapshot(
                    id: UUID(),
                    examName: "Sample Exam",
                    examDate: Date().addingTimeInterval(86400 * 7),
                    daysUntilExam: 7,
                    completedQuizzes: 5,
                    totalQuizzes: 21,
                    progressPercentage: 0.24
                )
            ],
            todayQuizzes: [],
            topMistakes: []
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuizEntry) -> ()) {
        let entry = fetchCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuizEntry>) -> ()) {
        let entry = fetchCurrentEntry()
        
        // Update widget every hour, or at midnight for new day
        let calendar = Calendar.current
        let now = Date()
        let midnight = calendar.startOfDay(for: now.addingTimeInterval(86400))
        let oneHour = now.addingTimeInterval(3600)
        
        let nextUpdate = oneHour < midnight ? oneHour : midnight
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchCurrentEntry() -> QuizEntry {
        let context = ModelContext(modelContainer)
        
        // Fetch active timelines
        let timelineDescriptor = FetchDescriptor<ExamTimeline>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.examDate)]
        )
        
        let timelines = (try? context.fetch(timelineDescriptor)) ?? []
        
        // Convert to snapshots
        let timelineSnapshots = timelines.map { timeline in
            TimelineSnapshot(
                id: timeline.id,
                examName: timeline.examName,
                examDate: timeline.examDate,
                daysUntilExam: timeline.daysUntilExam,
                completedQuizzes: timeline.completedQuizCount,
                totalQuizzes: timeline.totalQuizCount,
                progressPercentage: timeline.progressPercentage
            )
        }
        
        // Get today's quizzes across all timelines
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var todayQuizzes: [QuizSnapshot] = []
        var allMistakes: [MistakeSnapshot] = []
        
        for timeline in timelines {
            let quizzesToday = timeline.dailyQuizzes.filter { quiz in
                calendar.isDate(quiz.date, inSameDayAs: today)
            }
            
            todayQuizzes.append(contentsOf: quizzesToday.map { quiz in
                let incorrectCount = quiz.questions.filter { !$0.isAnsweredCorrectly && $0.isAnswered }.count
                return QuizSnapshot(
                    id: quiz.id,
                    timelineId: timeline.id,
                    timelineName: timeline.examName,
                    topic: quiz.topic,
                    dayNumber: quiz.dayNumber,
                    isCompleted: quiz.isCompleted,
                    score: quiz.score,
                    incorrectCount: incorrectCount
                )
            })
            
            // Collect mistakes from all completed quizzes
            for quiz in timeline.dailyQuizzes where quiz.isCompleted {
                for question in quiz.questions where !question.isAnsweredCorrectly && question.timesAnsweredIncorrectly > 0 {
                    allMistakes.append(MistakeSnapshot(
                        id: question.id,
                        topic: quiz.topic,
                        timelineName: timeline.examName,
                        question: question.question,
                        timesIncorrect: question.timesAnsweredIncorrectly
                    ))
                }
            }
        }
        
        // Sort mistakes by times incorrect (most frequent first)
        let topMistakes = Array(allMistakes.sorted { $0.timesIncorrect > $1.timesIncorrect }.prefix(5))
        
        return QuizEntry(
            date: Date(),
            timelines: timelineSnapshots,
            todayQuizzes: todayQuizzes,
            topMistakes: topMistakes
        )
    }
}

// MARK: - Widget Views
struct RETHINKAWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (Single Timeline)
struct SmallWidgetView: View {
    let entry: QuizEntry
    
    private var primaryTimeline: TimelineSnapshot? {
        entry.timelines.first
    }
    
    private var todayQuizCount: Int {
        entry.todayQuizzes.filter { !$0.isCompleted }.count
    }
    
    var body: some View {
        if let timeline = primaryTimeline {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "square.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 55, height: 55)
                    
                    VStack(spacing: 1) {
                        Text("\(timeline.daysUntilExam)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("days")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Text(timeline.examName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if todayQuizCount > 0 {
                    Text("\(todayQuizCount) quiz\(todayQuizCount == 1 ? "" : "es") today")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("All done!")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "square.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                Text("No Active\nTimelines")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium Widget (Today's Quizzes + Mistakes)
struct MediumWidgetView: View {
    let entry: QuizEntry
    
    private var incompleteQuizzes: [QuizSnapshot] {
        entry.todayQuizzes.filter { !$0.isCompleted }
    }
    
    private var completedQuizzes: [QuizSnapshot] {
        entry.todayQuizzes.filter { $0.isCompleted }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "square.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Text(entry.topMistakes.isEmpty ? "Today's Quizzes" : "Review & Quizzes")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if !incompleteQuizzes.isEmpty {
                    Text("\(incompleteQuizzes.count) left")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            if !entry.topMistakes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("Review This:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    
                    Text(entry.topMistakes[0].topic)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(entry.topMistakes[0].question)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(8)
            }
            
            if entry.todayQuizzes.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                        Text("No quizzes today")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(incompleteQuizzes.prefix(entry.topMistakes.isEmpty ? 3 : 2)) { quiz in
                        QuizRowView(quiz: quiz, isCompleted: false, showTimelineName: entry.timelines.count > 1)
                    }
                    
                    if incompleteQuizzes.count < (entry.topMistakes.isEmpty ? 3 : 2) {
                        ForEach(completedQuizzes.prefix((entry.topMistakes.isEmpty ? 3 : 2) - incompleteQuizzes.count)) { quiz in
                            QuizRowView(quiz: quiz, isCompleted: true, showTimelineName: entry.timelines.count > 1)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Large Widget (Full Overview with Mistakes)
struct LargeWidgetView: View {
    let entry: QuizEntry
    
    private var incompleteQuizzes: [QuizSnapshot] {
        entry.todayQuizzes.filter { !$0.isCompleted }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "square.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                Text("RETHINKA")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            if !entry.topMistakes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("Topics to Review")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    ForEach(entry.topMistakes.prefix(2)) { mistake in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(mistake.topic)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(mistake.timesIncorrect)×")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                            }
                            Text(mistake.question)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
            }
            
            if !entry.timelines.isEmpty {
                Text("Active Timelines")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                ForEach(entry.timelines.prefix(2)) { timeline in
                    TimelineRowView(timeline: timeline)
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
            }
            
            HStack {
                Text("Today's Quizzes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                if !incompleteQuizzes.isEmpty {
                    Text("\(incompleteQuizzes.count) remaining")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            if entry.todayQuizzes.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No quizzes today")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 4) {
                    ForEach(entry.todayQuizzes.prefix(4)) { quiz in
                        QuizRowView(quiz: quiz, isCompleted: quiz.isCompleted, showTimelineName: entry.timelines.count > 1)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - Lock Screen Widgets
struct AccessoryCircularView: View {
    let entry: QuizEntry
    
    private var primaryTimeline: TimelineSnapshot? {
        entry.timelines.first
    }
    
    var body: some View {
        if let timeline = primaryTimeline {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text("\(timeline.daysUntilExam)")
                        .font(.system(size: 20, weight: .bold))
                    Text("days")
                        .font(.system(size: 8))
                        .opacity(0.8)
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "square.fill")
                    .font(.system(size: 20))
            }
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: QuizEntry
    
    private var primaryTimeline: TimelineSnapshot? {
        entry.timelines.first
    }
    
    private var todayQuizCount: Int {
        entry.todayQuizzes.filter { !$0.isCompleted }.count
    }
    
    var body: some View {
        if let timeline = primaryTimeline {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "square.fill")
                        .font(.system(size: 12))
                    Text(timeline.examName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    Label("\(timeline.daysUntilExam) days", systemImage: "calendar")
                        .font(.system(size: 10))
                    
                    if todayQuizCount > 0 {
                        Label("\(todayQuizCount) quiz\(todayQuizCount == 1 ? "" : "es")", systemImage: "checklist")
                            .font(.system(size: 10))
                    }
                }
                .opacity(0.8)
            }
        } else {
            HStack {
                Image(systemName: "square.fill")
                    .font(.system(size: 14))
                Text("No active timelines")
                    .font(.system(size: 11))
            }
        }
    }
}

// MARK: - Supporting Views
struct QuizRowView: View {
    let quiz: QuizSnapshot
    let isCompleted: Bool
    let showTimelineName: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isCompleted ? Color.green : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(quiz.topic)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if showTimelineName && !quiz.timelineName.isEmpty {
                    Text(quiz.timelineName)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 4)
            
            if isCompleted {
                if let score = quiz.score {
                    Text("\(Int(score * 100))%")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                }
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "599191"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isCompleted ? 0.08 : 0.15))
        .cornerRadius(8)
    }
}

struct TimelineRowView: View {
    let timeline: TimelineSnapshot
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hex: "599191"))
                    .frame(width: 32, height: 32)
                
                Text("\(timeline.daysUntilExam)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(timeline.examName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(timeline.completedQuizzes)/\(timeline.totalQuizzes) quizzes")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer(minLength: 4)
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                    .frame(width: 26, height: 26)
                
                Circle()
                    .trim(from: 0, to: timeline.progressPercentage)
                    .stroke(Color.white, lineWidth: 2.5)
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(timeline.progressPercentage * 100))")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - Widget Configuration
struct RETHINKAWidget: Widget {
    let kind: String = "RETHINKAWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RETHINKAWidgetEntryView(entry: entry)
                .containerBackground(Color(hex: "0b6374"), for: .widget)
        }
        .configurationDisplayName("Quiz Progress")
        .description("Track daily quizzes, review mistakes, and monitor exam timelines.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    RETHINKAWidget()
} timeline: {
    QuizEntry(
        date: .now,
        timelines: [
            TimelineSnapshot(
                id: UUID(),
                examName: "iOS Development",
                examDate: Date().addingTimeInterval(86400 * 5),
                daysUntilExam: 5,
                completedQuizzes: 8,
                totalQuizzes: 15,
                progressPercentage: 0.53
            )
        ],
        todayQuizzes: [
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "SwiftUI Basics", dayNumber: 3, isCompleted: false, score: nil, incorrectCount: 0),
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "Data Persistence", dayNumber: 3, isCompleted: true, score: 0.85, incorrectCount: 2)
        ],
        topMistakes: []
    )
}

#Preview(as: .systemMedium) {
    RETHINKAWidget()
} timeline: {
    QuizEntry(
        date: .now,
        timelines: [
            TimelineSnapshot(
                id: UUID(),
                examName: "iOS Development",
                examDate: Date().addingTimeInterval(86400 * 5),
                daysUntilExam: 5,
                completedQuizzes: 8,
                totalQuizzes: 15,
                progressPercentage: 0.53
            )
        ],
        todayQuizzes: [
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "SwiftUI Basics", dayNumber: 3, isCompleted: false, score: nil, incorrectCount: 0),
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "Data Persistence", dayNumber: 3, isCompleted: false, score: nil, incorrectCount: 0),
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "Networking", dayNumber: 3, isCompleted: true, score: 0.90, incorrectCount: 1)
        ],
        topMistakes: [
            MistakeSnapshot(id: UUID(), topic: "Core Data", timelineName: "iOS Development", question: "What is the difference between NSManagedObject and NSManagedObjectContext?", timesIncorrect: 3)
        ]
    )
}

#Preview(as: .systemLarge) {
    RETHINKAWidget()
} timeline: {
    QuizEntry(
        date: .now,
        timelines: [
            TimelineSnapshot(
                id: UUID(),
                examName: "iOS Development",
                examDate: Date().addingTimeInterval(86400 * 5),
                daysUntilExam: 5,
                completedQuizzes: 8,
                totalQuizzes: 15,
                progressPercentage: 0.53
            ),
            TimelineSnapshot(
                id: UUID(),
                examName: "Machine Learning",
                examDate: Date().addingTimeInterval(86400 * 12),
                daysUntilExam: 12,
                completedQuizzes: 3,
                totalQuizzes: 36,
                progressPercentage: 0.08
            )
        ],
        todayQuizzes: [
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "SwiftUI Basics", dayNumber: 3, isCompleted: false, score: nil, incorrectCount: 0),
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "Data Persistence", dayNumber: 3, isCompleted: false, score: nil, incorrectCount: 0),
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "Networking", dayNumber: 3, isCompleted: true, score: 0.90, incorrectCount: 1),
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "Machine Learning", topic: "Neural Networks", dayNumber: 1, isCompleted: true, score: 0.75, incorrectCount: 3)
        ],
        topMistakes: [
            MistakeSnapshot(id: UUID(), topic: "Core Data", timelineName: "iOS Development", question: "What is the difference between NSManagedObject and NSManagedObjectContext?", timesIncorrect: 3),
            MistakeSnapshot(id: UUID(), topic: "SwiftUI", timelineName: "iOS Development", question: "Explain the view lifecycle in SwiftUI", timesIncorrect: 2)
        ]
    )
}

#Preview(as: .accessoryCircular) {
    RETHINKAWidget()
} timeline: {
    QuizEntry(
        date: .now,
        timelines: [
            TimelineSnapshot(
                id: UUID(),
                examName: "iOS Development",
                examDate: Date().addingTimeInterval(86400 * 5),
                daysUntilExam: 5,
                completedQuizzes: 8,
                totalQuizzes: 15,
                progressPercentage: 0.53
            )
        ],
        todayQuizzes: [],
        topMistakes: []
    )
}

#Preview(as: .accessoryRectangular) {
    RETHINKAWidget()
} timeline: {
    QuizEntry(
        date: .now,
        timelines: [
            TimelineSnapshot(
                id: UUID(),
                examName: "iOS Development",
                examDate: Date().addingTimeInterval(86400 * 5),
                daysUntilExam: 5,
                completedQuizzes: 8,
                totalQuizzes: 15,
                progressPercentage: 0.53
            )
        ],
        todayQuizzes: [
            QuizSnapshot(id: UUID(), timelineId: UUID(), timelineName: "iOS Development", topic: "SwiftUI Basics", dayNumber: 3, isCompleted: false, score: nil, incorrectCount: 0)
        ],
        topMistakes: []
    )
}

