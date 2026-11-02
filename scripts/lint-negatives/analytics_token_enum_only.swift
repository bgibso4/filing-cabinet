// A struct or extension must not conform to AnalyticsToken; this comment mentions it safely.
/// struct Doc: AnalyticsToken is only text here.
enum Kind: String, AnalyticsToken { case a }

enum Other:
    String,
    AnalyticsToken
{
    case b
}

let note = "struct S: AnalyticsToken {}"
