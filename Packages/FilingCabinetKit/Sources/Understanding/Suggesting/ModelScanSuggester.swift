import CoreGraphics
import FoundationModels

// periphery:ignore - the app wires it in Plan 5 Task 8; remove this line then
/// The on-device model (`SystemLanguageModel.default`; never Private Cloud Compute). One session per scan, with a
/// schema whose collection may only be one of the ids it was handed. Measured by Task 4, not unit-tested.
public struct ModelScanSuggester: ScanSuggester {
    /// Page 1's long side when the image is sent (M2).
    private static let imageLongSide = 1_024
    /// Context left for the instructions, the collections, the image and the answer; the rest is page text.
    private static let reservedTokens = 1_500
    /// A low guess of characters per token, so trimmed text fits; a misjudged scan ends in `contextSizeExceeded`.
    private static let charactersPerToken = 3

    private let includesImage: Bool

    /// `includesImage` sends page 1 alongside the text when the model can see images (E2).
    public init(includesImage: Bool) {
        self.includesImage = includesImage
    }

    public var availability: SuggesterAvailability {
        if case .available = SystemLanguageModel.default.availability { .available } else { .unavailable }
    }

    @concurrent
    public func suggest(_ input: SuggestionInput) async -> ScanSuggestion? {
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
            let suggestion = try await respond(to: input, image: image, model: model)
            UnderstandingLog.logger.info(
                """
                Suggester: answered in \(ContinuousClock.now - start, privacy: .public), \
                image \(image != nil, privacy: .public), \(suggestion.searchWords.count, privacy: .public) words
                """)
            return suggestion
        } catch {
            Self.log(error)
            return nil
        }
    }

    /// One new session per scan; the answer passed through `SuggestionCleanup`.
    private func respond(to input: SuggestionInput, image: CGImage?, model: SystemLanguageModel) async throws
        -> ScanSuggestion
    {
        let budget = max(model.contextSize - Self.reservedTokens, 0) * Self.charactersPerToken
        let prompt = SuggestionPrompt.prompt(for: input, budget: budget)
        let schema = try Self.schema(collectionIDs: SuggestionPrompt.collectionIDs(in: input.collections))
        let session = LanguageModelSession(model: model, instructions: SuggestionPrompt.instructions)
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
            words: try content.value([String].self, forProperty: "words"),
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
            let kind = Mirror(reflecting: error).children.first?.label ?? "unnamed"
            UnderstandingLog.logger.error(
                "Suggester: model error \(kind, privacy: .public), \(String(describing: error), privacy: .private)")
        case let error as SystemLanguageModel.Error:
            UnderstandingLog.logger.error("Suggester: model assets \(String(describing: error), privacy: .private)")
        case let error as GeneratedContent.ParsingError:
            UnderstandingLog.logger.error(
                "Suggester: answer not parsed \(String(describing: error.underlyingError), privacy: .private)")
        default:
            // Schema or session errors.
            UnderstandingLog.logger.error("Suggester: failed, \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// `title`, `collection` (any of `collectionIDs`), `words`.
    private static func schema(collectionIDs: [String]) throws -> GenerationSchema {
        let collection = DynamicGenerationSchema(
            name: "CollectionID",
            description: "The id of the one collection the scan belongs in",
            anyOf: collectionIDs
        )
        let root = DynamicGenerationSchema(
            name: "ScanSuggestion",
            properties: [
                DynamicGenerationSchema.Property(
                    name: "title",
                    description:
                        "What the document is and who it is from, never its owner's name, at most 40 characters",
                    schema: DynamicGenerationSchema(type: String.self)
                ),
                DynamicGenerationSchema.Property(name: "collection", schema: collection),
                DynamicGenerationSchema.Property(
                    name: "words",
                    description: "6 to 8 lowercase everyday search words for what kind of document this is",
                    schema: DynamicGenerationSchema(
                        arrayOf: DynamicGenerationSchema(type: String.self),
                        minimumElements: 6,
                        maximumElements: 8
                    )
                ),
            ])
        return try GenerationSchema(root: root, dependencies: [])
    }
}
