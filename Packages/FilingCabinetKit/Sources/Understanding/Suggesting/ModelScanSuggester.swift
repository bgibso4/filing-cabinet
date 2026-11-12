import CoreGraphics
import FoundationModels
import Synchronization

/// The on-device model (`SystemLanguageModel.default`; never Private Cloud Compute). Two calls per scan, each in its
/// own session: the filing call (a schema whose collection may only be one of the ids it was handed) while the scan is
/// reviewed, and the focused words call after it is saved. Measured by Tasks 4 to 4d, not unit-tested.
///
/// Prewarming (E3) makes the session the next `suggestFiling` uses, and only that one: a session keeps its
/// transcript, so a session answers one scan and is never reused, prewarmed or not.
public final class ModelScanSuggester: ScanSuggester {
    /// Page 1's long side when the image is sent (M2).
    private static let imageLongSide = 1_024
    /// Context left for the instructions, the collections, the image and the answer; the rest is page text.
    private static let reservedTokens = 1_500
    /// A low guess of characters per token, so trimmed text fits; a misjudged scan ends in `contextSizeExceeded`.
    private static let charactersPerToken = 3

    private let includesImage: Bool
    /// The session `prewarm` made, waiting for the next `suggestFiling` to take it.
    private let prewarmed = Mutex<LanguageModelSession?>(nil)

    /// `includesImage` sends page 1 alongside the text to the filing call when the model can see images (E2).
    public init(includesImage: Bool = true) {
        self.includesImage = includesImage
    }

    public var availability: SuggesterAvailability {
        if case .available = SystemLanguageModel.default.availability { .available } else { .unavailable }
    }

    /// Makes the next scan's session, if none is waiting, and asks the system to load the model and read the
    /// instructions and the collection list ahead. Returns at once; calling it again only repeats the hint.
    public func prewarm(collections: [SuggestionCollection]) {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return }
        let session = prewarmed.withLock { waiting in
            let session = waiting ?? Self.session(model: model)
            waiting = session
            return session
        }
        session.prewarm(promptPrefix: Prompt(SuggestionPrompt.prefix(for: collections)))
    }

    @concurrent
    public func suggestFiling(_ input: SuggestionInput) async -> ScanSuggestion? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, !input.collections.isEmpty else {
            UnderstandingLog.logger.info("Suggester: model unavailable or no collections")
            return nil
        }
        let start = ContinuousClock.now
        let image =
            includesImage && model.capabilities.contains(.vision)
            ? input.firstPage.flatMap { SuggestionImage.fitted($0, longSide: Self.imageLongSide) } : nil
        do {
            let session = prewarmed.withLock { $0.take() }
            let wasPrewarmed = session != nil
            let suggestion = try await respond(
                to: input, image: image, session: session ?? Self.session(model: model), model: model)
            UnderstandingLog.logger.info(
                """
                Suggester: filed in \(ContinuousClock.now - start, privacy: .public), \
                image \(image != nil, privacy: .public), prewarmed \(wasPrewarmed, privacy: .public)
                """)
            return suggestion
        } catch {
            Self.log(error)
            return nil
        }
    }

    @concurrent
    public func suggestWords(_ input: SuggestionInput, title: String, collectionName: String) async -> [String]? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            UnderstandingLog.logger.info("Suggester: model unavailable for words")
            return nil
        }
        let start = ContinuousClock.now
        let prompt = SuggestionPrompt.wordsPrompt(for: input, title: title, collectionName: collectionName)
        let session = LanguageModelSession(model: model, instructions: SuggestionPrompt.wordsInstructions)
        do {
            let response = try await session.respond(
                to: prompt, schema: try Self.wordsSchema(), options: GenerationOptions(samplingMode: .greedy))
            try Task.checkCancellation()
            let words = SuggestionCleanup.cleanWords(try response.content.value([String].self, forProperty: "words"))
            UnderstandingLog.logger.info(
                """
                Suggester: \(words.count, privacy: .public) words in \(ContinuousClock.now - start, privacy: .public)
                """)
            return words
        } catch {
            Self.log(error)
            return nil
        }
    }

    /// A fresh session with the suggester's instructions.
    private static func session(model: SystemLanguageModel) -> LanguageModelSession {
        LanguageModelSession(model: model, instructions: SuggestionPrompt.instructions)
    }

    /// The filing call's answer from `session`, passed through `SuggestionCleanup`.
    private func respond(
        to input: SuggestionInput, image: CGImage?, session: LanguageModelSession, model: SystemLanguageModel
    ) async throws -> ScanSuggestion {
        let budget = max(model.contextSize - Self.reservedTokens, 0) * Self.charactersPerToken
        let prompt = SuggestionPrompt.prompt(for: input, budget: budget)
        let schema = try Self.schema(collectionIDs: SuggestionPrompt.collectionIDs(in: input.collections))
        // Greedy: the same scan gets the same answer, which suits classification.
        let options = GenerationOptions(samplingMode: .greedy)
        let response: LanguageModelSession.Response<GeneratedContent>
        if let image {
            response = try await session.respond(schema: schema, options: options) {
                prompt
                Attachment(image)
            }
        } else {
            response = try await session.respond(to: prompt, schema: schema, options: options)
        }
        try Task.checkCancellation()
        let content = response.content
        return SuggestionCleanup.clean(
            title: try content.value(String.self, forProperty: "title"),
            collectionID: try content.value(String.self, forProperty: "collection"),
            allowed: input.collections
        )
    }

    /// Every failure means "no suggestion"; the log names the kind, never the scan's content.
    private static func log(_ error: any Error) {
        switch error {
        case is CancellationError:
            UnderstandingLog.logger.info("Suggester: cancelled")
        case let error as LanguageModelError:
            // The case name alone ("guardrailViolation") is public; its details stay private.
            UnderstandingLog.logger.error(
                """
                Suggester: model error \(kind(of: error), privacy: .public), \
                \(String(describing: error), privacy: .private)
                """)
        case let error as SystemLanguageModel.Error:
            UnderstandingLog.logger.error("Suggester: model assets \(String(describing: error), privacy: .private)")
        case let error as LanguageModelSession.Error:
            UnderstandingLog.logger.error("Suggester: session \(String(describing: error), privacy: .public)")
        case let error as GeneratedContent.ParsingError:
            UnderstandingLog.logger.error(
                "Suggester: answer not parsed \(String(describing: error.underlyingError), privacy: .private)")
        default:
            // Schema or session errors.
            UnderstandingLog.logger.error("Suggester: failed, \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// The case's name, written out so the log can show it publicly.
    private static func kind(of error: LanguageModelError) -> String {
        switch error {
        case .contextSizeExceeded: "contextSizeExceeded"
        case .rateLimited: "rateLimited"
        case .guardrailViolation: "guardrailViolation"
        case .refusal: "refusal"
        case .unsupportedCapability: "unsupportedCapability"
        case .unsupportedTranscriptContent: "unsupportedTranscriptContent"
        case .unsupportedGenerationGuide: "unsupportedGenerationGuide"
        case .unsupportedLanguageOrLocale: "unsupportedLanguageOrLocale"
        case .timeout: "timeout"
        @unknown default: "unknown"
        }
    }

    /// `title` and `collection` (any of `collectionIDs`).
    private static func schema(collectionIDs: [String]) throws -> GenerationSchema {
        let collection = DynamicGenerationSchema(
            name: "CollectionID",
            description: "The id of the one collection the scan belongs in",
            anyOf: collectionIDs
        )
        let title = DynamicGenerationSchema.Property(
            name: "title",
            description: "What the document is and who it is from, never its owner's name, at most 40 characters",
            schema: DynamicGenerationSchema(type: String.self)
        )
        let root = DynamicGenerationSchema(
            name: "ScanSuggestion",
            properties: [title, DynamicGenerationSchema.Property(name: "collection", schema: collection)]
        )
        return try GenerationSchema(root: root, dependencies: [])
    }

    /// The focused call's answer: `words` alone.
    private static func wordsSchema() throws -> GenerationSchema {
        let root = DynamicGenerationSchema(
            name: "SearchWords",
            properties: [
                DynamicGenerationSchema.Property(
                    name: "words",
                    description:
                        "4 to 8 lowercase everyday search words: the kind of thing, the kind of shop or organization, "
                        + "the everyday category",
                    schema: DynamicGenerationSchema(
                        arrayOf: DynamicGenerationSchema(type: String.self),
                        minimumElements: 4,
                        maximumElements: 8
                    )
                )
            ])
        return try GenerationSchema(root: root, dependencies: [])
    }
}
