import XCTest

/// How long a screen iOS draws in its own process may take to show: the keyboard, the share sheet's contents, Apple's
/// rating prompt. Each starts cold on a CI simulator, and the times vary from run to run: the first keyboard took 1.5 s
/// once and more than 15 s another time (run 43997920889), the share sheet's caption about 7 s and more than 10 s (run
/// 44083594093), the rating prompt 9.7 s (run 43554564482). On a Mac each takes about 1 s. iPhone Settings, opened
/// from the app, is the same: in the foreground within 0.5 s in six CI runs and still blank after 10 s in a seventh
/// (run 44748993039), where how long it needed is not known.
let systemUITimeout: TimeInterval = 30
