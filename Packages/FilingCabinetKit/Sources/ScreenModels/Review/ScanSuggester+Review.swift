import Understanding

extension ScanSuggester {
    /// Whether review asks this suggester: the switch is on (`isOn`) and the model can answer now. Off or
    /// unavailable, review behaves as on an iPhone without Apple Intelligence.
    package func answers(whenOn isOn: Bool) -> Bool {
        isOn && availability == .available
    }
}
