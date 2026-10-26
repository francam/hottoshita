import SwiftUI
import MessageUI

struct SummaryView: View {
    let answers: CheckInAnswers
    let onStartOver: () -> Void

    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @AppStorage(TrustedContacts.storageKey) private var additionalContactsJSON = ""

    private var recipients: ReportRecipients {
        ReportRecipients(primaryName: contactName, primaryEmail: contactEmail,
                         additional: TrustedContacts.decode(additionalContactsJSON))
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isCompactHeight) private var isCompactHeight
    @Environment(\.isDense) private var isDense
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme

    @State private var showMail = false
    @State private var showMailError = false
    /// Couldn't write the history file (storage full); `afterSaveWarning`
    /// is what the user was doing — closing, or sending the report.
    @State private var showSaveFailed = false
    @State private var afterSaveWarning: (() -> Void)?
    @State private var saved = false
    @State private var reportSent = false
    @State private var showNotSentAlert = false
    @State private var showBacklogChoice = false
    @State private var includeBacklog = false
    @State private var fold: Fold?

    private var localizedFeelings: String {
        guard !answers.feelings.isEmpty else { return String(localized: "Not specified") }
        return answers.feelings
            .map { String(localized: String.LocalizationValue($0)) }
            .joined(separator: String(localized: "list.separator"))
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                Group {
                    if let fold {
                        // iPhone Duo inner display: what was answered on one
                        // page (left / top), what to do with it on the other.
                        FoldSplitLayout(fold: fold) {
                            VStack(spacing: 16) {
                                headerBlock
                                summaryRows
                            }
                            .padding(.horizontal, 24)

                            actionsBlock
                                .padding(.horizontal, 24)
                        }
                    } else if isCompactHeight {
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
                        VStack(spacing: isDense ? 20 : 36) {
                            headerBlock
                                .padding(.top, 8)

                            summaryRows
                                .padding(.horizontal, 48)

                            Divider().padding(.horizontal, 48)

                            actionsBlock
                                .padding(.horizontal, 48)
                                .padding(.bottom, isDense ? 16 : 40)
                        }
                    }
                }
                .readsFold($fold)
                .frame(maxWidth: .infinity, minHeight: isCompactHeight || fold != nil ? geo.size.height : 0)
            }
        }
        .background(appTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showMail) {
            MailComposeView(
                recipients: recipients.emails,
                bcc: recipients.usesBCC,
                subject: ReportGenerator.subject(for: answers),
                body: ReportGenerator.generate(answers: answers, contactName: recipients.greetingName, userName: userName,
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
            Text("Your report was not sent to \(recipients.displayNames).")
        }
        .alert("Couldn't Save Check-in", isPresented: $showSaveFailed) {
            Button("OK") {
                afterSaveWarning?()
                afterSaveWarning = nil
            }
        } message: {
            Text("save.failed")
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
                .font(.system(size: isDense ? 40 : 64))
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
        VStack(spacing: isDense ? 10 : 14) {
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
                    : String(localized: "Not taken"),
                singleLine: true
            )
        }
    }

    private var actionsBlock: some View {
        VStack(spacing: isDense ? 12 : 16) {
            if reportSent {
                Label {
                    Text("Report sent!")
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                }
                .font(.title3.bold())
                .foregroundStyle(appTheme.accent)
            } else {
                Text("Will be sent to: \(recipients.displayNames)")
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
                saveOnce(then: startSend)
            } label: {
                Label {
                    Text(reportSent ? "Send Again" : "Send Report")
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } icon: {
                    Image(systemName: "envelope.fill").accessibilityHidden(true)
                }
                .font(.title2.bold())
                .foregroundStyle(appTheme.onAccent)
                .frame(maxWidth: 420)
                .padding(.vertical, isDense ? 14 : 22)
            }
            .primaryActionStyle(accent: appTheme.accent)

            // Done and Start Over share a row instead of each taking a full
            // width row — on a 13" iPad portrait, three stacked full-width
            // buttons pushed Start Over below the fold, forcing a scroll.
            // At accessibility text sizes, though, cramming both into half
            // the width each truncates "Start Over" to "Star…" even after
            // shrinking — stack them instead, since scrolling is already
            // expected at these sizes.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    doneButton
                    startOverButton
                }
            } else {
                HStack(spacing: 16) {
                    doneButton
                    startOverButton
                }
            }
        }
    }

    /// Saves today's check-in (once), then continues with `next` — after a
    /// gentle warning if the history file couldn't be written.
    private func saveOnce(then next: @escaping () -> Void) {
        if !saved {
            store.save(answers)
            saved = true
        }
        if store.saveFailed {
            afterSaveWarning = next
            showSaveFailed = true
        } else {
            next()
        }
    }

    private func startSend() {
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
    }

    private var doneButton: some View {
        Button {
            // Finishing without emailing still counts as today's check-in
            // and shows up in History.
            saveOnce { dismiss() }
        } label: {
            Text("Done")
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isDense ? 10 : 16)
        }
        .secondaryActionStyle(accent: appTheme.accent)
    }

    private var startOverButton: some View {
        Button(action: onStartOver) {
            Label {
                Text("Start Over")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } icon: {
                Image(systemName: "arrow.counterclockwise").accessibilityHidden(true)
            }
            .font(.title3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isDense ? 10 : 16)
        }
        .secondaryActionStyle(accent: .gray)
    }

    /// `singleLine` keeps short values like "128/82 mmHg" from splitting
    /// across lines next to a long label — they shrink slightly instead.
    private func summaryRow(icon: String, label: LocalizedStringKey, value: String, singleLine: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                // Increase Contrast darkens the grey row fill until the
                // accent icon nearly vanishes (measured 1.5:1).
                .foregroundStyle(contrast == .increased ? Color.primary : appTheme.accent)
                .frame(width: 36)
                .accessibilityHidden(true)
            Text(label)
                .font(.title3)
            Spacer()
            Text(value)
                .font(.title3.bold())
                .multilineTextAlignment(.trailing)
                // In the side-by-side layout each row gets half the width;
                // even shrunk, "128/82 mmHg" truncated there (iPhone Duo
                // closed, held sideways), so let it break at the space.
                .lineLimit(singleLine && !isCompactHeight ? 1 : nil)
                .minimumScaleFactor(singleLine ? 0.7 : 1)
        }
        .padding(.vertical, isDense ? 8 : 16)
        .padding(.horizontal, 16)
        // Content layer: a solid surface, not glass.
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}
