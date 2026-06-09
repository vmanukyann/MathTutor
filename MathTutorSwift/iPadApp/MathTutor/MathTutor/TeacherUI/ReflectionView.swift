import SwiftUI

struct ReflectionView: View {
    @EnvironmentObject private var appModel: AppModel
    let session: TutoringSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MTGlassPanel(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 12) {
                            MTStatusPill(title: "Session saved", symbol: "checkmark.seal.fill", tint: MTTheme.success)

                            Text("Reflection")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                            Text("\(session.student.name) practiced with guidance that supported correction without giving away final answers.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
                        MTMetricCard(title: "Checks", value: "\(session.events.count)", symbol: "viewfinder", tint: MTTheme.accent)
                        MTMetricCard(title: "Mistakes", value: "\(session.mistakeCount)", symbol: "exclamationmark.triangle.fill", tint: MTTheme.warning)
                        MTMetricCard(title: "Corrections", value: "\(session.selfCorrectionCount)", symbol: "checkmark.circle.fill", tint: MTTheme.success)
                    }

                    MTGlassPanel(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 16) {
                            MTSectionHeader(
                                title: "Student Reflection",
                                subtitle: "A short close-out keeps the experience about learning instead of scorekeeping."
                            )

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                                MTInfoRow(
                                    title: "What improved?",
                                    detail: strongestPatternText,
                                    symbol: "arrow.up.forward.circle.fill",
                                    tint: MTTheme.success
                                )
                                MTInfoRow(
                                    title: "What was hard?",
                                    detail: hardestPatternText,
                                    symbol: "exclamationmark.bubble.fill",
                                    tint: MTTheme.warning
                                )
                            }
                        }
                    }

                    MTGlassPanel(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 16) {
                            MTSectionHeader(
                                title: "Recent Tutor Moments",
                                subtitle: "Each row shows the kind of hint the tutor used, not a solved answer."
                            )

                            if session.events.isEmpty {
                                Text("No tutoring events were recorded in this session.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(session.events.suffix(4)) { event in
                                    ReflectionEventRow(event: event)
                                }
                            }
                        }
                    }
                }
                .padding(MTTheme.pagePadding)
            }
            .background(MTBackground())
            .navigationTitle("Reflection")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appModel.returnHome()
                    } label: {
                        Label("Students", systemImage: "person.2.fill")
                    }
                }
            }
        }
    }

    private var strongestPatternText: String {
        if session.selfCorrectionCount > 0 {
            "\(session.student.name) self-corrected \(session.selfCorrectionCount) step\(session.selfCorrectionCount == 1 ? "" : "s") after a hint."
        } else {
            "The next session can watch for a first self-correction moment."
        }
    }

    private var hardestPatternText: String {
        session.events.last?.observation.misconceptionType.displayName ?? "No misconception pattern was logged yet."
    }
}

private struct ReflectionEventRow: View {
    let event: TutorEvent

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: event.studentSelfCorrected ? "checkmark.circle.fill" : "lightbulb.fill")
                .font(.title2)
                .foregroundStyle(event.studentSelfCorrected ? MTTheme.success : MTTheme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.observation.misconceptionType.displayName)
                        .font(.headline)
                    Spacer()
                    Text("Level \(event.observation.hintLevel)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text(event.observation.hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 12)
        }
    }
}
