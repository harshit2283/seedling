import Flutter
import NaturalLanguage

/// Plugin that provides ML-based text analysis using Apple's Natural Language framework
///
/// This uses CoreML under the hood for on-device NLP processing.
/// - NLTagger for part-of-speech tagging and entity recognition
/// - NLEmbedding for semantic similarity (if available on device)
/// - Sentiment analysis using NLTagger's sentiment scheme
class MLTextAnalyzerPlugin: NSObject, FlutterPlugin {

    private let tagger: NLTagger
    private var embedding: NLEmbedding?

    override init() {
        self.tagger = NLTagger(tagSchemes: [.sentimentScore, .lexicalClass, .nameType, .lemma])

        // NLEmbedding requires iOS 13+ and the word embedding model
        if #available(iOS 13.0, *) {
            self.embedding = NLEmbedding.wordEmbedding(for: .english)
        }

        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.seedling.app/ml_text_analyzer",
            binaryMessenger: registrar.messenger()
        )
        let instance = MLTextAnalyzerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(true)

        case "detectTheme":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing text argument", details: nil))
                return
            }
            result(detectTheme(text))

        case "analyzeSentiment":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing text argument", details: nil))
                return
            }
            result(analyzeSentiment(text))

        case "calculateSimilarity":
            guard let args = call.arguments as? [String: Any],
                  let textA = args["textA"] as? String,
                  let textB = args["textB"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing text arguments", details: nil))
                return
            }
            result(calculateSimilarity(textA, textB))

        case "extractKeywords":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing text argument", details: nil))
                return
            }
            result(extractKeywords(text))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Theme Detection

    private func detectTheme(_ text: String) -> String {
        // Use NLTagger to extract named entities and nouns
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        var entityCounts: [String: Int] = [:]
        var nounCounts: [String: Int] = [:]

        // Extract named entities
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let word = String(text[range]).lowercased()
                entityCounts[tag.rawValue, default: 0] += 1

                // Track specific entity words for theme detection
                if tag == .personalName {
                    nounCounts["person", default: 0] += 1
                } else if tag == .placeName {
                    nounCounts["place", default: 0] += 1
                } else if tag == .organizationName {
                    nounCounts["organization", default: 0] += 1
                }
            }
            return true
        }

        // Extract nouns for additional context
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                nounCounts[word, default: 0] += 1
            }
            return true
        }

        // Score themes based on extracted features
        let themeScores = scoreThemes(text: text.lowercased(), nouns: nounCounts, entities: entityCounts)

        // Return highest scoring theme
        let sortedThemes = themeScores.sorted { $0.value > $1.value }
        return sortedThemes.first?.key ?? "moments"
    }

    private func scoreThemes(text: String, nouns: [String: Int], entities: [String: Int]) -> [String: Double] {
        var scores: [String: Double] = [:]

        // Theme keywords with weights
        let themeKeywords: [String: [String: Double]] = [
            "family": ["mom": 2.0, "dad": 2.0, "mother": 2.0, "father": 2.0, "family": 2.0,
                      "sister": 1.5, "brother": 1.5, "parent": 1.5, "child": 1.5, "kids": 1.5,
                      "grandma": 1.5, "grandpa": 1.5, "home": 1.0, "love": 0.5],
            "friends": ["friend": 2.0, "friends": 2.0, "buddy": 1.5, "hangout": 1.5,
                       "party": 1.0, "fun": 0.5, "laughed": 0.5, "together": 0.5],
            "work": ["work": 2.0, "job": 2.0, "meeting": 1.5, "office": 1.5, "project": 1.5,
                    "career": 1.5, "boss": 1.0, "colleague": 1.0, "deadline": 1.0],
            "nature": ["nature": 2.0, "outside": 1.5, "outdoors": 1.5, "sun": 1.0, "rain": 1.0,
                      "tree": 1.0, "flower": 1.0, "walk": 0.5, "hike": 1.0, "garden": 1.0],
            "gratitude": ["grateful": 2.0, "thankful": 2.0, "appreciate": 1.5, "blessed": 1.5,
                         "lucky": 1.0, "wonderful": 0.5, "amazing": 0.5],
            "reflection": ["think": 1.0, "feel": 1.0, "realize": 1.5, "learn": 1.0,
                          "wonder": 1.0, "remember": 1.0, "thought": 1.0, "life": 0.5],
            "travel": ["travel": 2.0, "trip": 2.0, "vacation": 2.0, "flight": 1.5,
                      "visit": 1.0, "explore": 1.0, "adventure": 1.0, "journey": 1.0],
            "creativity": ["create": 2.0, "art": 2.0, "write": 1.5, "music": 2.0,
                          "paint": 1.5, "design": 1.5, "make": 0.5, "build": 0.5],
            "health": ["health": 2.0, "exercise": 2.0, "workout": 2.0, "run": 1.0,
                      "yoga": 1.5, "gym": 1.5, "sleep": 1.0, "meditation": 1.5],
            "food": ["food": 2.0, "eat": 1.5, "cook": 2.0, "meal": 1.5, "dinner": 1.5,
                    "lunch": 1.5, "breakfast": 1.5, "delicious": 1.0, "recipe": 1.5]
        ]

        for (theme, keywords) in themeKeywords {
            var score = 0.0
            for (keyword, weight) in keywords {
                if text.contains(keyword) {
                    score += weight
                }
            }
            scores[theme] = score
        }

        // Boost based on entities
        if (entities["PersonalName", default: 0] + nouns["person", default: 0]) > 0 {
            scores["family", default: 0] += 1.0
            scores["friends", default: 0] += 0.5
        }
        if (entities["PlaceName", default: 0] + nouns["place", default: 0]) > 0 {
            scores["travel", default: 0] += 1.5
            scores["nature", default: 0] += 0.5
        }

        return scores
    }

    // MARK: - Sentiment Analysis

    private func analyzeSentiment(_ text: String) -> Double {
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        var totalScore = 0.0
        var count = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, range in
            if let tag = tag, let score = Double(tag.rawValue) {
                totalScore += score
                count += 1
            }
            return true
        }

        return count > 0 ? (totalScore / Double(count)) : 0.0
    }

    // MARK: - Semantic Similarity

    private func calculateSimilarity(_ textA: String, _ textB: String) -> Double {
        guard #available(iOS 13.0, *), let embedding = self.embedding else {
            return jaccardSimilarity(textA, textB)
        }

        // Use word embeddings for semantic similarity
        let wordsA = tokenize(textA)
        let wordsB = tokenize(textB)

        guard !wordsA.isEmpty && !wordsB.isEmpty else { return 0.0 }

        // Calculate average embedding similarity
        var totalSimilarity = 0.0
        var comparisons = 0

        for wordA in wordsA {
            guard let vectorA = embedding.vector(for: wordA) else { continue }

            var maxSim = 0.0
            for wordB in wordsB {
                guard let vectorB = embedding.vector(for: wordB) else { continue }
                let sim = cosineSimilarity(vectorA, vectorB)
                maxSim = max(maxSim, sim)
            }

            if maxSim > 0 {
                totalSimilarity += maxSim
                comparisons += 1
            }
        }

        return comparisons > 0 ? totalSimilarity / Double(comparisons) : jaccardSimilarity(textA, textB)
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }

        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        guard normA > 0 && normB > 0 else { return 0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }

    private func jaccardSimilarity(_ textA: String, _ textB: String) -> Double {
        let setA = Set(tokenize(textA))
        let setB = Set(tokenize(textB))

        guard !setA.isEmpty && !setB.isEmpty else { return 0.0 }

        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count

        return Double(intersection) / Double(union)
    }

    // MARK: - Keyword Extraction

    private func extractKeywords(_ text: String) -> [String] {
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        var keywords: [String: Int] = [:]

        // Extract nouns (lexicalClass scheme uses .noun for all noun types)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                if word.count > 2 && !stopWords.contains(word) {
                    keywords[word, default: 0] += 1
                }
            }
            return true
        }

        // Sort by frequency and return top keywords
        let sorted = keywords.sorted { $0.value > $1.value }
        return Array(sorted.prefix(10).map { $0.key })
    }

    // MARK: - Helpers

    private func tokenize(_ text: String) -> [String] {
        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }

    private let stopWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "can", "had",
        "her", "was", "one", "our", "out", "get", "has", "him", "his", "how",
        "its", "may", "new", "now", "old", "see", "way", "who", "did", "got",
        "let", "put", "say", "she", "too", "use", "been", "call", "come",
        "each", "find", "from", "have", "into", "just", "know", "like",
        "look", "made", "make", "many", "more", "most", "much", "must",
        "need", "only", "over", "said", "some", "such", "take", "than",
        "that", "them", "then", "there", "these", "they", "this", "time",
        "very", "want", "well", "went", "what", "when", "will", "with",
        "would", "your", "about", "after", "also", "back", "being", "both",
        "could", "down", "even", "first", "going", "here", "just", "last"
    ]
}
