import Core
import ScreenModels
import SwiftUI

/// "Choose a date…": a calendar from today on. Done keeps the scan through the chosen day.
struct ExpiryDateSheet: View {
    let model: ReviewModel

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(model: ReviewModel) {
        self.model = model
        _date = State(initialValue: model.earliestCustomDate)
    }

    var body: some View {
        NavigationStack {
            DatePicker(selection: $date, in: model.earliestCustomDate..., displayedComponents: .date) {
                Text("Expiry", bundle: #bundle)
            }
            .datePickerStyle(.graphical)
            .accessibilityIdentifier(AccessibilityID.ExpiryDate.picker)
            .padding(.horizontal, Tokens.Spacing.s4)
            .frame(maxHeight: .infinity, alignment: .top)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: #bundle)
                    }
                    .accessibilityIdentifier(AccessibilityID.ExpiryDate.cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        model.chooseExpiryDate(date)
                        dismiss()
                    } label: {
                        Text("Done", bundle: #bundle)
                    }
                    .accessibilityIdentifier(AccessibilityID.ExpiryDate.done)
                }
            }
        }
        .environment(\.calendar, model.calendar)
        .environment(\.timeZone, model.calendar.timeZone)
        .environment(\.locale, model.locale)
        .presentationDetents([.large])
    }
}
