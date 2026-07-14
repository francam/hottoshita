import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme
    @Environment(\.dismiss) private var dismiss

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
                    List(store.entries.reversed()) { entry in
                        HistoryRowView(entry: entry)
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
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(.bordered)
                    .tint(appTheme.accent)
                }
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
            Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.headline)
                .foregroundStyle(.primary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                historyGridRow(
                    icon: "moon.zzz.fill",
                    label: "Sleep",
                    value: String(localized: String.LocalizationValue(entry.sleep.rawValue))
                )
                historyGridRow(icon: "face.smiling", label: "Feeling", value: feelingsText)
                historyGridRow(
                    icon: "heart.fill",
                    label: "Blood Pressure",
                    value: entry.tookBloodPressure ? entry.bloodPressure.formatted : String(localized: "Not taken")
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
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
    }
}
