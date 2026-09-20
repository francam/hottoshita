import SwiftUI
import MessageUI

struct HistoryView: View {
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme
    @Environment(\.dismiss) private var dismiss

    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""

    @State private var entryToDelete: CheckInAnswers?
    @State private var showDeleteConfirm = false
    @State private var showMail = false
    @State private var showMailError = false

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "No Check-ins Yet",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("Your completed check-ins will appear here.")
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text("No Check-ins Yet")
                                .font(.headline)
                            Text("Your completed check-ins will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List {
                        ForEach(store.entries.reversed()) { entry in
                            HistoryRowView(entry: entry)
                        }
                        .onDelete { offsets in
                            // Ask before actually deleting — a swipe is easy
                            // to trigger by accident.
                            let reversed = Array(store.entries.reversed())
                            if let first = offsets.first {
                                entryToDelete = reversed[first]
                                showDeleteConfirm = true
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .background(appTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Text("Done")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(appTheme.onAccent)
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appTheme.accent)
                }
            }
            .alert("Delete this check-in?", isPresented: $showDeleteConfirm, presenting: entryToDelete) { entry in
                Button("Delete", role: .destructive) { store.delete(entry) }
                Button("Cancel", role: .cancel) {}
            } message: { entry in
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
            }
            .safeAreaInset(edge: .bottom) {
                if !store.unsentEntries().isEmpty {
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showMail = true
                        } else {
                            showMailError = true
                        }
                    } label: {
                        Label {
                            Text("Send Unsent Check-ins")
                        } icon: {
                            Image(systemName: "envelope.fill").accessibilityHidden(true)
                        }
                        .font(.title3.bold())
                        .foregroundStyle(appTheme.onAccent)
                        .frame(maxWidth: 420)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appTheme.accent)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
            }
            .sheet(isPresented: $showMail) {
                // Newest unsent check-in leads the report; the older ones
                // ride along in the catch-up section.
                let unsent = store.unsentEntries().sorted { $0.date < $1.date }
                if let primary = unsent.last {
                    MailComposeView(
                        recipient: contactEmail,
                        subject: ReportGenerator.subject(for: primary),
                        body: ReportGenerator.generate(answers: primary, contactName: contactName, userName: userName,
                                                       previousUnsent: Array(unsent.dropLast()))
                    ) { result in
                        if result == .sent {
                            store.markAllUnsentAsSent()
                        }
                    }
                }
            }
            .alert("Cannot Send Email", isPresented: $showMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please configure an email account on this device to send reports.")
            }
        }
    }
}

private struct HistoryRowView: View {
    @EnvironmentObject private var appTheme: AppTheme
    let entry: CheckInAnswers

    private var feelingsText: String {
        entry.feelings.isEmpty
            ? String(localized: "Not specified")
            : entry.feelings.map { String(localized: String.LocalizationValue($0)) }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if !entry.sent {
                    Text("Not sent yet")
                        .font(.caption.bold())
                        .foregroundStyle(appTheme.accent)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(appTheme.accent.opacity(0.15), in: Capsule())
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                historyGridRow(
                    icon: "moon.zzz.fill",
                    label: "Sleep",
                    value: String(localized: String.LocalizationValue(entry.sleep?.rawValue ?? ""))
                )
                historyGridRow(icon: "face.smiling", label: "Feeling", value: feelingsText)
                historyGridRow(
                    icon: "heart.fill",
                    label: "Blood Pressure",
                    value: (entry.tookBloodPressure ?? false) && entry.bloodPressure.isValid
                        ? entry.bloodPressure.formatted
                        : String(localized: "Not taken")
                )
            }
        }
        .padding(.vertical, 8)
    }

    private func historyGridRow(icon: String, label: LocalizedStringKey, value: String) -> some View {
        GridRow {
            Image(systemName: icon)
                .foregroundStyle(appTheme.accent)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
    }
}
