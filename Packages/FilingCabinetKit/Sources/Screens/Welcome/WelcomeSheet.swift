import ScreenModels
import SwiftUI

/// The first-launch welcome, a sheet over Home that can't be swiped away (Plan 6 §4): Welcome (01-03), then "Know when
/// it cleans up" (01-04). The model decides when it closes.
public struct WelcomeSheet: View {
    private let model: WelcomeModel

    @Environment(\.reducesMotion) private var reducesMotion
    /// The screen on show. It keeps the last one while the sheet slides away, after the model's step is nil.
    @State private var shown: WelcomeModel.Step

    // design/prototype/index.html line 243 (.pagesheet .step.enter, keyframes rise): the next screen rises 12 pt as it
    // fades in, over 0.3 s, easing out.
    private static let riseDistance: CGFloat = 12
    private static let stepDuration: TimeInterval = 0.3

    public init(model: WelcomeModel) {
        self.model = model
        _shown = State(initialValue: model.step ?? .welcome)
    }

    public var body: some View {
        ZStack {
            switch shown {
            case .welcome:
                WelcomeScreen(onContinue: { Task { await model.continueTapped() } })
                    .transition(stepTransition)
            case .notifications:
                NotificationsAskScreen(
                    onTurnOn: { Task { await model.turnOnTapped() } },
                    onNotNow: model.notNowTapped
                )
                .transition(stepTransition)
            }
        }
        .onChange(of: model.step) { _, step in
            guard let step, step != shown else { return }
            withAnimation(.easeOut(duration: Self.stepDuration)) { shown = step }
            // VoiceOver starts again at the top of the new screen.
            AccessibilityNotification.ScreenChanged().post()
        }
        .presentationDetents([.large])
        .presentationBackground(Tokens.Color.bgSurface)
        .interactiveDismissDisabled()
    }

    /// The next screen rises as it fades in; with Reduce Motion it only fades.
    private var stepTransition: AnyTransition {
        reducesMotion ? .opacity : .opacity.combined(with: .offset(y: Self.riseDistance))
    }
}
