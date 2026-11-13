/// Where feedback goes.
package enum FeedbackAddress {
    /// A reserved, undeliverable address. The release script refuses to upload while `value` is still this.
    package static let placeholder = "feedback@example.invalid"

    package static let value = "filingcabinet.app@gmail.com"
}
