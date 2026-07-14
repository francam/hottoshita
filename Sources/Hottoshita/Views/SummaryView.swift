import SwiftUI
import MessageUI

struct SummaryView: View {
    let answers: CheckInAnswers
    let onStartOver: () -> Void

    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isCompactHeight) private var isCompactHeight
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme

    @State private var showMail = false
    @State private var showMailError = false
    @State private var saved = false
    @State private var reportSent = false
    @State private var showNotSentAlert = false

    private var localizedFeelings: String {
        guard !answers.feelings.isEmpty else { return String(localized: "Not specified") }
        return answers.feelings
            .map { String(localized: String.LocalizationValue($0)) }
            .joined(separator: ", ")
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                Group {
                    if isCompactHeight {
                        HStack(spacing: 24) {
                            VStack(spacing: 16) {
                                headerBlock
                                summaryRows
                            }
                            .frame(maxWidth: .infinity)

                            actionsBlock
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 36) {
                            headerBlock
                                .padding(.top, 8)

                            summaryRows
                                .padding(.horizontal, 48)

                            Divider().padding(.horizontal, 48)

                            actionsBlock
                                .padding(.horizontal, 48)
                                .padding(.bottom, 40)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: isCompactHeight ? geo.size.height : 0)
            }
        }
        .background(appTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showMail) {
            MailComposeView(
                recipient: contactEmail,
                subject: ReportGenerator.subject(for: answers),
                body: ReportGenerator.generate(answers: answers, contactName: contactName, userName: userName)
            ) { result in
                if result == .sent {
                    reportSent = true
                } else {
                    // Cancelled, saved as draft, or failed — the contact did
                    // NOT receive the report; make sure the user knows.
                    showNotSentAlert = true
                }
            }
        }
        .alert("Report Not Sent", isPresented: $showNotSentAlert) {
            Button("Try Again") { showMail = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your report was not sent to \(contactName).")
        }
        .alert("Cannot Send Email", isPresented: $showMailError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please configure an email account on this iPad to send reports.")
        }
    }

    private var headerBlock: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: isCompactHeight ? 40 : 64))
                .foregroundStyle(appTheme.accent)
            Text("Check-in Complete")
                .font(.largeTitle.bold())
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
            Text(answers.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryRows: some View {
        VStack(spacing: isCompactHeight ? 10 : 14) {
            summaryRow(
                icon: "moon.zzz.fill",
                label: "Sleep",
                value: String(localized: String.LocalizationValue(answers.sleep.rawValue))
            )
            summaryRow(
                icon: "face.smiling",
                label: "Feeling",
                value: localizedFeelings
            )
            summaryRow(
                icon: "heart.fill",
                label: "Blood Pressure",
                value: answers.tookBloodPressure
                    ? answers.bloodPressure.formatted
                    : String(localized: "Not taken")
            )
        }
    }

    private var actionsBlock: some View {
        VStack(spacing: isCompactHeight ? 12 : 16) {
            if reportSent {
                Label("Report sent!", systemImage: "checkmark.circle.fill")
                    .font(.title3.bold())
                    .foregroundStyle(appTheme.accent)
            } else {
                Text("Will be sent to: \(contactName)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Button {
                if !saved {
                    store.save(answers)
                    saved = true
                }
                if MFMailComposeViewController.canSendMail() {
                    showMail = true
                } else {
                    showMailError = true
                }
            } label: {
                Label(reportSent ? "Send Again" : "Send Report", systemImage: "envelope.fill")
                    .font(.title2.bold())
                    .foregroundStyle(appTheme.onAccent)
                    .frame(maxWidth: 420)
                    .padding(.vertical, isCompactHeight ? 14 : 22)
            }
            .buttonStyle(.borderedProminent)
            .tint(appTheme.accent)

            Button {
                // Finishing without emailing still counts as today's
                // check-in and shows up in History.
                if !saved {
                    store.save(answers)
                    saved = true
                }
                dismiss()
            } label: {
                Text("Done")
                    .font(.title3.bold())
                    .frame(maxWidth: 420)
                    .padding(.vertical, isCompactHeight ? 10 : 16)
            }
            .buttonStyle(.bordered)
            .tint(appTheme.accent)

            Button(action: onStartOver) {
                Label("Start Over", systemImage: "arrow.counterclockwise")
                    .font(.title3)
                    .frame(maxWidth: 420)
                    .padding(.vertical, isCompactHeight ? 8 : 12)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }

    private func summaryRow(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(appTheme.accent)
                .frame(width: 36)
            Text(label)
                .font(.title3)
            Spacer()
            Text(value)
                .font(.title3.bold())
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, isCompactHeight ? 8 : 16)
        .padding(.horizontal, 16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}
