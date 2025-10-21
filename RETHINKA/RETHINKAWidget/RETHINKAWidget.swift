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
    let primaryTimeline: TimelineSnapshot?
    let todayQuizzes: [QuizSnapshot]
    let topMistakes: [MistakeSnapshot]
    let mistakeRotationIndex: Int
}

// MARK: - Data Snapshots
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
    let topic: String
    let isCompleted: Bool
    let score: Double?
}

struct MistakeSnapshot: Identifiable {
    let id: UUID
    let question: String
    let correctAnswer: String
    let timesIncorrect: Int
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    var modelContainer: ModelContainer {
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
            print("Widget ERROR: Cannot access App Group!")
            fatalError("Widget: App Groups not configured")
        }
        
        let storeURL = appGroupURL.appendingPathComponent("RETHINKA.sqlite")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            fatalError("Widget: Failed to create ModelContainer: \(error)")
        }
    }
    
    func placeholder(in context: Context) -> QuizEntry {
        QuizEntry(
            date: Date(),
            primaryTimeline: TimelineSnapshot(
                id: UUID(),
                examName: "Sample Exam",
                examDate: Date().addingTimeInterval(86400 * 7),
                daysUntilExam: 7,
                completedQuizzes: 5,
                totalQuizzes: 21,
                progressPercentage: 0.24
            ),
            todayQuizzes: [],
            topMistakes: [],
            mistakeRotationIndex: 0
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuizEntry) -> ()) {
        let entry = fetchCurrentEntry(rotationIndex: 0)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuizEntry>) -> ()) {
        var entries: [QuizEntry] = []
        let baseData = fetchCurrentEntry(rotationIndex: 0)

        // If there are mistakes, create one timeline entry per rotation start index,
        // stepping every 30 seconds so medium (1) and large (5) rotate through the full list.
        let rotationInterval: TimeInterval = 30

        if !baseData.topMistakes.isEmpty {
            let now = Date()
            // number of distinct start indices we should rotate through:
            let rotationCount = max(1, baseData.topMistakes.count)

            for i in 0..<rotationCount {
                let entryDate = now.addingTimeInterval(Double(i) * rotationInterval)
                // We pass the full mistakes list but set the rotationIndex (will be modulo-ed in the views)
                entries.append(QuizEntry(
                    date: entryDate,
                    primaryTimeline: baseData.primaryTimeline,
                    todayQuizzes: baseData.todayQuizzes,
                    topMistakes: baseData.topMistakes,
                    mistakeRotationIndex: i
                ))
            }

            // Schedule next full refresh after one full rotation so data is refreshed
            let nextRefresh = now.addingTimeInterval(Double(rotationCount) * rotationInterval)
            let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
            completion(timeline)
        } else {
            // No mistakes: single static entry, refresh in 5 minutes
            entries.append(baseData)
            let nextRefresh = Date().addingTimeInterval(300)
            let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    
    private func fetchCurrentEntry(rotationIndex: Int) -> QuizEntry {
        let context = ModelContext(modelContainer)
        
        // Fetch active timelines
        let timelineDescriptor = FetchDescriptor<ExamTimeline>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.examDate)]
        )
        
        let timelines = (try? context.fetch(timelineDescriptor)) ?? []
        
        // Get PRIMARY timeline (closest exam date)
        let primaryTimeline = timelines.first
        
        let primarySnapshot: TimelineSnapshot? = primaryTimeline.map { timeline in
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
        
        // Get today's quizzes from PRIMARY timeline only
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var todayQuizzes: [QuizSnapshot] = []
        var allMistakes: [MistakeSnapshot] = []
        
        if let timeline = primaryTimeline {
            let quizzesToday = timeline.dailyQuizzes.filter { quiz in
                calendar.isDate(quiz.date, inSameDayAs: today)
            }
            
            todayQuizzes = quizzesToday.map { quiz in
                QuizSnapshot(
                    id: quiz.id,
                    topic: quiz.topic.isEmpty ? "Daily Quiz" : quiz.topic,
                    isCompleted: quiz.isCompleted,
                    score: quiz.score
                )
            }
            
            // Collect ALL mistakes from completed quizzes
            for quiz in timeline.dailyQuizzes where quiz.isCompleted {
                for question in quiz.questions where !question.isAnsweredCorrectly && question.timesAnsweredIncorrectly > 0 {
                    allMistakes.append(MistakeSnapshot(
                        id: question.id,
                        question: question.question,
                        correctAnswer: question.correctAnswer,
                        timesIncorrect: question.timesAnsweredIncorrectly
                    ))
                }
            }
        }
        
        // Sort mistakes by frequency
        let topMistakes = allMistakes.sorted { $0.timesIncorrect > $1.timesIncorrect }
        
        return QuizEntry(
            date: Date(),
            primaryTimeline: primarySnapshot,
            todayQuizzes: todayQuizzes,
            topMistakes: topMistakes,
            mistakeRotationIndex: rotationIndex
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

// MARK: - Small Widget
struct SmallWidgetView: View {
    let entry: QuizEntry
    
    private var availableQuizCount: Int {
        entry.todayQuizzes.filter { !$0.isCompleted }.count
    }
    
    var body: some View {
        if let timeline = entry.primaryTimeline {
            VStack(spacing: 6) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    VStack(spacing: 1) {
                        Text("\(timeline.daysUntilExam)")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("days til")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.9))
                        Text("exam")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Text(timeline.examName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
                
                if availableQuizCount > 0 {
                    Text("\(availableQuizCount) \(availableQuizCount == 1 ? "quiz" : "quizzes") available")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text("All done!")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                
                Text("No Active\nTimelines")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let entry: QuizEntry
    
    private var availableQuizCount: Int {
        entry.todayQuizzes.filter { !$0.isCompleted }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            if let timeline = entry.primaryTimeline {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 38, height: 38)
                        .overlay(
                            VStack(spacing: 0) {
                                Text("\(timeline.daysUntilExam)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("days")
                                    .font(.system(size: 6))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeline.examName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(availableQuizCount) \(availableQuizCount == 1 ? "quiz" : "quizzes") available")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
            }
            
            // Show rotating mistake
            if !entry.topMistakes.isEmpty {
                let currentMistake = entry.topMistakes[entry.mistakeRotationIndex % entry.topMistakes.count]
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("Review This:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        if entry.topMistakes.count > 1 {
                            let idx = (entry.mistakeRotationIndex % entry.topMistakes.count) + 1
                        }
                    }
                    
                    Text(currentMistake.question)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 4) {
                        Text("A:")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                        Text(currentMistake.correctAnswer)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
            } else if !entry.todayQuizzes.isEmpty {
                VStack(spacing: 6) {
                    ForEach(entry.todayQuizzes.prefix(3)) { quiz in
                        QuizRowCompact(quiz: quiz)
                    }
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.6))
                        Text("All caught up!")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                Spacer()
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Large Widget (5 rotating mistakes)
struct LargeWidgetView: View {
    let entry: QuizEntry
    
    private var availableQuizCount: Int {
        entry.todayQuizzes.filter { !$0.isCompleted }.count
    }
    
    private var displayMistakes: [MistakeSnapshot] {
        guard !entry.topMistakes.isEmpty else { return [] }

        let count = entry.topMistakes.count
        // Always reduce startIndex into 0..<count (defensive)
        let startIndex = entry.mistakeRotationIndex % count
        var mistakes: [MistakeSnapshot] = []

        // collect up to 5 mistakes starting from startIndex, wrapping using modulo
        let toDisplay = min(5, count)
        for i in 0..<toDisplay {
            let index = (startIndex + i) % count
            mistakes.append(entry.topMistakes[index])
        }

        return mistakes
    }
    
    private func rotatingIndicesText(total count: Int, startIndex: Int, maxDisplay: Int = 5) -> String {
        guard count > 0 else { return "" }
        let displayedCount = min(maxDisplay, count)
        var indices: [Int] = []
        indices.reserveCapacity(displayedCount)
        for i in 0..<displayedCount {
            indices.append(((startIndex + i) % count) + 1) // 1-based
        }
        return compressRuns(indices)
    }

    private func compressRuns(_ nums: [Int]) -> String {
        guard !nums.isEmpty else { return "" }
        var parts: [String] = []
        var runStart = nums[0]
        var prev = nums[0]
        for n in nums.dropFirst() {
            if n == prev + 1 {
                prev = n
            } else {
                if runStart == prev {
                    parts.append("\(runStart)")
                } else {
                    parts.append("\(runStart)-\(prev)")
                }
                runStart = n
                prev = n
            }
        }
        if runStart == prev {
            parts.append("\(runStart)")
        } else {
            parts.append("\(runStart)-\(prev)")
        }
        return parts.joined(separator: ",")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            if let timeline = entry.primaryTimeline {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 46, height: 46)
                        .overlay(
                            VStack(spacing: 0) {
                                Text("\(timeline.daysUntilExam)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text("days")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(timeline.examName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(availableQuizCount) \(availableQuizCount == 1 ? "quiz" : "quizzes") available")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack(spacing: 4) {
                            ProgressView(value: timeline.progressPercentage)
                                .tint(.white)
                                .frame(height: 4)
                            
                            Text("\(Int(timeline.progressPercentage * 100))%")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 2)
            
            // Mistakes section
            if !entry.topMistakes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("Review These")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if entry.topMistakes.count > 5 {
                            let count = entry.topMistakes.count
                            let start = entry.mistakeRotationIndex % count
                            let rangeText = rotatingIndicesText(total: count, startIndex: start, maxDisplay: 5)
                        }

                    }
                    
                    ForEach(displayMistakes) { mistake in
                        MistakeCardCompact(mistake: mistake)
                    }
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.6))
                    Text("No mistakes to review!")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Great job!")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compact Components
struct QuizRowCompact: View {
    let quiz: QuizSnapshot
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(quiz.isCompleted ? Color.green : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
            
            Text(quiz.topic)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            if quiz.isCompleted {
                if let score = quiz.score {
                    Text("\(Int(score * 100))%")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                }
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(quiz.isCompleted ? 0.05 : 0.15))
        .cornerRadius(8)
    }
}

struct MistakeCardCompact: View {
    let mistake: MistakeSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mistake.question)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 4) {
                Text("A:")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
                Text(mistake.correctAnswer)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - Lock Screen Widgets
struct AccessoryCircularView: View {
    let entry: QuizEntry
    
    var body: some View {
        if let timeline = entry.primaryTimeline {
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
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 18))
            }
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: QuizEntry
    
    private var availableQuizCount: Int {
        entry.todayQuizzes.filter { !$0.isCompleted }.count
    }
    
    var body: some View {
        if let timeline = entry.primaryTimeline {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeline.examName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label("\(timeline.daysUntilExam) days", systemImage: "calendar")
                        .font(.system(size: 10))
                    Text("days")
                        .font(.system(size: 8))
                        .opacity(0.8)
                    
                    if availableQuizCount > 0 {
                        Label("\(availableQuizCount) left", systemImage: "checklist")
                            .font(.system(size: 10))
                    }
                }
                .opacity(0.8)
            }
        } else {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 14))
                Text("No timelines")
                    .font(.system(size: 11))
            }
        }
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
        .description("Track daily quizzes and review mistakes.")
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
#Preview(as: .systemLarge) {
    RETHINKAWidget()
} timeline: {
    QuizEntry(
        date: .now,
        primaryTimeline: TimelineSnapshot(
            id: UUID(),
            examName: "iOS Development",
            examDate: Date().addingTimeInterval(86400 * 5),
            daysUntilExam: 5,
            completedQuizzes: 8,
            totalQuizzes: 15,
            progressPercentage: 0.53
        ),
        todayQuizzes: [
            QuizSnapshot(id: UUID(), topic: "SwiftUI Basics", isCompleted: false, score: nil),
            QuizSnapshot(id: UUID(), topic: "Data Persistence", isCompleted: false, score: nil)
        ],
        topMistakes: [
            MistakeSnapshot(id: UUID(), question: "What is the difference between @State and @Binding?", correctAnswer: "@State creates storage, @Binding references existing storage", timesIncorrect: 3),
            MistakeSnapshot(id: UUID(), question: "How do you create a custom view modifier?", correctAnswer: "Create a struct conforming to ViewModifier protocol", timesIncorrect: 2),
            MistakeSnapshot(id: UUID(), question: "What is the purpose of @Environment?", correctAnswer: "Access values from the environment", timesIncorrect: 2),
            MistakeSnapshot(id: UUID(), question: "How does SwiftData persistence work?", correctAnswer: "Uses ModelContext to save and fetch objects", timesIncorrect: 1),
            MistakeSnapshot(id: UUID(), question: "What is a GeometryReader used for?", correctAnswer: "Reading size and position of views", timesIncorrect: 1)
        ],
        mistakeRotationIndex: 0
    )
}
