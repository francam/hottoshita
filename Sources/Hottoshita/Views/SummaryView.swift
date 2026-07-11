import SwiftUI
import MessageUI

struct SummaryView: View {
    let answers: CheckInAnswers
    let onStartOver: () -> Void

    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme

    @State private var showMail = false
    @State private var showMailError = false
    @State private var saved = false

    private var localizedFeelings: String {
        guard !answers.feelings.isEmpty else { return String(localized: "Not specified") }
        return answers.feelings
            .map { String(localized: String.LocalizationValue($0)) }
            .joined(separator: ", ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(appTheme.accent)
                    Text("Check-in Complete")
                        .font(.largeTitle.bold())
                    Text(answers.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                VStack(spacing: 14) {
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
                .padding(.horizontal, 48)

                Divider().padding(.horizontal, 48)

                VStack(spacing: 16) {
                    Text("Will be sent to: \(contactName)")
                        .font(.title3)
                        .foregroundStyle(.secondary)

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
                        Label("Send Report", systemImage: "envelope.fill")
                            .font(.title2.bold())
                            .frame(maxWidth: 420)
                            .padding(.vertical, 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appTheme.accent)

                    Button("Done") { dismiss() }
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Button("Start Over", action: onStartOver)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 40)
            }
        }
        .background(appTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showMail) {
            MailComposeView(
                recipient: contactEmail,
                subject: ReportGenerator.subject(for: answers),
                body: ReportGenerator.generate(answers: answers, contactName: contactName, userName: userName)
            )
        }
        .alert("Cannot Send Email", isPresented: $showMailError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please configure an email account on this iPad to send reports.")
        }
    }

    private func summaryRow(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.teal)
                .frame(width: 36)
            Text(label)
                .font(.title3)
            Spacer()
            Text(value)
                .font(.title3.bold())
                .multilineTextAlignment(.trailing)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}
