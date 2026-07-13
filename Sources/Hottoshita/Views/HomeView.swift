import SwiftUI

struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme
    @State private var showCheckIn = false
    @State private var showSettings = false
    @State private var showHistory = false

    @ScaledMetric(relativeTo: .largeTitle) private var greetingSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title2) private var dateSize: CGFloat = 26

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let key = hour < 12 ? "greeting.morning" : hour < 17 ? "greeting.afternoon" : "greeting.evening"
        return String(format: NSLocalizedString(key, comment: ""), userName)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Text(greeting)
                        .font(.system(size: greetingSize, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: dateSize))
                        .foregroundStyle(.secondary)
                }

                if store.submittedToday {
                    alreadySubmittedBanner
                } else {
                    startButton
                }

                Spacer()

                bottomActions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(appTheme.background)
        }
        .background(appTheme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showCheckIn) {
            CheckInFlowView().environmentObject(appTheme).environmentObject(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appTheme)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView().environmentObject(store).environmentObject(appTheme)
        }
    }

    private var startButton: some View {
        Button { showCheckIn = true } label: {
            VStack(spacing: 16) {
                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: 56))
                Text("Start Today's Check-in")
                    .font(.title.bold())
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: 420)
            .padding(.vertical, 32)
            .padding(.horizontal)
        }
        .buttonStyle(.borderedProminent)
        .tint(appTheme.accent)
        .padding(.horizontal, 32)
    }

    private var bottomActions: some View {
        HStack(spacing: 20) {
            homeActionButton(icon: "clock.arrow.circlepath", title: "History") { showHistory = true }
            homeActionButton(icon: "gear", title: "Settings") { showSettings = true }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }

    private func homeActionButton(icon: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .buttonStyle(.bordered)
        .tint(appTheme.accent)
    }

    private var alreadySubmittedBanner: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(appTheme.accent)
            Text("Already submitted today!")
                .font(.title2.bold())
            Text("Come back tomorrow.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button { showCheckIn = true } label: {
                Text("Submit again anyway").font(.body)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding(32)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 48)
    }
}
