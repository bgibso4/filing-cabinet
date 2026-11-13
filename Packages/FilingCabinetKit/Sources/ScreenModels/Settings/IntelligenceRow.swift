/// Settings' Apple Intelligence row (10-01, 10-06) and the line under its group.
package struct IntelligenceRow: Equatable {
    /// Whether the model can answer on this iPhone now; when it can't, the switch is off and dimmed.
    package let isAvailable: Bool
    package let isOn: Bool
    package let subtitle: String
    /// The line under the group: how far older scans' reading has got, or the privacy line. Nil without Apple
    /// Intelligence, whose subtitle says what to do instead (10-06).
    package let footer: String?
    /// How far the reading of older scans has got, 0 to 1; nil while it isn't reading.
    package let progress: Double?
}
