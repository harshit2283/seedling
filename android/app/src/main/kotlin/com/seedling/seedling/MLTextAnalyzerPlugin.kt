package com.twotwoeightthreelabs.seedling

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.google.mlkit.nl.entityextraction.*
import com.google.mlkit.nl.languageid.LanguageIdentification
import kotlinx.coroutines.*

/**
 * Plugin that provides ML-based text analysis using Google ML Kit
 *
 * Uses on-device ML Kit APIs for:
 * - Entity extraction (people, places, organizations, dates)
 * - Language identification
 * - Text similarity (using custom implementation)
 *
 * Note: ML Kit's Entity Extraction requires downloading models (~10MB each).
 * The plugin handles this gracefully with fallbacks.
 */
class MLTextAnalyzerPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var entityExtractor: EntityExtractor? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.seedling.app/ml_text_analyzer")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext

        // Initialize entity extractor with English model
        val options = EntityExtractorOptions.Builder(EntityExtractorOptions.ENGLISH).build()
        entityExtractor = EntityExtraction.getClient(options)

        // Download model if needed (async, non-blocking)
        entityExtractor?.downloadModelIfNeeded()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        entityExtractor?.close()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAvailable" -> {
                result.success(entityExtractor != null)
            }

            "detectTheme" -> {
                val text = call.argument<String>("text")
                if (text == null) {
                    result.error("INVALID_ARGS", "Missing text argument", null)
                    return
                }
                detectTheme(text, result)
            }

            "analyzeSentiment" -> {
                val text = call.argument<String>("text")
                if (text == null) {
                    result.error("INVALID_ARGS", "Missing text argument", null)
                    return
                }
                analyzeSentiment(text, result)
            }

            "calculateSimilarity" -> {
                val textA = call.argument<String>("textA")
                val textB = call.argument<String>("textB")
                if (textA == null || textB == null) {
                    result.error("INVALID_ARGS", "Missing text arguments", null)
                    return
                }
                calculateSimilarity(textA, textB, result)
            }

            "extractKeywords" -> {
                val text = call.argument<String>("text")
                if (text == null) {
                    result.error("INVALID_ARGS", "Missing text argument", null)
                    return
                }
                extractKeywords(text, result)
            }

            else -> result.notImplemented()
        }
    }

    // MARK: - Theme Detection

    private fun detectTheme(text: String, result: Result) {
        scope.launch {
            try {
                val entities = extractEntitiesSync(text)
                val theme = scoreThemes(text.lowercase(), entities)
                withContext(Dispatchers.Main) {
                    result.success(theme)
                }
            } catch (e: Exception) {
                // Fallback to keyword-only detection
                val theme = detectThemeWithKeywords(text.lowercase())
                withContext(Dispatchers.Main) {
                    result.success(theme)
                }
            }
        }
    }

    private suspend fun extractEntitiesSync(text: String): Map<String, Int> {
        return suspendCancellableCoroutine { continuation ->
            entityExtractor?.annotate(text)
                ?.addOnSuccessListener { entityAnnotations ->
                    val counts = mutableMapOf<String, Int>()
                    for (annotation in entityAnnotations) {
                        for (entity in annotation.entities) {
                            val type = when (entity.type) {
                                Entity.TYPE_ADDRESS -> "address"
                                Entity.TYPE_DATE_TIME -> "datetime"
                                Entity.TYPE_EMAIL -> "email"
                                Entity.TYPE_FLIGHT_NUMBER -> "flight"
                                Entity.TYPE_IBAN -> "iban"
                                Entity.TYPE_ISBN -> "isbn"
                                Entity.TYPE_MONEY -> "money"
                                Entity.TYPE_PAYMENT_CARD -> "payment"
                                Entity.TYPE_PHONE -> "phone"
                                Entity.TYPE_TRACKING_NUMBER -> "tracking"
                                Entity.TYPE_URL -> "url"
                                else -> "other"
                            }
                            counts[type] = (counts[type] ?: 0) + 1
                        }
                    }
                    continuation.resumeWith(kotlin.Result.success(counts))
                }
                ?.addOnFailureListener {
                    continuation.resumeWith(kotlin.Result.success(emptyMap()))
                }
                ?: continuation.resumeWith(kotlin.Result.success(emptyMap()))
        }
    }

    private fun scoreThemes(text: String, entities: Map<String, Int>): String {
        val scores = mutableMapOf<String, Double>()

        // Theme keywords with weights
        val themeKeywords = mapOf(
            "family" to mapOf("mom" to 2.0, "dad" to 2.0, "mother" to 2.0, "father" to 2.0,
                "family" to 2.0, "sister" to 1.5, "brother" to 1.5, "parent" to 1.5,
                "child" to 1.5, "kids" to 1.5, "grandma" to 1.5, "grandpa" to 1.5,
                "home" to 1.0, "love" to 0.5),
            "friends" to mapOf("friend" to 2.0, "friends" to 2.0, "buddy" to 1.5,
                "hangout" to 1.5, "party" to 1.0, "fun" to 0.5, "laughed" to 0.5),
            "work" to mapOf("work" to 2.0, "job" to 2.0, "meeting" to 1.5, "office" to 1.5,
                "project" to 1.5, "career" to 1.5, "boss" to 1.0, "colleague" to 1.0),
            "nature" to mapOf("nature" to 2.0, "outside" to 1.5, "outdoors" to 1.5,
                "sun" to 1.0, "rain" to 1.0, "tree" to 1.0, "flower" to 1.0,
                "walk" to 0.5, "hike" to 1.0, "garden" to 1.0),
            "gratitude" to mapOf("grateful" to 2.0, "thankful" to 2.0, "appreciate" to 1.5,
                "blessed" to 1.5, "lucky" to 1.0, "wonderful" to 0.5),
            "reflection" to mapOf("think" to 1.0, "feel" to 1.0, "realize" to 1.5,
                "learn" to 1.0, "wonder" to 1.0, "remember" to 1.0),
            "travel" to mapOf("travel" to 2.0, "trip" to 2.0, "vacation" to 2.0,
                "flight" to 1.5, "visit" to 1.0, "explore" to 1.0),
            "creativity" to mapOf("create" to 2.0, "art" to 2.0, "write" to 1.5,
                "music" to 2.0, "paint" to 1.5, "design" to 1.5),
            "health" to mapOf("health" to 2.0, "exercise" to 2.0, "workout" to 2.0,
                "run" to 1.0, "yoga" to 1.5, "gym" to 1.5, "sleep" to 1.0),
            "food" to mapOf("food" to 2.0, "eat" to 1.5, "cook" to 2.0, "meal" to 1.5,
                "dinner" to 1.5, "lunch" to 1.5, "breakfast" to 1.5)
        )

        for ((theme, keywords) in themeKeywords) {
            var score = 0.0
            for ((keyword, weight) in keywords) {
                if (text.contains(keyword)) {
                    score += weight
                }
            }
            scores[theme] = score
        }

        // Boost based on ML Kit entities
        if (entities.containsKey("address") || entities.containsKey("flight")) {
            scores["travel"] = (scores["travel"] ?: 0.0) + 1.5
        }
        if (entities.containsKey("datetime")) {
            scores["reflection"] = (scores["reflection"] ?: 0.0) + 0.5
        }

        return scores.maxByOrNull { it.value }?.key ?: "moments"
    }

    private fun detectThemeWithKeywords(text: String): String {
        return scoreThemes(text, emptyMap())
    }

    // MARK: - Sentiment Analysis

    private fun analyzeSentiment(text: String, result: Result) {
        // ML Kit doesn't have built-in sentiment analysis, so we use keyword-based approach
        val content = text.lowercase()

        val positiveWords = listOf(
            "happy", "joy", "love", "great", "wonderful", "amazing", "beautiful",
            "grateful", "thankful", "excited", "fun", "good", "best", "awesome"
        )
        val negativeWords = listOf(
            "sad", "angry", "hate", "bad", "terrible", "awful", "worst", "worried",
            "anxious", "stressed", "frustrated", "disappointed", "upset"
        )

        var score = 0.0
        for (word in positiveWords) {
            if (content.contains(word)) score += 0.1
        }
        for (word in negativeWords) {
            if (content.contains(word)) score -= 0.1
        }

        result.success(score.coerceIn(-1.0, 1.0))
    }

    // MARK: - Similarity

    private fun calculateSimilarity(textA: String, textB: String, result: Result) {
        val tokensA = tokenize(textA)
        val tokensB = tokenize(textB)

        if (tokensA.isEmpty() || tokensB.isEmpty()) {
            result.success(0.0)
            return
        }

        // Jaccard similarity
        val intersection = tokensA.intersect(tokensB).size
        val union = tokensA.union(tokensB).size

        val similarity = if (union > 0) intersection.toDouble() / union else 0.0
        result.success(similarity)
    }

    // MARK: - Keywords

    private fun extractKeywords(text: String, result: Result) {
        scope.launch {
            try {
                // Use entity extraction for key terms
                val entities = extractEntitiesSync(text)
                val tokens = tokenize(text)

                // Filter and rank tokens
                val keywords = tokens
                    .groupingBy { it }
                    .eachCount()
                    .entries
                    .sortedByDescending { it.value }
                    .take(10)
                    .map { it.key }

                withContext(Dispatchers.Main) {
                    result.success(keywords)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.success(tokenize(text).take(10))
                }
            }
        }
    }

    // MARK: - Helpers

    private fun tokenize(text: String): Set<String> {
        return text.lowercase()
            .replace(Regex("[^\\w\\s]"), " ")
            .split(Regex("\\s+"))
            .filter { it.length > 2 && !stopWords.contains(it) }
            .toSet()
    }

    private val stopWords = setOf(
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
    )
}
