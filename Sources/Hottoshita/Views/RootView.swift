import SwiftUI

struct RootView: View {
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""

    @AppStorage("userName") private var userName = ""

    private var isOnboarded: Bool { !userName.isEmpty && !contactName.isEmpty && !contactEmail.isEmpty }

    var body: some View {
        if isOnboarded {
            HomeView()
        } else {
            OnboardingView()
        }
    }
}
