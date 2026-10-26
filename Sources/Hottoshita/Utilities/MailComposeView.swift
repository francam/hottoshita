import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    /// Several contacts: BCC, so they don't see each other's addresses.
    var bcc = false
    let subject: String
    let body: String
    var onResult: (MFMailComposeResult) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss, onResult: onResult) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        if bcc {
            vc.setBccRecipients(recipients)
        } else {
            vc.setToRecipients(recipients)
        }
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        let onResult: (MFMailComposeResult) -> Void

        init(dismiss: DismissAction, onResult: @escaping (MFMailComposeResult) -> Void) {
            self.dismiss = dismiss
            self.onResult = onResult
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            dismiss()
            onResult(result)
        }
    }
}
