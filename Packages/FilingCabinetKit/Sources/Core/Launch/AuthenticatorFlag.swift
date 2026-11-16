/// `-Authenticator succeeds|succeedsOnce|cancels|cancelsOnce|fails|passcodeOnly|none`: how the fake authenticator
/// answers. `succeedsOnce`: the first check succeeds and every later one is cancelled, so a test can see the library lock
/// again. `cancelsOnce`: the first check is cancelled and every later one succeeds, so a test can see Unlock unlock.
public enum AuthenticatorFlag: String, Sendable, Equatable {
    case succeeds, succeedsOnce, cancels, cancelsOnce, fails, passcodeOnly, none
}
