import SwiftUI

struct StudentPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingNewStudent = false
    @State private var selectedStudentID: StudentProfile.ID?

    private var selectedStudent: StudentProfile? {
        if let selectedStudentID,
           let student = appModel.students.first(where: { $0.id == selectedStudentID }) {
            return student
        }
        return appModel.students.first
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let compact = proxy.size.width < 900

                Group {
                    if compact {
                        ScrollView {
                            VStack(spacing: 18) {
                                studentColumn

                                if let selectedStudent {
                                    StudentDetailPanel(
                                        student: selectedStudent,
                                        begin: { appModel.select(selectedStudent) },
                                        openAdmin: { appModel.route = .admin }
                                    )
                                } else {
                                    emptyState
                                }
                            }
                            .padding(MTTheme.pagePadding)
                        }
                        .background(MTBackground())
                    } else {
                        HStack(spacing: 24) {
                            studentColumn
                                .frame(width: 360)

                            if let selectedStudent {
                                StudentDetailPanel(
                                    student: selectedStudent,
                                    begin: { appModel.select(selectedStudent) },
                                    openAdmin: { appModel.route = .admin }
                                )
                            } else {
                                emptyState
                            }
                        }
                        .mtPage()
                    }
                }
            }
            .navigationTitle("MathTutor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MTStatusPill(title: "Teacher Mode", symbol: "graduationcap.fill", tint: MTTheme.accent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewStudent = true
                    } label: {
                        Label("New Student", systemImage: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewStudent) {
                NewStudentSheet()
                    .environmentObject(appModel)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                selectedStudentID = selectedStudent?.id
            }
        }
    }

    private var studentColumn: some View {
        MTGlassPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 18) {
                MTSectionHeader(
                    title: "Students",
                    subtitle: "Choose who the tutor is coaching today."
                )

                if appModel.students.isEmpty {
                    MTInfoRow(
                        title: "Create the first learner",
                        detail: "MathTutor builds a memory of each student's patterns after sessions.",
                        symbol: "person.crop.circle.badge.plus"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(appModel.students) { student in
                                StudentRow(
                                    student: student,
                                    isSelected: selectedStudent?.id == student.id
                                ) {
                                    selectedStudentID = student.id
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }

                Button {
                    showingNewStudent = true
                } label: {
                    Label("Create Student", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MTSecondaryButton())
            }
        }
    }

    private var emptyState: some View {
        MTGlassPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .font(.system(size: 64, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(MTTheme.accent)

                MTSectionHeader(
                    title: "Build a learner memory",
                    subtitle: "Create a profile and MathTutor will start tracking patterns, hints, and self-corrections."
                )

                Button {
                    showingNewStudent = true
                } label: {
                    Label("Create First Student", systemImage: "person.badge.plus")
                }
                .buttonStyle(MTPrimaryButton())
            }
        }
    }
}

private struct StudentRow: View {
    let student: StudentProfile
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                Circle()
                    .fill(isSelected ? MTTheme.accentSoft : Color(.tertiarySystemFill))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(initials)
                            .font(.headline.weight(.bold))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(student.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(student.mathLevel.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MTTheme.accent)
                        .font(.title3)
                }
            }
            .padding(14)
            .background(
                isSelected ? MTTheme.accent.opacity(0.10) : Color(.secondarySystemGroupedBackground).opacity(0.55),
                in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(isSelected ? MTTheme.accent.opacity(0.28) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var initials: String {
        student.name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

private struct StudentDetailPanel: View {
    let student: StudentProfile
    let begin: () -> Void
    let openAdmin: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            MTGlassPanel(alignment: .leading) {
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        MTStatusPill(title: "No-answer mode", symbol: "lock.shield.fill", tint: MTTheme.success)
                        Text(student.name)
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.72)
                        Text("Ready for \(student.mathLevel.displayName)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 72, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(MTTheme.accent)
                        .padding(10)
                }

                HStack(spacing: 14) {
                    Button(action: begin) {
                        Label("Begin Session", systemImage: "camera.viewfinder")
                            .frame(minWidth: 190)
                    }
                    .buttonStyle(MTPrimaryButton())

                    Button(action: openAdmin) {
                        Label("Review", systemImage: "chart.bar.doc.horizontal")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(MTSecondaryButton())
                }
            }

            HStack(spacing: 16) {
                MTMetricCard(
                    title: "Known Patterns",
                    value: "\(student.misconceptionCounts.values.reduce(0, +))",
                    symbol: "brain.head.profile",
                    tint: MTTheme.accent
                )
                MTMetricCard(
                    title: "Top Focus",
                    value: student.topMisconceptions.first?.displayName ?? "New",
                    symbol: "target",
                    tint: MTTheme.warning
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                MTInfoRow(
                    title: "Teacher-like memory",
                    detail: "Hints can reference prior patterns without exposing final answers.",
                    symbol: "brain.head.profile"
                )

                MTInfoRow(
                    title: "Quiet by default",
                    detail: "The camera session waits for confidence before interrupting.",
                    symbol: "speaker.badge.exclamationmark",
                    tint: MTTheme.success
                )
            }

            MTGlassPanel(alignment: .leading) {
                VStack(alignment: .leading, spacing: 16) {
                    MTSectionHeader(
                        title: "Misconception Memory",
                        subtitle: "The app personalizes future hints from patterns it observes."
                    )

                    if student.misconceptionCounts.isEmpty {
                        Text("No patterns yet. MathTutor will learn from this student's sessions.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(student.topMisconceptions.prefix(4), id: \.self) { type in
                            HStack {
                                Label(type.displayName, systemImage: "circle.hexagongrid.circle")
                                Spacer()
                                Text("\(student.misconceptionCounts[type, default: 0])")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }
}

private struct NewStudentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var name = ""
    @State private var level: MathLevel = .algebraTwo

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Student name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Math level", selection: $level) {
                        ForEach(MathLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }
            }
            .navigationTitle("New Student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let student = StudentProfile(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            mathLevel: level
                        )
                        appModel.saveStudent(student)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
