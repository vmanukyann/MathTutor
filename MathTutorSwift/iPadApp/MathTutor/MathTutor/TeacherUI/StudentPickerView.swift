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
            ZStack {
                MTBackground()

                VStack(spacing: 28) {
                    Spacer(minLength: 28)

                    Text("MathTutor")
                        .font(.system(size: 46, weight: .semibold, design: .serif))
                        .foregroundStyle(MTTheme.chalkboardGreen)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 10) {
                        if appModel.students.isEmpty {
                            emptyStudentButton
                        } else {
                            ForEach(appModel.students) { student in
                                StudentNotebookRow(
                                    student: student,
                                    isSelected: selectedStudent?.id == student.id
                                ) {
                                    selectedStudentID = student.id
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 520)

                    HStack(spacing: 12) {
                        Button {
                            showingNewStudent = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        .buttonStyle(MTIconButton(tint: MTTheme.chalkboardGreen))
                        .accessibilityLabel("Create student")

                        Button {
                            if let selectedStudent {
                                appModel.select(selectedStudent)
                            }
                        } label: {
                            Image(systemName: "arrow.right")
                        }
                        .buttonStyle(MTIconButton(tint: MTTheme.notebookPaper))
                        .background(MTTheme.chalkboardGreen, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
                        .disabled(selectedStudent == nil)
                        .opacity(selectedStudent == nil ? 0.45 : 1)
                        .accessibilityLabel("Begin session")
                    }

                    Spacer(minLength: 28)
                }
                .padding(MTTheme.pagePadding)

                VStack {
                    HStack {
                        VoiceControlIndicator(snapshot: appModel.voiceRecognizer.snapshot)
                            .accessibilityLabel("Voice start available")

                        Spacer()
                        Button {
                            appModel.route = .admin
                        } label: {
                            Image(systemName: "book.closed")
                        }
                        .buttonStyle(MTIconButton(tint: MTTheme.graphiteInk))
                        .accessibilityLabel("Open admin review")
                    }
                    Spacer()
                }
                .padding(24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewStudent) {
                NewStudentSheet()
                    .environmentObject(appModel)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                selectedStudentID = selectedStudent?.id
            }
            .onChange(of: appModel.voiceRecognizer.commandEventID) { _, _ in
                handleVoiceCommand()
            }
        }
    }

    private func handleVoiceCommand() {
        guard let command = appModel.voiceRecognizer.lastRecognizedCommand else { return }
        let action = appModel.voiceRouter.route(
            command,
            in: VoiceRouteContext(
                location: .studentPicker,
                sessionStatus: nil,
                canEnterTeachMode: false,
                holderControlsActive: false
            )
        )
        appModel.voiceRecognizer.recordRoutedAction(action.displayName)

        guard action == .startSession, let selectedStudent else { return }
        appModel.select(selectedStudent)
    }

    private var emptyStudentButton: some View {
        Button {
            showingNewStudent = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                Text("Student")
                    .font(.title3.weight(.medium))
            }
            .foregroundStyle(MTTheme.secondaryInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(MTTheme.gridLine, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create first student")
    }
}

private struct StudentNotebookRow: View {
    let student: StudentProfile
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 16) {
                Text(initials)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? MTTheme.notebookPaper : MTTheme.chalkboardGreen)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? MTTheme.chalkboardGreen : MTTheme.accentSoft, in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(student.name)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(MTTheme.ink)
                    Text(student.mathLevel.displayName)
                        .font(.caption)
                        .foregroundStyle(MTTheme.secondaryInk)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MTTheme.labGreen)
                }
            }
            .padding(14)
            .background(MTTheme.notebookPaper.opacity(0.82), in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(isSelected ? MTTheme.labGreen : MTTheme.gridLine, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(student.name)")
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
            .scrollContentBackground(.hidden)
            .background(MTBackground())
            .navigationTitle("Student")
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
