import SwiftUI

struct AdminReviewView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose a student")
                    .font(.system(size: 38, weight: .semibold, design: .serif))
                    .foregroundStyle(MTTheme.chalkboardGreen)

                if appModel.students.isEmpty {
                    Text("No students yet")
                        .font(.title3)
                        .foregroundStyle(MTTheme.secondaryInk)
                } else {
                    VStack(spacing: 10) {
                        ForEach(appModel.students) { student in
                            NavigationLink {
                                AdminStudentDetailView(student: student)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.title2)
                                    Text(student.name)
                                        .font(.title3.weight(.semibold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(MTTheme.secondaryInk)
                                }
                                .foregroundStyle(MTTheme.graphiteInk)
                                .padding(16)
                                .frame(maxWidth: 520)
                                .background(MTTheme.notebookPaper)
                                .overlay {
                                    RoundedRectangle(cornerRadius: MTTheme.controlRadius)
                                        .stroke(MTTheme.gridLine, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(MTTheme.pagePadding)
            .background(MTBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appModel.returnHome()
                    } label: {
                        Label("Home", systemImage: "house")
                    }
                }

            }
        }
    }
}

private struct AdminStudentDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let student: StudentProfile

    private var sessions: [TutoringSession] {
        appModel.sessions.filter { $0.student.id == student.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                patterns
                history
            }
            .padding(MTTheme.pagePadding)
        }
        .background(MTBackground())
        .navigationTitle(student.name)
    }

    private var patterns: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Patterns")
                .font(.title2.weight(.semibold))
                .foregroundStyle(MTTheme.chalkboardGreen)

            if student.misconceptionCounts.isEmpty {
                Text("No patterns recorded")
                    .foregroundStyle(MTTheme.secondaryInk)
            } else {
                ForEach(student.topMisconceptions, id: \.self) { type in
                    HStack {
                        Text(type.displayName)
                        Spacer()
                        Text("\(student.misconceptionCounts[type, default: 0])")
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .padding(18)
        .background(MTTheme.notebookPaper)
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.cardRadius)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("History")
                .font(.title2.weight(.semibold))
                .foregroundStyle(MTTheme.chalkboardGreen)

            if sessions.isEmpty {
                Text("No completed sessions")
                    .foregroundStyle(MTTheme.secondaryInk)
            } else {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.startedAt, style: .date)
                            .font(.headline)
                        HStack(spacing: 16) {
                            Label("\(session.events.count)", systemImage: "viewfinder")
                            Label("\(session.mistakeCount)", systemImage: "exclamationmark.triangle")
                            Label("\(session.selfCorrectionCount)", systemImage: "checkmark")
                        }
                        .foregroundStyle(MTTheme.secondaryInk)
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .padding(18)
        .background(MTTheme.notebookPaper)
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.cardRadius)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
