/// How review shows itself: the slim suggestion card or the full sheet.
package enum ReviewPresentation: Equatable {
    /// The card, while the model is reading (`isReading`) or once its suggestion filled the fields.
    case card(isReading: Bool)
    /// The full sheet: no suggestions, the model failed or was too slow, or the card was opened.
    case sheet
}
