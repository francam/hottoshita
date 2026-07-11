import SwiftUI

struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme
    @State private var showCheckIn = false
    @State private var showSettings = false
    @State private var showHistory = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let key = hour < 12 ? "greeting.morning" : hour < 17 ? "greeting.afternoon" : "greeting.evening"
        return String(format: NSLocalizedString(key, comment: ""), userName)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 48) {
                Spacer()

                VStack(spacing: 12) {
                    Text(greeting)
                        .font(.largeTitle.bold())
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                if store.submittedToday {
                    alreadySubmittedBanner
                } else {
                    startButton
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(appTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath").font(.title2)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear").font(.title2)
                    }
                }
            }
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
            VStack(spacing: 12) {
                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: 48))
                Text("Start Today's Check-in")
                    .font(.title2.bold())
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: 400)
            .padding(.vertical, 28)
            .padding(.horizontal)
        }
        .buttonStyle(.borderedProminent)
        .tint(appTheme.accent)
        .padding(.horizontal, 32)
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
