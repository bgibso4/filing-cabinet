import Foundation

/// The copy of Save to Photos, Save to Files and Copy Text (M12). Success shows no note: VoiceOver hears it and the
/// phone taps. A failure is the edit alert's wording, adapted.
package enum ExportText {
    package static var savedToPhotos: String { String(localized: "Saved to Photos", bundle: #bundle) }
    package static var savedToFiles: String { String(localized: "Saved to Files", bundle: #bundle) }
    package static var copied: String { String(localized: "Copied", bundle: #bundle) }

    static var photosFailed: String { String(localized: "Couldn’t save to Photos", bundle: #bundle) }
    static var filesFailed: String { String(localized: "Couldn’t save to Files", bundle: #bundle) }
}
