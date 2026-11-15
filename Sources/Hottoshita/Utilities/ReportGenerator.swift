import Foundation

/// The emailed report, as HTML, in the app's look: the "hottoshita" band in
/// the sender's theme colour, a background fading from that colour to white,
/// and a rounded card with a check seal, the greeting and one rounded row per
/// answer, like the app's summary. Earlier unsent check-ins follow in their own
/// card, and a small capsule with the logo closes it.
///
/// Built for real mail apps rather than browsers: tables for layout, styles
/// inline (Gmail and Outlook drop most `<style>` rules, so the only stylesheet
/// is the dark-mode one, and mail apps that ignore it still get the light
/// version), no web fonts and no scripts. Mail apps that don't draw CSS
/// gradients show the flat background colour. The name in the band is text, so
/// it shows even when a mail app blocks images. The only thing fetched is the
/// footer's logo, from the public repo that also serves the privacy policy.
enum ReportGenerator {
    static let logoURL = "https://raw.githubusercontent.com/francam/hottoshita/main/email/glyph.png"
    /// The footer links here, so whoever receives the report can get the app.
    static let appStoreURL = "https://apps.apple.com/app/id6814054159"

    /// The colours for one theme, light and dark, as hex for inline styles.
    /// Mirrors ColorTheme (AppTheme.swift), which this Foundation-only file
    /// can't import.
    struct Palette {
        // Light
        let accent: String      // band, seal, link text
        let glow: String        // top of the background gradient
        let pill: String        // footer capsule
        let ink = "#12201f"
        let muted = "#56625f"
        let card = "#f0f2f2"
        let line = "#e3e8e7"
        // Dark
        let darkPage: String
        let darkGlow: String
        let darkSheet: String
        let darkCard: String
        let darkLine: String
        let darkAccentText: String
        let darkPill: String

        init(theme: String) {
            typealias RGB = (Double, Double, Double)
            let (pastel, light, dark): (RGB?, RGB, RGB) = switch theme {
            case "pink":     ((1.00, 0.88, 0.90), (0.76, 0.25, 0.42), (0.78, 0.28, 0.44))
            case "lavender": ((0.91, 0.88, 1.00), (0.48, 0.30, 0.75), (0.54, 0.37, 0.80))
            case "mint":     ((0.85, 0.96, 0.90), (0.10, 0.50, 0.32), (0.12, 0.52, 0.34))
            case "sky":      ((0.85, 0.93, 1.00), (0.18, 0.45, 0.78), (0.19, 0.46, 0.79))
            case "peach":    ((1.00, 0.90, 0.82), (0.65, 0.30, 0.12), (0.71, 0.36, 0.18))
            case "lemon":    ((1.00, 0.97, 0.82), (0.58, 0.42, 0.03), (0.59, 0.43, 0.04))
            default:         (nil, (0.00, 0.50, 0.58), (0.00, 0.50, 0.58))
            }
            func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
                (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
            }
            func hex(_ c: RGB) -> String {
                String(format: "#%02x%02x%02x", Int((c.0 * 255).rounded()), Int((c.1 * 255).rounded()), Int((c.2 * 255).rounded()))
            }
            let white: RGB = (1, 1, 1), black: RGB = (0, 0, 0)
            // The default keeps the exact teal of the logo and of 1.0.1's email.
            accent = pastel == nil ? "#00808f" : hex(light)
            glow = hex(mix(white, light, 0.30))
            pill = hex(mix(white, light, 0.14))
            // Dark mode: the app's tinted near-black, the theme colour glowing
            // from the top, brighter accent text.
            let page = pastel.map { mix($0, black, 0.85) } ?? black
            darkPage = hex(page)
            darkGlow = hex(mix(page, dark, 0.45))
            darkSheet = hex(mix(page, white, 0.07))
            darkCard = hex(mix(page, white, 0.12))
            darkLine = hex(mix(page, white, 0.18))
            darkAccentText = hex(mix(dark, white, 0.35))
            darkPill = hex(mix(page, dark, 0.30))
        }
    }

    private static let font = "-apple-system, BlinkMacSystemFont, 'Hiragino Sans', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
    private static let roundedFont = "ui-rounded, 'SF Pro Rounded', 'Hiragino Maru Gothic ProN', \(font)"

    /// `contactName` nil: several recipients (in BCC), greeted generically.
    /// `theme`: the sender's colour theme (ColorTheme's raw value).
    static func generate(answers: CheckInAnswers, contactName: String?, userName: String,
                         previousUnsent: [CheckInAnswers] = [], theme: String = "default") -> String {
        let p = Palette(theme: theme)
        let greeting = contactName.map { String(format: NSLocalizedString("report.greeting", comment: ""), $0) }
            ?? NSLocalizedString("report.greeting.everyone", comment: "")
        let intro = String(format: NSLocalizedString("report.intro", comment: ""), userName)
        let title = String(format: NSLocalizedString("report.title", comment: ""), userName)
        let footer = NSLocalizedString("report.footer", comment: "")

        var card = """
        <table role="presentation" align="center" cellpadding="0" cellspacing="0" style="margin:0 auto"><tr><td align="center" width="52" height="52" style="width:52px;height:52px;border-radius:26px;background:\(p.accent);color:#ffffff;font:700 28px/52px \(roundedFont);text-align:center">&#10003;</td></tr></table>
        <div class="ink" style="text-align:center;font:700 23px/1.25 \(roundedFont);color:\(p.ink);margin-top:12px">\(escape(title))</div>
        <div class="muted" style="text-align:center;font-size:14px;color:\(p.muted);margin-top:6px">\(escape(longDate(answers.date)))</div>
        <div class="ink" style="font-size:17px;color:\(p.ink);margin-top:22px">\(escape(greeting))</div>
        <div class="ink" style="font-size:16px;color:\(p.ink);margin:6px 0 6px;line-height:1.5">\(escape(intro))</div>
        \(answerCards(for: answers, palette: p))
        """

        // Catch up on check-ins that were finished but never emailed: one
        // card, a line per day, so today's answers stay the focus.
        let backlog = previousUnsent.sorted { $0.date < $1.date }
        if !backlog.isEmpty {
            let rows = backlog.enumerated().map { index, entry in
                let values = Values(entry)
                let rule = index == 0 ? "" : "border-top:1px solid \(p.line);"
                return """
                <tr><td class="ink rule" style="padding:10px 12px 10px 0;font-size:14px;font-weight:600;color:\(p.ink);white-space:nowrap;vertical-align:top;\(rule)">\(escape(shortDate(entry.date)))</td>\
                <td class="ink rule" style="padding:10px 0;font-size:15px;color:\(p.ink);\(rule)">\(escape(values.sleep)) · \(escape(values.feelings)) · <span style="white-space:nowrap">\(escape(values.bloodPressure))</span></td></tr>
                """
            }
            card += """
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="rule" style="border:1px solid \(p.line);border-radius:18px;margin-top:22px"><tr><td style="padding:14px 18px 6px">
            <div class="muted" style="font-size:14px;color:\(p.muted);margin-bottom:2px">\(escape(NSLocalizedString("report.previous", comment: "")))</div>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0">\(rows.joined(separator: "\n"))</table>
            </td></tr></table>
            """
        }

        let footerPill = """
        <table role="presentation" align="center" cellpadding="0" cellspacing="0" class="pill" style="margin:28px auto 0;background:\(p.pill);border-radius:999px"><tr>
        <td style="padding:8px 6px 8px 14px;vertical-align:middle"><a href="\(appStoreURL)"><img src="\(logoURL)" width="24" height="22" alt="" style="display:block;border:0"></a></td>
        <td style="padding:8px 16px 8px 4px;vertical-align:middle;font-size:14px;font-weight:700"><a href="\(appStoreURL)" class="link" style="color:\(p.accent);text-decoration:none">\(escape(footer))</a></td>
        </tr></table>
        """

        return """
        <!doctype html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
        <style>
        @media (prefers-color-scheme: dark) {
          .page { background-color:\(p.darkPage) !important; background-image:linear-gradient(180deg,\(p.darkGlow) 0px,\(p.darkPage) 380px) !important; }
          .sheet { background:\(p.darkSheet) !important; border-color:\(p.darkLine) !important; }
          .card { background:\(p.darkCard) !important; }
          .ink { color:#eef3f2 !important; }
          .muted { color:#a3b1ae !important; }
          .rule { border-color:\(p.darkLine) !important; }
          .pill { background:\(p.darkPill) !important; }
          .link { color:\(p.darkAccentText) !important; }
        }
        </style></head>
        <body style="margin:0;padding:0">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:\(p.accent)"><tr>
        <td align="center" style="padding:16px 20px;font:700 28px/1 \(roundedFont);color:#ffffff;letter-spacing:.01em">hottoshita</td>
        </tr></table>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="page" bgcolor="#ffffff" style="background-color:#ffffff;background-image:linear-gradient(180deg,\(p.glow) 0px,#ffffff 380px)"><tr><td align="center" style="padding:22px 14px 32px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;font-family:\(font);text-align:left"><tr><td>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="sheet" bgcolor="#ffffff" style="background:#ffffff;border:1px solid \(p.line);border-radius:26px"><tr><td style="padding:24px 20px 22px">
        \(card)
        </td></tr></table>
        \(footerPill)
        </td></tr></table>
        </td></tr></table>
        </body></html>
        """
    }

    /// One check-in's answers as the report words them.
    private struct Values {
        let sleep: String
        let feelings: String
        let bloodPressure: String
        let hasReading: Bool

        init(_ answers: CheckInAnswers) {
            sleep = NSLocalizedString(answers.sleep?.rawValue ?? "", comment: "")
            feelings = answers.feelings.isEmpty
                ? NSLocalizedString("Not specified", comment: "")
                : answers.feelings.sorted().map { NSLocalizedString($0, comment: "") }.joined(separator: NSLocalizedString("list.separator", comment: ""))
            hasReading = (answers.tookBloodPressure ?? false) && answers.bloodPressure.isValid
            bloodPressure = hasReading ? answers.bloodPressure.formatted : NSLocalizedString("Not taken", comment: "")
        }
    }

    /// One rounded row per answer, like the app's summary: the label on the
    /// left, the answer on the right.
    private static func answerCards(for answers: CheckInAnswers, palette p: Palette) -> String {
        let values = Values(answers)
        let rows = [
            (NSLocalizedString("report.sleep", comment: ""), values.sleep, false),
            (NSLocalizedString("report.feeling", comment: ""), values.feelings, false),
            (NSLocalizedString("report.bp", comment: ""), values.bloodPressure, values.hasReading),
        ]
        // The reading never breaks across lines ("128/82 / mmHg").
        return rows.map { label, value, isReading in
            """
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="card" style="background:\(p.card);border-radius:18px;margin-top:10px"><tr>\
            <td class="muted" style="padding:16px 18px;font-size:16px;color:\(p.muted);vertical-align:middle">\(escape(label))</td>\
            <td class="ink" align="right" style="padding:16px 18px;font-size:\(isReading ? 21 : 17)px;font-weight:600;color:\(p.ink);vertical-align:middle\(isReading ? ";white-space:nowrap" : "")">\(escape(value))</td></tr></table>
            """
        }.joined(separator: "\n")
    }

    private static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
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
