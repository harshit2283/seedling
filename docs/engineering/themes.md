# Themes and Related Memories

How Seedling assigns a theme to each memory and picks "Related memories",
how quality is measured, and how to change either without regressing it.
Everything runs on-device, offline, with no model downloads.

## Themes

Code: `lib/core/services/ai/theme_detector_service.dart` (classifier),
`lib/core/services/ai/theme_lexicon.dart` (data).

The theme is detected when an entry is saved (`EntryCreatorNotifier`) and
persisted in `Entry.detectedTheme`. Badges, filters, Theme Insights and Year
in Review all read the stored value.

### How it works

A weighted-lexicon classifier, tuned for short personal texts such as
"coffee with mum on the porch" or "first frost on the car":

| Signal | Example |
|---|---|
| Curated lexicon per theme, weights 0.25 to 4.5 | `kiln` 3 for creativity, `walk` 1 for nature |
| Inflections generated from the base form | `hike` also matches hiked, hiking, hiker |
| Irregular forms, typos, single-edit typo matches at 0.4x | ran → run, freinds → friends |
| British/American and accent folding | colour = color, realise = realize, Bàba = baba |
| Phrases, and blocker phrases that score nothing | "letting go", "couch to 5k"; "running late" |
| Relationship words in many languages | mum, nan, abuela, appa, oma, nonna, babcia |
| Emoji | 🍜 food, ✈️ travel, 👶 family |
| Destination gazetteer (1.25) | Lisbon, Kyoto, Patagonia |
| Capitalised names after "with"/"and" (friends), "in"/"to" (travel) | "lunch with Ana" |
| Negation halves a word's weight | "didn't run today" is still about health |
| Company after "with" counts 0.75x | "painted with my daughter" is creativity |
| Field weights | title 1.5, text and transcription 1, context 0.75, mood 0.5 |
| Release prior | +0.75 reflection on release entries |

The top theme needs a score of at least `minimumScore` (1.0), which a single
defining word reaches. Otherwise the entry is **moments**, which therefore
means "nothing else applies", not "the detector gave up". A few explicit
cues ("nothing happened", "ordinary day") also score for moments.

`analyze()` returns the primary theme, a secondary theme (when the runner-up
has at least half the primary's score and passes the minimum), a confidence
from 0 to 1, and the raw scores. Only the primary is persisted.

Cost: about 30 µs per entry (debug JIT, so release builds are faster), and
the lexicon source is 37 KB. The lookup tables are built once per isolate
the first time they are used.

### Why not a trained model?

We considered a multinomial naive Bayes or logistic regression model
trained offline. The labelled set is about 300 training texts written by the
same author who wrote the lexicons. A model trained on it would mostly learn
that author's phrasing, and on such short texts it would almost never have
seen the words a user writes. The curated lexicon is a hand-built prior that
works on any vocabulary. If we collect a larger set from varied writers
(opt-in, never user data), a small linear model over the same features is
the next step. It should be shipped as a Dart const map and stay under
200 KB.

### Evaluation

The labelled set is `test/fixtures/theme_eval.json`. It has 420 memories
(361 lines, 30 releases, 20 capsules, 9 objects), covering many ages,
cultures and spellings, with typos, emoji and multi-theme cases. Each has a
primary theme and an optional secondary theme. It is split 70/30, stratified
by theme, with a fixed seed. **The test split is held out: tune only on the
train split.** The verbose run prints misses from the train split only.

```bash
THEME_EVAL_VERBOSE=1 flutter test test/services/ai/theme_eval_test.dart
```

Held-out results (n = 127):

| | Keyword detector (before) | Weighted lexicon (now) |
|---|---|---|
| Accuracy | 8.7% | 81.9% |
| Accuracy counting secondary | 8.7% | 84.3% |
| Macro-F1 | 0.014 | 0.817 |
| Predicted "moments" | 100% | 6.3% (true share 8.7%) |

The train split scores 89.8% accuracy and 0.899 macro-F1. The gap to the
held-out numbers is the expected cost of tuning on train. The old detector
divided keyword hits by the size of each list and needed a ratio of 0.1,
roughly five hits, so every real memory came out as moments.

Caveat: the same person wrote the texts, the labels and the lexicons. The
held-out split guards against tuning to particular sentences, but not
against one author's view of what each theme means. Treat the numbers as a
regression guard, not as a benchmark.

The weakest themes on the held-out split are gratitude and reflection
(F1 0.71). Many of their misses are labelling judgement calls, such as
"So grateful my dad is home" against "Mom drove four hours to bring soup".

`theme_eval_test.dart` fails if held-out macro-F1 or accuracy falls below
0.78, if the predicted moments share drifts more than 5 points from the true
share, or if inference takes more than 1 ms per entry.

### Changing the lexicon

1. Add terms in their base form. Inflections, spelling variants and accents
   are generated automatically.
2. Run the eval in verbose mode and read the train misses. Do not read the
   held-out texts while tuning.
3. Bump `ThemeBackfillService.currentVersion` if stored themes should
   change for existing users.

## Backfill

`ThemeBackfillService` runs once per `currentVersion`, off the UI isolate
for collections of 200 or more. Version 2 re-themes every entry whose stored
theme is one of ours, since all themes are auto-assigned. Labels we don't
recognise, such as those from an imported journal, are kept. Only changed
entries are written, with `preserveModifiedAt` so sync does not treat them
as edits.

## Related memories

Code: `lib/core/services/ai/connection_finder_service.dart`.

| Factor | Weight | Notes |
|---|---|---|
| Text | 0.85 | TF-IDF cosine over the user's own collection, binary tf, 20 pseudo-document prior so new users' few entries still link; normalised and lightly stemmed terms (cups = cup, glazed = glaze) |
| People and places | 0.45 | Relationship words folded per person (mum = mom = mother), but not "her mum" or "Priya's mum"; capitalised words the collection never writes in lowercase (Leo, Atlas, Lisbon); weighted by rarity |
| Theme | 0.25 | Same persisted theme 1, related theme 0.5; moments counts as no theme |
| Time | 0.15 | Same or adjacent day 1, linear decay to 7 days |

The total is clamped to 1. A pair needs text or people/places evidence
before theme and time count, so two unrelated entries from the same week
are never "related". The weights put the old 0.3 "meaningful" cut-off at
the best balance of precision and coverage on the train split, so the UI's
0.3/0.5/0.7 strength dots keep their meaning.

Caching: token sets and entities are cached per entry id and invalidated by
content. Document frequencies are cached per collection and rebuilt when a
different list is passed in or any entry's tokens change.

### Evaluation

The labelled set is `test/fixtures/connection_eval.json`. It is one
simulated journal of 64 entries from January to October 2026, with 45 query
entries. Gold labels are every other entry of the same story plus
hand-picked cross links. There are 19 unrelated same-day distractors, and
four story clusters are held out.

```bash
THEME_EVAL_VERBOSE=1 flutter test test/services/ai/connection_eval_test.dart
```

Precision@3 here means hits in the top 3 divided by min(3, number of
related entries), so returning nothing scores 0. Shown precision means
relevant shown divided by shown.

| | Before (Jaccard + time + theme) | Now |
|---|---|---|
| Train P@3 | 0.176 | 0.696 |
| Train shown precision | 0.750 | 0.959 |
| Held-out P@3 | 0.000 | 0.864 |
| Held-out shown precision | 0.000 | 0.760 |
| Distractor links per entry | 0.20 | 0.47 |

Most distractor links are fair: "Leo has a cold" links to other Leo
entries, and "new shoes for the wedding" links to Priya's wedding. The
remaining misses need coreference to resolve. For example, "Found his old
pocket watch" means Grandad's watch, but nothing in the text says so.

Warm `findConnections` (cached tokens) takes 1.2 ms for 500 entries and
3.8 ms for 2,000. It took 8.1 ms and 6.3 ms before the change. See
`test/benchmarks/ai_perf_benchmark.dart`.
