import MathTutorCore
import SwiftUI

struct StudentPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingNewStudent = false

    var body: some View {
        NavigationStack {
            List {
                Section("Students") {
                    ForEach(appModel.students) { student in
                        Button {
                            appModel.select(student)
                        } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(Color.blue.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                    .overlay(Text(initials(for: student)))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(student.name)
                                        .font(.headline)
                                    Text(student.mathLevel.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let first = student.topMisconceptions.first {
                                    Text(first.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.14))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Section {
                    Button {
                        appModel.route = .admin
                    } label: {
                        Label("iPad Admin Review", systemImage: "chart.bar.doc.horizontal")
                    }
                }
            }
            .navigationTitle("MathTutor")
            .toolbar {
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
            }
        }
    }

    private func initials(for student: StudentProfile) -> String {
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
                TextField("Student name", text: $name)
                Picker("Math level", selection: $level) {
                    ForEach(MathLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
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
