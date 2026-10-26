import SwiftUI
import UIKit

struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme
    @State private var showCheckIn = false
    @State private var showSettings = false
    @State private var showHistory = false

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorSchemeContrast) private var contrast

    @ScaledMetric(relativeTo: .largeTitle) private var greetingSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title2) private var dateSize: CGFloat = 26

    /// Landscape on iPhone: lay content out side-by-side and shrink the
    /// oversized paddings so the screen fits without scrolling.
    private var isCompactHeight: Bool { verticalSizeClass == .compact }
    @Environment(\.isShortHeight) private var isShortHeight
    /// Compact height or a short screen (iPhone SE): tighter spacing only.
    private var isDense: Bool { isCompactHeight || isShortHeight }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        // The small hours (0–4) are still "evening", not "morning".
        let key = hour < 5 ? "greeting.evening"
                : hour < 12 ? "greeting.morning"
                : hour < 17 ? "greeting.afternoon"
                : "greeting.evening"
        return String(format: NSLocalizedString(key, comment: ""), userName)
    }

    var body: some View {
        NavigationStack {
            // Scrollable so nothing is cut off in landscape / small heights;
            // content centres itself when there's room.
            GeometryReader { geo in
                ScrollView {
                    Group {
                        if isCompactHeight {
                            HStack(spacing: 16) {
                                greetingBlock
                                    .frame(maxWidth: .infinity)
                                VStack(spacing: 16) {
                                    if store.submittedToday {
                                        alreadySubmittedBanner
                                    } else {
                                        startButton
                                    }
                                    bottomActions
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(spacing: isShortHeight ? 20 : 40) {
                                Spacer()

                                greetingBlock

                                if store.submittedToday {
                                    alreadySubmittedBanner
                                } else {
                                    startButton
                                }

                                Spacer()

                                bottomActions
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
            .background(appTheme.background)
        }
        .background(appTheme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showCheckIn) {
            CheckInFlowView().environmentObject(appTheme).environmentObject(store)
                .cappedDynamicType()
                .detectsShortHeight()
        }
        .sheet(isPresented: $showSettings, onDismiss: { appTheme.updateAppIcon() }) {
            SettingsView().environmentObject(appTheme)
                .cappedDynamicType()
                .detectsShortHeight()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView().environmentObject(store).environmentObject(appTheme)
                .cappedDynamicType()
                .detectsShortHeight()
        }
    }

    private var greetingBlock: some View {
        VStack(spacing: 12) {
            Text(greeting)
                .font(.system(size: greetingSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: dateSize))
                .foregroundStyle(.secondary)
        }
    }

    private var startButton: some View {
        Button { showCheckIn = true } label: {
            VStack(spacing: 16) {
                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: isDense ? 40 : 56))
                    .accessibilityHidden(true)
                Text("Start Today's Check-in")
                    .font(.title.bold())
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(appTheme.onAccent)
            .frame(maxWidth: 420)
            .padding(.vertical, isDense ? 20 : 32)
            .padding(.horizontal)
        }
        .primaryActionStyle(accent: appTheme.accent)
        // Squircle on iPhone; the default capsule-like shape suits iPad better.
        .buttonBorderShape(UIDevice.current.userInterfaceIdiom == .phone
                           ? .roundedRectangle(radius: 36) : .automatic)
        .padding(.horizontal, isCompactHeight ? 16 : 32)
    }

    private var bottomActions: some View {
        HStack(spacing: 20) {
            homeActionButton(icon: "clock.arrow.circlepath", title: "History") { showHistory = true }
            homeActionButton(icon: "gear", title: "Settings") { showSettings = true }
        }
        .padding(.horizontal, isCompactHeight ? 16 : 32)
        .padding(.bottom, isCompactHeight ? 0 : isShortHeight ? 8 : 16)
    }

    private func homeActionButton(icon: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2)
                    .accessibilityHidden(true)
                Text(title).font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isShortHeight ? 14 : 20)
        }
        .secondaryActionStyle(accent: appTheme.accent)
    }

    private var alreadySubmittedBanner: some View {
        VStack(spacing: isDense ? 12 : 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: isDense ? 44 : 64))
                // On the grey card, the accent fades under Increase Contrast.
                .foregroundStyle(contrast == .increased ? Color.primary : appTheme.accent)
            Text("Already submitted today!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            Text("Come back tomorrow.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showCheckIn = true } label: {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityHidden(true)
                    Text("Submit again anyway")
                }
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.8)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
            .secondaryActionStyle(accent: appTheme.accent)
            .padding(.top, 8)
        }
        .padding(isDense ? 16 : 24)
        .frame(maxWidth: 420)
        // Content layer: a solid card, so its glass button isn't glass on glass.
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, isCompactHeight ? 0 : 24)
    }
}
