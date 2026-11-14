import Foundation

/// The emailed report, as HTML: a teal header with the app's name, then the
/// day's answers in a tinted box, any earlier unsent check-ins below, and a
/// footer with the logo.
///
/// Built for real mail apps rather than browsers: tables for layout, styles
/// inline (Gmail and Outlook drop most `<style>` rules), no web fonts and no
/// scripts. The name in the header is text, so it shows even when a mail app
/// blocks images. The only thing fetched is the footer's logo, from the
/// public repo that also serves the privacy policy.
enum ReportGenerator {
    static let logoURL = "https://raw.githubusercontent.com/francam/hottoshita/main/email/glyph.png"
    /// The footer links here, so whoever receives the report can get the app.
    static let appStoreURL = "https://apps.apple.com/app/id6814054159"

    private enum Palette {
        static let teal = "#00808f"
        static let ink = "#12201f"
        static let muted = "#5a6b69"
        static let line = "#e1e8e6"
        static let tint = "#e3f1f1"
    }

    private static let font = "-apple-system, BlinkMacSystemFont, 'Hiragino Sans', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
    private static let roundedFont = "ui-rounded, 'SF Pro Rounded', 'Hiragino Maru Gothic ProN', \(font)"

    static func generate(answers: CheckInAnswers, contactName: String, userName: String,
                         previousUnsent: [CheckInAnswers] = []) -> String {
        let greeting = String(format: NSLocalizedString("report.greeting", comment: ""), contactName)
        let intro = String(format: NSLocalizedString("report.intro", comment: ""), userName)
        let footer = NSLocalizedString("report.footer", comment: "")

        var content = """
        <div class="muted" style="font-size:14px;color:\(Palette.muted)">\(escape(longDate(answers.date)))</div>
        <div style="font-size:18px;color:\(Palette.ink);margin-top:18px">\(escape(greeting))</div>
        <div style="font-size:17px;color:\(Palette.ink);margin:10px 0 16px;line-height:1.5">\(escape(intro))</div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="box" style="background:\(Palette.tint);border-radius:14px"><tr><td style="padding:12px 20px">
        \(answersTable(for: answers, emphasizeReading: true))
        </td></tr></table>
        """

        // Catch up on check-ins that were finished but never emailed.
        let backlog = previousUnsent.sorted { $0.date < $1.date }
        if !backlog.isEmpty {
            content += """
            <div style="font-size:15px;color:\(Palette.ink);margin:28px 0 8px">\(escape(NSLocalizedString("report.previous", comment: "")))</div>
            """
            for entry in backlog {
                content += """
                <div style="font-size:14px;font-weight:600;color:\(Palette.ink);margin:14px 0 4px">\(escape(longDate(entry.date)))</div>
                <div class="rule" style="border-left:3px solid \(Palette.line);padding-left:14px">\(answersTable(for: entry, emphasizeReading: false))</div>
                """
            }
        }

        content += """
        <div class="rule" style="margin-top:30px;border-top:1px solid \(Palette.line);padding-top:12px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
        <td style="padding-right:10px;vertical-align:middle"><a href="\(appStoreURL)"><img src="\(logoURL)" width="35" height="32" alt="" style="display:block;border:0"></a></td>
        <td style="vertical-align:middle;font-size:14px;font-weight:700"><a href="\(appStoreURL)" class="link" style="color:\(Palette.teal);text-decoration:none">\(escape(footer))</a></td>
        </tr></table></div>
        """

        return """
        <!doctype html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
        <style>
        @media (prefers-color-scheme: dark) {
          .page { background:#182221 !important; }
          .page div, .page td { color:#e8f0ee !important; }
          .page .muted, .page .label { color:#9db0ad !important; }
          .page .box { background:#173a3c !important; }
          .page .rule { border-color:#2a3836 !important; }
          .page .link { color:#3fb6c2 !important; }
        }
        </style></head>
        <body style="margin:0;padding:0">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:\(Palette.teal)"><tr>
        <td align="center" style="padding:16px 20px;font:700 28px/1 \(roundedFont);color:#ffffff;letter-spacing:.01em">hottoshita</td>
        </tr></table>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="page" style="background:#ffffff"><tr><td style="padding:28px 20px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;font-family:\(font)"><tr><td>
        \(content)
        </td></tr></table>
        </td></tr></table>
        </body></html>
        """
    }

    private static func answersTable(for answers: CheckInAnswers, emphasizeReading: Bool) -> String {
        let sleepValue = NSLocalizedString(answers.sleep?.rawValue ?? "", comment: "")
        let feelingsValue = answers.feelings.isEmpty
            ? NSLocalizedString("Not specified", comment: "")
            : answers.feelings.sorted().map { NSLocalizedString($0, comment: "") }.joined(separator: NSLocalizedString("list.separator", comment: ""))
        let hasReading = (answers.tookBloodPressure ?? false) && answers.bloodPressure.isValid
        let bpValue = hasReading ? answers.bloodPressure.formatted : NSLocalizedString("Not taken", comment: "")

        let rows = [
            (NSLocalizedString("report.sleep", comment: ""), sleepValue, false),
            (NSLocalizedString("report.feeling", comment: ""), feelingsValue, false),
            (NSLocalizedString("report.bp", comment: ""), bpValue, emphasizeReading && hasReading),
        ]
        let cells = rows.map { label, value, large in
            """
            <tr><td class="label" style="padding:8px 16px 8px 0;font-size:15px;color:\(Palette.muted);white-space:nowrap;vertical-align:top">\(escape(label))</td>\
            <td style="padding:8px 0;font-size:\(large ? 22 : 17)px;font-weight:600;color:\(Palette.ink)">\(escape(value))</td></tr>
            """
        }
        return """
        <table role="presentation" cellpadding="0" cellspacing="0">\(cells.joined(separator: "\n"))</table>
        """
    }

    private static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    /// Names are typed by the user; anything that looks like markup must
    /// show as text, not change the email.
    static func escape(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    static func subject(for answers: CheckInAnswers) -> String {
        let dateStr = answers.date.formatted(.dateTime.month().day().year())
        return String(format: NSLocalizedString("report.subject", comment: ""), dateStr)
    }
}
