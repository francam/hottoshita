import SwiftUI
import MessageUI

struct SummaryView: View {
    let answers: CheckInAnswers
    let onStartOver: () -> Void

    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @AppStorage(TrustedContacts.storageKey) private var additionalContactsJSON = ""
    @AppStorage(TrustedContacts.primaryPhotoKey) private var contactPhoto: Data?

    /// Everyone in the trusted contacts list.
    private var everyone: ReportRecipients {
        ReportRecipients(primaryName: contactName, primaryEmail: contactEmail, primaryPhoto: contactPhoto,
                         additional: TrustedContacts.decode(additionalContactsJSON))
    }
    /// Who this report goes to: everyone, minus anyone left out of this one
    /// send (by email, since the list is rebuilt on every read).
    private var recipients: ReportRecipients { everyone.excluding(emails: leftOut) }
    @State private var leftOut: Set<String> = []
    @State private var showRecipientChoice = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isCompactHeight) private var isCompactHeight
    @Environment(\.isDense) private var isDense
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// iPad-sized and upright: larger rows in a centred column, rather than
    /// iPhone-sized rows stretched across the whole width.
    private var isRoomy: Bool { horizontalSizeClass == .regular && fold == nil && !isCompactHeight }
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
                        VStack(spacing: isDense ? 20 : isRoomy ? 48 : 36) {
                            headerBlock
                                .padding(.top, isRoomy ? 32 : 8)

                            summaryRows
                                .padding(.horizontal, 48)

                            Divider().padding(.horizontal, 48)

                            actionsBlock
                                .padding(.horizontal, 48)
                                .padding(.bottom, isDense ? 16 : 40)
                        }
                        .frame(maxWidth: isRoomy ? 680 : .infinity)
                        .frame(maxWidth: .infinity)
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
                .font(.system(size: isDense ? 40 : isRoomy ? 88 : 64))
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

    /// "Will be sent to" and the recipients' pictures, overlapping like a
    /// stack. With several contacts, tapping it chooses who gets this one.
    private var recipientsButton: some View {
        Button { showRecipientChoice = true } label: {
            VStack(spacing: 8) {
                Text("Will be sent to")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(spacing: -14) {
                    ForEach(recipients.contacts) { contact in
                        ContactAvatar(contact: contact, accent: appTheme.accent, size: isDense ? 40 : 48)
                            .overlay { Circle().stroke(appTheme.background, lineWidth: 3) }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(everyone.contacts.count < 2)
        .accessibilityLabel(Text("Will be sent to: \(recipients.displayNames)"))
        .accessibilityHint(everyone.contacts.count < 2 ? Text("") : Text("Double-tap to choose who receives it."))
        .sheet(isPresented: $showRecipientChoice) {
            RecipientChoiceSheet(everyone: everyone, leftOut: $leftOut)
                .environmentObject(appTheme)
                .cappedDynamicType()
                .presentationDetents([.medium, .large])
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
                recipientsButton
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
                .font(isRoomy ? .title2 : .title3)
                // Increase Contrast darkens the grey row fill until the
                // accent icon nearly vanishes (measured 1.5:1).
                .foregroundStyle(contrast == .increased ? Color.primary : appTheme.accent)
                .frame(width: 36)
                .accessibilityHidden(true)
            Text(label)
                .font(isRoomy ? .title2 : .title3)
            Spacer()
            Text(value)
                .font(isRoomy ? .title2.bold() : .title3.bold())
                .multilineTextAlignment(.trailing)
                // In the side-by-side layout each row gets half the width;
                // even shrunk, "128/82 mmHg" truncated there (iPhone Duo
                // closed, held sideways), so let it break at the space.
                .lineLimit(singleLine && !isCompactHeight ? 1 : nil)
                .minimumScaleFactor(singleLine ? 0.7 : 1)
        }
        .padding(.vertical, isDense ? 8 : isRoomy ? 22 : 16)
        .padding(.horizontal, isRoomy ? 22 : 16)
        // Content layer: a solid surface, not glass.
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Who gets this one report: everyone is ticked; untick someone to leave
/// them out this time. Settings' list doesn't change, and at least one
/// person always stays ticked.
private struct RecipientChoiceSheet: View {
    let everyone: ReportRecipients
    @Binding var leftOut: Set<String>
    @EnvironmentObject private var appTheme: AppTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(everyone.contacts) { contact in
                        let key = contact.email.lowercased()
                        let included = !leftOut.contains(key)
                        let isLast = included && leftOut.count == everyone.contacts.count - 1
                        Button {
                            if included { leftOut.insert(key) } else { leftOut.remove(key) }
                        } label: {
                            HStack(spacing: 12) {
                                ContactAvatar(contact: contact, accent: appTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name).font(.title3).foregroundStyle(.primary)
                                    Text(contact.email).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(included ? appTheme.accent : Color.secondary)
                            }
                        }
                        .disabled(isLast)
                        .accessibilityAddTraits(included ? .isSelected : [])
                    }
                } footer: {
                    Text("recipients.choice.footer")
                }
            }
            .navigationTitle("Who gets this report?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("Done").font(.title3.weight(.semibold))
                    }
                    .toolbarSecondaryStyle(accent: appTheme.accent)
                }
            }
        }
    }
}
