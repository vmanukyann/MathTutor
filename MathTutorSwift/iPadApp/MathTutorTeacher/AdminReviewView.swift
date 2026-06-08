import MathTutorCore
import SwiftUI

struct AdminReviewView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Study Summary") {
                    metricRow("Students", "\(appModel.students.count)")
                    metricRow("Sessions", "\(appModel.sessions.count)")
                    metricRow("Mistakes logged", "\(appModel.sessions.map(\.mistakeCount).reduce(0, +))")
                }

                Section("Student Patterns") {
                    ForEach(appModel.students) { student in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(student.name)
                                .font(.headline)
                            if student.misconceptionCounts.isEmpty {
                                Text("No misconception history yet")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(student.topMisconceptions.prefix(3), id: \.self) { type in
                                    HStack {
                                        Text(type.displayName)
                                        Spacer()
                                        Text("\(student.misconceptionCounts[type, default: 0])")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("Recent Sessions") {
                    ForEach(appModel.sessions) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.student.name)
                                .font(.headline)
                            Text("\(session.events.count) checks, \(session.mistakeCount) mistakes, \(session.selfCorrectionCount) corrections")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Admin Review")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appModel.returnHome()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}
