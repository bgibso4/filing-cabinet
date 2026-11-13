import Core
import ScreenModels
import SwiftUI

/// Review's slim card (Review.dc.html lines 234-252, 03-02): the title with the pencil, the collection's dot and
/// "Receipts · kept 3 months", and Save. While the model reads (the loading mock, option B:
/// claude.ai/artifact/SZ5Ntg5vThvnYN3KAgv14Q) a shimmering bar and "Reading your scan…" stand in for them and Save is
/// off; when the suggestion lands they cross-fade in. A scan begun inside a collection shows that collection's line
/// under the bar and Save is on straight away (design §5): only the title waits. Tapping the card, or dragging it up,
/// opens the sheet.
struct ReviewCard: View {
    let model: ReviewModel
    let isReading: Bool
    let onSave: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.reducesMotion) private var reducesMotion
    /// How far the dot's bottom sits above the line's baseline, so it centres on the capitals of the first line however
    /// the line wraps (03-02: an 8 pt dot by 15 pt text).
    @ScaledMetric(relativeTo: .subheadline) private var dotLift = Self.dotLiftAtDefaultSize

    // Review.dc.html line 236: 12 pt in from the screen's sides and 30 pt up from its bottom, 30 pt corners; 8 pt above
    // the content, 12 pt right of and below it, 18 pt left of it, and 4 pt between the grabber and the row.
    private static let sideInset: CGFloat = 12
    private static let bottomInset: CGFloat = 30
    private static let cornerRadius: CGFloat = 30
    private static let topPadding: CGFloat = 8
    private static let leadingPadding: CGFloat = 18
    private static let trailingPadding: CGFloat = 12
    private static let bottomPadding: CGFloat = 12
    private static let grabberGap: CGFloat = 4
    // Review.dc.html line 237: the grabber is 36 by 5 pt, 6 pt right of centre (the content's centre).
    private static let grabberWidth: CGFloat = 36
    private static let grabberHeight: CGFloat = 5
    private static let grabberShift: CGFloat = 6
    // Review.dc.html lines 246-247: 6 pt between the title and its pencil, and between the dot and the line; the dot
    // is 8 pt.
    private static let inlineGap: CGFloat = 6
    private static let dotDiameter: CGFloat = 8
    // Half of SF Pro's 15 pt cap height (10.6 pt) less half the dot.
    private static let dotLiftAtDefaultSize: CGFloat = 1.3
    // Review.dc.html line 249: Save is 52 pt tall at least, with 26 pt either side of its label.
    private static let saveMinHeight: CGFloat = 52
    private static let saveSidePadding: CGFloat = 26
    // SZ5N `.bar`: the shimmering bar is 150 by 14 pt, with 4 pt above and below it.
    private static let barWidth: CGFloat = 150
    private static let barHeight: CGFloat = 14
    private static let barMargin: CGFloat = 4
    // ULgeF `.ring` (claude.ai/artifact/ULgeFhB5rS6qNzMwLebT5N): before a collection, a 9 pt ring in 1.5 pt dashes.
    private static let ringDiameter: CGFloat = 9
    private static let ringStyle = StrokeStyle(lineWidth: 1.5, dash: [2, 2])
    // No mock: how far up a drag on the card has to go (or be flung) to open the sheet.
    private static let openDistance: CGFloat = 24
    // SZ5N `.layer`: the rows cross-fade in 0.28 s; under Reduce Motion, a 0.15 s fade.
    private static let crossFade = Animation.easeInOut(duration: 0.28)
    private static let reducedFade = Animation.linear(duration: 0.15)

    var body: some View {
        VStack(spacing: Self.grabberGap) {
            grabber
            if typeSize.isAccessibilitySize {
                // 12-03: the title and line take the full width, Save goes under them.
                VStack(alignment: .leading, spacing: Tokens.Spacing.s3) {
                    info
                    saveButton
                }
            } else {
                HStack(spacing: Tokens.Spacing.s3) {
                    info
                    saveButton
                }
            }
        }
        .padding(.top, Self.topPadding)
        .padding(.leading, Self.leadingPadding)
        .padding(.trailing, Self.trailingPadding)
        .padding(.bottom, Self.bottomPadding)
        .background(background, in: .rect(cornerRadius: Self.cornerRadius))
        .contentShape(.rect(cornerRadius: Self.cornerRadius))
        // Anywhere on the card opens the sheet, Save too while it is off (no collection yet): intended.
        .onTapGesture(perform: model.openSheet)
        .simultaneousGesture(openDrag)
        .animation(reducesMotion ? Self.reducedFade : Self.crossFade, value: isReading)
        .accessibilityElement(children: .contain)
        .padding(.horizontal, Self.sideInset)
        .padding(.bottom, Self.bottomInset)
    }

    // MARK: Colours

    /// The mock's near-opaque card: white in light, #2c2c2e in dark (Review.dc.html lines 358-359, `glassStrong`).
    private var background: Color { colorScheme == .dark ? Tokens.Color.bgWell : Tokens.Color.bgSurface }

    /// The bar's and the dot's grey while reading (SZ5N `--shim`: #e5e5ea, #3a3a3c).
    private var placeholder: Color { Tokens.Color.separator }

    /// The band that passes across the bar, lighter than it in both appearances (SZ5N `--shimHi`: #f7f7fa, #4a4a4e).
    private var shimmerHighlight: Color { colorScheme == .dark ? Tokens.Color.chevron : Tokens.Color.bgSurface }

    // MARK: Parts

    /// Decoration from the mock: the drag works anywhere on the card.
    private var grabber: some View {
        Capsule()
            .fill(Tokens.Color.chevron)
            .frame(width: Self.grabberWidth, height: Self.grabberHeight)
            .padding(.leading, Self.grabberShift)
            .accessibilityHidden(true)
    }

    /// The title and collection, or the reading placeholder, one over the other so they cross-fade. Only the one
    /// showing is read by VoiceOver.
    private var info: some View {
        Button(action: model.openSheet) {
            ZStack(alignment: .leading) {
                reading
                    .opacity(isReading ? 1 : 0)
                    .accessibilityHidden(!isReading)
                suggestion
                    .opacity(isReading ? 0 : 1)
                    .accessibilityHidden(isReading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(UnfadedButtonStyle())
        .accessibilityHint(Text("Change the title, collection or expiry", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.Review.card)
    }

    /// The bar for the title, then the scan's collection line when it began inside one, else "Reading your scan…".
    private var reading: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Still once the suggestion lands: the layer stays, faded out, for the cross-fade.
            Shimmer(base: placeholder, highlight: shimmerHighlight, isActive: isReading)
                .frame(width: Self.barWidth, height: Self.barHeight)
                .clipShape(.capsule)
                .padding(.vertical, Self.barMargin)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: Self.inlineGap) {
                if let collection = model.collection {
                    CollectionDot(collection: collection, diameter: Self.dotDiameter)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] + dotLift }
                    Text(model.cardLine)
                } else {
                    Circle()
                        .fill(placeholder)
                        .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] + dotLift }
                        .accessibilityHidden(true)
                    Text("Reading your scan…", bundle: #bundle)
                }
            }
            .font(Tokens.Typography.subheadline)
            .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    /// SF Pro semibold, as the mock draws it: on the card the title is a label; the sheet shows it in New York. A long
    /// title or line wraps rather than truncating as the mock's does, so no text is cut off at larger sizes.
    private var suggestion: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Self.inlineGap) {
                Text(model.title.isEmpty ? model.fallbackTitle : model.title)
                    .font(Tokens.Typography.headline)
                    .foregroundStyle(Tokens.Color.textPrimary)
                Image(systemName: "pencil")
                    // Footnote is closest to the mock's 14 pt glyph.
                    .font(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .firstTextBaseline, spacing: Self.inlineGap) {
                collectionMark
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] + dotLift }
                Text(model.cardLine)
            }
            .font(Tokens.Typography.subheadline)
            .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    /// The collection's dot, or a dashed ring before there is one (a suggestion that named no collection).
    @ViewBuilder private var collectionMark: some View {
        if let collection = model.collection {
            CollectionDot(collection: collection, diameter: Self.dotDiameter)
        } else {
            Circle()
                .stroke(Tokens.Color.textSecondary, style: Self.ringStyle)
                .frame(width: Self.ringDiameter, height: Self.ringDiameter)
                .accessibilityHidden(true)
        }
    }

    /// Off until there is a collection: while reading, that is only when the scan began inside one. "Save", not the
    /// sheet's "Save to Receipts": the line beside it names the collection.
    private var saveButton: some View {
        let isOn = model.canSave
        return Button(action: onSave) {
            Text("Save", bundle: #bundle)
                .font(Tokens.Typography.headline)
                .foregroundStyle(isOn ? Tokens.Color.bgGrouped : Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Self.saveSidePadding)
                .padding(.vertical, Tokens.Spacing.s2)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: Self.saveMinHeight)
                .background(isOn ? Tokens.Color.tint : Tokens.Color.bgWell, in: .capsule)
        }
        // Not .plain, which fades a disabled label below the mock's colours (and below AA contrast).
        .buttonStyle(UnfadedButtonStyle())
        .disabled(!isOn)
        .accessibilityIdentifier(AccessibilityID.Review.save)
    }

    // MARK: Drag

    /// Up far enough, or flung up, opens the sheet.
    private var openDrag: some Gesture {
        DragGesture(minimumDistance: Tokens.Spacing.s2)
            .onEnded { drag in
                if min(drag.translation.height, drag.predictedEndTranslation.height) < -Self.openDistance {
                    model.openSheet()
                }
            }
    }
}
