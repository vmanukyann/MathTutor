import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var appModel: AppModel
    let student: StudentProfile

    @State private var studyLogging = true
    @State private var noAnswerMode = true

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let wide = proxy.size.width > 920

                Group {
                    if wide {
                        HStack(alignment: .center, spacing: 24) {
                            consentHero
                                .frame(maxWidth: 620)
                            consentControls
                                .frame(width: 420)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 18) {
                                consentHero
                                consentControls
                            }
                            .padding(MTTheme.pagePadding)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(wide ? MTTheme.pagePadding : 0)
                .background(MTBackground())
            }
            .navigationTitle("Consent")
            .navigationBarTitleDisplayMode(.inline)
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

    private var consentHero: some View {
        MTGlassPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 24) {
                MTStatusPill(title: "Study Mode", symbol: "doc.text.magnifyingglass", tint: MTTheme.accent)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Before \(student.name) starts")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.75)
                    Text("MathTutor will watch the work, remember learning patterns, and speak only short hints that support self-correction.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    MTInfoRow(
                        title: "Camera observes the page",
                        detail: "The live view is the main surface so the student can keep thinking on paper.",
                        symbol: "camera.viewfinder"
                    )
                    MTInfoRow(
                        title: "Memory shapes future hints",
                        detail: "Mistake types and hint levels become part of the learner profile.",
                        symbol: "person.text.rectangle",
                        tint: MTTheme.success
                    )
                    MTInfoRow(
                        title: "The tutor asks, not solves",
                        detail: "Normal mode blocks final answers and uses Socratic prompts.",
                        symbol: "lock.shield.fill",
                        tint: MTTheme.warning
                    )
                }
            }
        }
    }

    private var consentControls: some View {
        MTGlassPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 18) {
                MTSectionHeader(
                    title: "Session Settings",
                    subtitle: "These defaults protect the study protocol for V1 testing."
                )

                VStack(spacing: 14) {
                    ConsentToggleRow(
                        title: "Log this tutoring session",
                        subtitle: "Saves mistakes, hints, confidence, and self-corrections for research review.",
                        symbol: "externaldrive.badge.checkmark",
                        isOn: $studyLogging
                    )

                    ConsentToggleRow(
                        title: "No-answer integrity mode",
                        subtitle: "Blocks final answers so the app behaves like a teacher, not a solver.",
                        symbol: "lock.shield.fill",
                        isOn: $noAnswerMode
                    )
                    .disabled(true)
                }

                Button {
                    appModel.acceptConsent(for: student)
                } label: {
                    Label("Begin Tutoring", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MTPrimaryButton())
                .disabled(!studyLogging || !noAnswerMode)
            }
        }
    }
}

private struct ConsentToggleRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(MTTheme.accent)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
    }
}
