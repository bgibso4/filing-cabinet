/// `-Authenticator succeeds|succeedsOnce|cancels|fails|passcodeOnly|none`: how the fake authenticator answers.
/// `succeedsOnce`: the first check succeeds and every later one is cancelled, so a test can see the library lock again.
public enum AuthenticatorFlag: String, Sendable, Equatable {
    case succeeds, succeedsOnce, cancels, fails, passcodeOnly, none
}
