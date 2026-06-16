import SwiftUI

struct AdminReviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingHolderSettings = false

    private var totalMistakes: Int {
        appModel.sessions.map(\.mistakeCount).reduce(0, +)
    }

    private var totalCorrections: Int {
        appModel.sessions.map(\.selfCorrectionCount).reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Research notebook")
                            .font(.system(size: 44, weight: .semibold, design: .serif))
                            .foregroundStyle(MTTheme.chalkboardGreen)

                        HStack(spacing: 14) {
                            NotebookCount(value: "\(appModel.students.count)", label: "students")
                            NotebookCount(value: "\(appModel.sessions.count)", label: "sessions")
                            NotebookCount(value: "\(totalMistakes)", label: "mistakes")
                            NotebookCount(value: "\(totalCorrections)", label: "corrections")
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                        patternsPanel
                        sessionsPanel
                    }
                }
                .padding(MTTheme.pagePadding)
            }
            .background(MTBackground())
            .navigationTitle("Admin")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appModel.returnHome()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHolderSettings = true
                    } label: {
                        Label("Holder", systemImage: "ipad.and.arrow.forward")
                    }
                }
            }
            .sheet(isPresented: $showingHolderSettings) {
                HolderSettingsView(standController: appModel.standController)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var patternsPanel: some View {
        MTGlassPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 18) {
                MTSectionHeader(
                    title: "Student Patterns",
                    subtitle: "Longitudinal signals that make the tutor feel like it knows the learner."
                )

                if appModel.students.isEmpty {
                    MTInfoRow(
                        title: "No profiles yet",
                        detail: "Create a student and run a session to populate research signals.",
                        symbol: "person.crop.circle.badge.plus"
                    )
                } else {
                    ForEach(appModel.students) { student in
                        AdminStudentPatternRow(student: student)
                    }
                }
            }
        }
    }

    private var sessionsPanel: some View {
        MTGlassPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 18) {
                MTSectionHeader(
                    title: "Recent Sessions",
                    subtitle: "A quick audit trail of camera checks, hinting, and corrections."
                )

                if appModel.sessions.isEmpty {
                    MTInfoRow(
                        title: "No completed sessions",
                        detail: "Finished iPad tutoring sessions will appear here for review.",
                        symbol: "calendar.badge.clock"
                    )
                } else {
                    ForEach(appModel.sessions.prefix(8)) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(session.student.name)
                                    .font(.headline)
                                Spacer()
                                Text(session.startedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                MTStatusPill(title: "\(session.events.count) checks", symbol: "viewfinder", tint: MTTheme.accent)
                                MTStatusPill(title: "\(session.selfCorrectionCount) corrections", symbol: "checkmark.circle.fill", tint: MTTheme.success)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }
}

private struct NotebookCount: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
            Text(label)
                .font(.caption)
                .foregroundStyle(MTTheme.secondaryInk)
        }
        .foregroundStyle(MTTheme.ink)
        .padding(.vertical, 4)
        .padding(.trailing, 8)
    }
}

private struct AdminStudentPatternRow: View {
    let student: StudentProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(student.name, systemImage: "person.crop.circle.fill")
                    .font(.headline)
                Spacer()
                Text(student.mathLevel.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MTTheme.secondaryInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MTTheme.accentSoft, in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
            }

            if student.misconceptionCounts.isEmpty {
                Text("No misconception history yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(student.topMisconceptions.prefix(3), id: \.self) { type in
                    HStack {
                        Text(type.displayName)
                            .font(.callout)
                        Spacer()
                        Text("\(student.misconceptionCounts[type, default: 0])")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(MTTheme.notebookPaper.opacity(0.78), in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
    }
}
