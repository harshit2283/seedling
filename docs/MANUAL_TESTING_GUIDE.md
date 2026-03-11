# Manual Testing Guide - Animated Tree

This guide covers how to manually test the animated tree visualization on iOS and Android emulators.

## Prerequisites

```bash
# Verify Flutter is set up
flutter doctor

# Get dependencies
flutter pub get
```

## Running on Emulators

### iOS Simulator

```bash
# List available simulators
xcrun simctl list devices

# Start a simulator (if not running)
open -a Simulator

# Run the app
flutter run -d iphone
```

### Android Emulator

```bash
# List available emulators
flutter emulators

# Start an emulator
flutter emulators --launch <emulator_id>

# Run the app
flutter run -d android
```

---

## Test Cases

### 1. Idle Animation

**Steps:**
1. Launch the app
2. Observe the tree on the home screen

**Expected:**
- Tree sways gently side-to-side
- Movement is continuous (3-second cycle)
- Leaves/canopy have subtle wobble
- Animation is smooth, not jerky

---

### 2. Tree States (Visual Verification)

Test each of the 6 tree states by adding entries:

| State | Entry Count | Visual |
|-------|-------------|--------|
| Seed | 0-10 | Small glowing oval with ground line |
| Sprout | 11-30 | Curved stem with two leaves |
| Sapling | 31-100 | Small trunk with branches and leaf clusters |
| Young Tree | 101-250 | Multiple branch tiers, fuller canopy |
| Mature Tree | 251-500 | Thick trunk, visible roots, large canopy |
| Ancient Tree | 501+ | Gnarled trunk, elaborate roots, massive layered canopy with glow |

**Quick Test (using debug):**

To quickly test all states without adding hundreds of entries, temporarily modify `lib/data/models/tree.dart`:

```dart
// In Tree.calculateState(), temporarily change thresholds:
static TreeState calculateState(int entryCount) {
  if (entryCount <= 1) return TreeState.seed;      // was 10
  if (entryCount <= 2) return TreeState.sprout;    // was 30
  if (entryCount <= 3) return TreeState.sapling;   // was 100
  if (entryCount <= 4) return TreeState.youngTree; // was 250
  if (entryCount <= 5) return TreeState.matureTree;// was 500
  return TreeState.ancientTree;
}
```

Then add 6 entries to see all states. **Remember to revert changes after testing.**

---

### 3. Growth Transition Animation

**Steps:**
1. Note the current tree state
2. Add entries until the tree reaches the next threshold
3. Observe the transition

**Expected:**
- Smooth morphing animation between states
- Scale bounce effect (tree slightly shrinks then expands)
- Medium haptic feedback on device
- Duration ~1.2 seconds

---

### 4. Celebration Particles

**Steps:**
1. Add entries to trigger a state transition (e.g., from Seed to Sprout at 11 entries)

**Expected:**
- Sparkle burst emanates from tree
- Particles are star-shaped
- Colors: green, amber, white mix
- Particles float upward then fade
- Light haptic feedback
- Duration ~2 seconds

---

### 5. Seasonal Colors

Test by changing the device date:

| Season | Months | Expected Colors |
|--------|--------|-----------------|
| Spring | Mar-May | Fresh green leaves + pink blossoms |
| Summer | Jun-Aug | Full green canopy |
| Autumn | Sep-Nov | Orange/red leaves + falling leaf particles |
| Winter | Dec-Feb | Muted/pale green |

**iOS Simulator:**
1. Open Settings > General > Date & Time
2. Disable "Set Automatically"
3. Change date to target month
4. Return to app (may need to restart)

**Android Emulator:**
1. Open Settings > System > Date & time
2. Disable "Automatic date & time"
3. Set date to target month
4. Return to app

---

### 6. Tap Interaction

**Steps:**
1. Tap on the tree

**Expected:**
- Navigates to Memories screen
- No visual glitch during navigation

---

### 7. Progress Indicator

**Steps:**
1. Observe the progress bar below tree label
2. Add entries and watch progress

**Expected:**
- Progress bar fills as entries are added
- Resets to 0 at each state boundary
- Shows "Flourishing" text for Ancient Tree (no bar)

---

### 8. State Label

**Steps:**
1. Observe the label below the tree

**Expected:**
- Shows current state name (Seed, Sprout, Sapling, Young Tree, Mature Tree, Ancient Tree)
- Color matches tree state theme color

---

## Performance Testing

### Frame Rate

**Steps:**
1. Enable performance overlay: `flutter run --profile`
2. Observe the tree idle animation

**Expected:**
- Consistent 60fps (or device refresh rate)
- No dropped frames during idle
- No jank during growth transitions

### Memory

**Steps:**
1. Run with DevTools: `flutter run` then open DevTools
2. Monitor memory during state transitions

**Expected:**
- No memory leaks
- Stable memory usage during idle animation
- Particles are cleaned up after celebration

---

## Regression Checklist

Before releasing, verify:

- [ ] All 6 tree states render correctly
- [ ] Idle sway animation is smooth
- [ ] Growth transitions animate properly
- [ ] Celebration particles appear on growth
- [ ] Haptic feedback works (on physical device)
- [ ] Seasonal colors change with date
- [ ] Tap navigates to Memories
- [ ] Progress bar updates correctly
- [ ] No crashes or ANRs
- [ ] Performance is acceptable (60fps)

---

## Troubleshooting

**Tree not animating:**
- Ensure app is in foreground
- Check that `TickerProviderStateMixin` is working (hot restart may help)

**Wrong season showing:**
- Season is determined at widget init
- Restart app after changing device date

**Celebration not triggering:**
- Only triggers on state *increase* (not decrease)
- Check that `treeGrowthDetectorProvider` is being watched in TreeScreen

**Haptics not working:**
- Only works on physical devices
- Check device haptic settings
