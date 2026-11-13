/// The library folder couldn't be found or made, or the store couldn't open (#40). The app shows the failure screen,
/// never an empty library.
struct LibraryOpenFailure: Error {
    let underlying: any Error
}
