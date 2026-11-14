/// One answer of Ben's from the review page (`judgements.json` is a `[Judgement]`).
struct Judgement: Codable, Equatable {
    let id: String
    /// The title style the judged title came from (the page shows it blind, as "A" or "B").
    let variant: String
    /// The title judged; empty when the case has no title to judge and only a collection or a better title was given.
    let title: String
    let verdict: Verdict
    /// What Ben would call it, when he typed something.
    let better: String?
    /// The collection id Ben picked (private cases).
    let collection: String?
}

enum Verdict: String, Codable {
    case right = "yes"
    case wrong = "no"
}
