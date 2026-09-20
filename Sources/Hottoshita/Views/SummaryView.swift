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
    @State private var showBacklogChoice = false
    @State private var includeBacklog = false

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
                body: ReportGenerator.generate(answers: answers, contactName: contactName, userName: userName,
                                               previousUnsent: includeBacklog ? store.unsentEntries(excluding: answers.id) : [])
            ) { result in
                if result == .sent {
                    reportSent = true
                    if includeBacklog {
                        store.markAllUnsentAsSent()
                    } else {
                        store.markSent(id: answers.id)
                    }
                    // Report delivered — show the confirmation briefly, then
                    // return home on the user's behalf.
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        dismiss()
                    }
                } else {
                    // Cancelled, saved as draft, or failed — the contact did
                    // NOT receive the report; make sure the user knows.
                    showNotSentAlert = true
                }
            }
        }
        .alert("Send earlier check-ins too?", isPresented: $showBacklogChoice) {
            Button("Send everything") { includeBacklog = true; showMail = true }
            Button("Only today's") { includeBacklog = false; showMail = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Some earlier check-ins have not been sent yet.")
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
            Text("Please configure an email account on this device to send reports.")
        }
    }

    private var headerBlock: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: isCompactHeight ? 40 : 64))
                .foregroundStyle(appTheme.accent)
                .accessibilityHidden(true)
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
                value: String(localized: String.LocalizationValue(answers.sleep?.rawValue ?? ""))
            )
            summaryRow(
                icon: "face.smiling",
                label: "Feeling",
                value: localizedFeelings
            )
            summaryRow(
                icon: "heart.fill",
                label: "Blood Pressure",
                value: (answers.tookBloodPressure ?? false) && answers.bloodPressure.isValid
                    ? answers.bloodPressure.formatted
                    : String(localized: "Not taken")
            )
        }
    }

    private var actionsBlock: some View {
        VStack(spacing: isCompactHeight ? 12 : 16) {
            if reportSent {
                Label {
                    Text("Report sent!")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                }
                .font(.title3.bold())
                .foregroundStyle(appTheme.accent)
            } else {
                Text("Will be sent to: \(contactName)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if !store.unsentEntries(excluding: answers.id).isEmpty {
                    Text("Some earlier check-ins have not been sent yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                if !saved {
                    store.save(answers)
                    saved = true
                }
                if !MFMailComposeViewController.canSendMail() {
                    showMailError = true
                } else if !store.unsentEntries(excluding: answers.id).isEmpty {
                    // Pending check-ins — let the user decide what this
                    // email should contain.
                    showBacklogChoice = true
                } else {
                    includeBacklog = false
                    showMail = true
                }
            } label: {
                Label {
                    Text(reportSent ? "Send Again" : "Send Report")
                } icon: {
                    Image(systemName: "envelope.fill").accessibilityHidden(true)
                }
                .font(.title2.bold())
                .foregroundStyle(appTheme.onAccent)
                .frame(maxWidth: 420)
                .padding(.vertical, isCompactHeight ? 14 : 22)
            }
            .buttonStyle(.borderedProminent)
            .tint(appTheme.accent)

            // Done and Start Over share a row instead of each taking a full
            // width row — on a 13" iPad portrait, three stacked full-width
            // buttons pushed Start Over below the fold, forcing a scroll.
            HStack(spacing: 16) {
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompactHeight ? 10 : 16)
                }
                .buttonStyle(.bordered)
                .tint(appTheme.accent)

                Button(action: onStartOver) {
                    Label {
                        Text("Start Over")
                    } icon: {
                        Image(systemName: "arrow.counterclockwise").accessibilityHidden(true)
                    }
                    .font(.title3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompactHeight ? 10 : 16)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
    }

    private func summaryRow(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(appTheme.accent)
                .frame(width: 36)
                .accessibilityHidden(true)
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
