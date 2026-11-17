import XCTest

/// How long the keyboard may take to show. The first keyboard after a simulator boots starts cold: on CI it took 1.5 s
/// in one run and more than 15 s in another, while the field already had focus (run 43997920889). Later ones are quick.
let keyboardTimeout: TimeInterval = 20
