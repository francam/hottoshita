import SwiftUI

struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var appTheme: AppTheme
    @State private var showCheckIn = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var fold: Fold?

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
                        if let fold {
                            // iPhone Duo inner display: greeting on one page
                            // (left / top), actions on the other.
                            FoldSplitLayout(fold: fold) {
                                greetingBlock
                                VStack(spacing: 24) {
                                    if store.submittedToday {
                                        alreadySubmittedBanner()
                                    } else {
                                        startButton
                                    }
                                    bottomActions
                                }
                            }
                        } else if isCompactHeight && geo.size.width > geo.size.height * 1.6 {
                            // Landscape iPhone: very wide and short, so the
                            // greeting and the actions sit side by side.
                            // Shapes closer to square (iPhone Duo closed,
                            // held sideways) stack instead: one reading
                            // order, and full-width History/Settings.
                            HStack(spacing: 16) {
                                greetingBlock
                                    .frame(maxWidth: .infinity)
                                VStack(spacing: 16) {
                                    if store.submittedToday {
                                        alreadySubmittedBanner()
                                    } else {
                                        startButton
                                    }
                                    bottomActions
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(spacing: isCompactHeight ? 12 : isShortHeight ? 20 : 40) {
                                Spacer()

                                greetingBlock

                                if store.submittedToday {
                                    alreadySubmittedBanner(row: isCompactHeight)
                                } else {
                                    startButton
                                }

                                Spacer()

                                bottomActions
                            }
                        }
                    }
                    .readsFold($fold)
                    .padding(.vertical, isCompactHeight ? 8 : 16)
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
                .placedOffFold(fold)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView().environmentObject(store).environmentObject(appTheme)
                .cappedDynamicType()
                .detectsShortHeight()
                .placedOffFold(fold)
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
        // Squircle in phone-sized layouts; the default capsule-like shape
        // suits iPad-sized ones better. By size class, not device idiom: the
        // iPhone Duo's inner display is iPad-sized but still an "iPhone".
        .buttonBorderShape(horizontalSizeClass == .compact || verticalSizeClass == .compact
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
            // When the pill is too narrow for icon and word (iPhone Duo
            // closed, held sideways), drop the icon rather than letting the
            // word hyphenate ("His-tory") or shrink.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.title2)
                        .accessibilityHidden(true)
                    Text(title)
                }
                Text(title)
                    .minimumScaleFactor(0.8)
            }
            .font(.title3.weight(.semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isShortHeight ? 14 : 20)
        }
        .secondaryActionStyle(accent: appTheme.accent)
    }

    /// `row`: the stacked layout on a short, wide screen (iPhone Duo
    /// closed, held sideways) — one row instead of a tall card, so History
    /// and Settings still fit below it without scrolling.
    private func alreadySubmittedBanner(row: Bool = false) -> some View {
        Group {
            if row {
                HStack(spacing: 16) {
                    submittedSeal(size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        submittedTitle
                        submittedSubtitle
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    submitAgainButton
                }
                .padding(16)
                .frame(maxWidth: 640)
            } else {
                VStack(spacing: isDense ? 12 : 16) {
                    submittedSeal(size: isDense ? 44 : 64)
                    submittedTitle
                        .multilineTextAlignment(.center)
                    submittedSubtitle
                        .multilineTextAlignment(.center)
                    submitAgainButton
                        .padding(.top, 8)
                }
                .padding(isDense ? 16 : 24)
                .frame(maxWidth: 420)
            }
        }
        // Content layer: a solid card, so its glass button isn't glass on glass.
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 24))
        // Row: same side margin as History/Settings below it.
        .padding(.horizontal, row ? 16 : isCompactHeight ? 0 : 24)
    }

    private func submittedSeal(size: CGFloat) -> some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size))
            // On the grey card, the accent fades under Increase Contrast.
            .foregroundStyle(contrast == .increased ? Color.primary : appTheme.accent)
    }

    private var submittedTitle: some View {
        Text("Already submitted today!")
            .font(.title2.bold())
            .minimumScaleFactor(0.8)
    }

    private var submittedSubtitle: some View {
        Text("Come back tomorrow.")
            .font(.title3)
            .foregroundStyle(.secondary)
    }

    private var submitAgainButton: some View {
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
    }
}
