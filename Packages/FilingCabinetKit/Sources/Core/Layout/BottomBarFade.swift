import CoreGraphics

/// The fade into the page background at the bottom of Home, the grids and Trash, under their bottom bar (#83). Shared
/// with the UI tests' audit, which ignores contrast on text the fade covers.
public enum BottomBarFade {
    // Home.dc.html line 191 (also Collection.dc.html line 125, Trash.dc.html line 118): 128 pt from the screen's
    // bottom edge, solid page background for its lower 38%, then clear.
    public static let height: CGFloat = 128
    package static let solidFraction: CGFloat = 0.38
}
