# Sweet Kingdom · مملكة الحلوى

Original offline portrait Match-3 for Android. The refreshed preview uses a separate Android app ID so it can install alongside the first debug build, which keeps its existing save. Arabic is the default language. Switch to English from the home screen or settings.

## Play

Swipe between adjacent tiles or tap two neighboring candies. Match three to clear them. Match four for a rocket, five for a rainbow, or make a T or L for a bomb. Swap a rainbow with a candy to clear its color. Swap two specials for a combined effect. Jelly loses one layer per clear, cocoa blocks take a hit from neighboring matches, and locked candies can be matched in place.

The four boosters are Hammer, Extra Moves, Shuffle, and Color Blast. Initial stock is free. After stock runs out, the displayed coin cost is charged only when the booster activates. Five lives cap the offline lives system. A failed level spends a life and a life regenerates every 20 minutes.

## Install the debug APK

1. Open the repository's **Actions** tab and choose a successful **Android debug** run.
2. Download **sweet-kingdom-android-debug** from **Artifacts** while signed in to GitHub.
3. Extract the ZIP and open **sweet-kingdom-debug.apk** on an ARM Android device. Allow installs from the file manager if prompted.
4. With Android platform-tools and USB debugging enabled, you can also run **adb install -r sweet-kingdom-debug.apk**.

The APK is debug signed. Each GitHub Actions runner generates its own test keystore, so a later build may require uninstalling the prior version. Uninstalling removes local game progress. Android 8.0 and higher is the target. Device verification remains pending.

## Develop

Open **project.godot** with Godot 4.5.1 and run the main scene. The Compatibility renderer uses baked, original 2.5D candy lighting. Audio is synthesized by the project. The candy kingdom scenic plates are original generated art. Tajawal ExtraBold is distributed under its included SIL Open Font License. The build records actual Godot screenshots of Home, the map, and gameplay in its artifact. No network or external assets are required at runtime.

Run in a clean user-data environment:

    godot --headless --path . --editor --import
    godot --headless --path . --script tests/run.gd

The suite runs seeded rule and UI checks plus a greedy simulation for every level. Simulation provides sample playthroughs and flags levels the policy did not beat. It cannot establish device behavior or prove a level impossible.

For a local Android build, install matching export templates, OpenJDK 17, and Android platform 35 and build-tools 35.0.0. Set the JDK, Android SDK, and debug keystore paths in Godot Editor Settings, then use the Android export preset:

    mkdir -p build
    godot --headless --path . --export-debug Android build/sweet-kingdom-debug.apk

## Project structure

- **scripts/board/board.gd** contains seeded board generation, turn resolution, powers, obstacles and objectives. The board produces snapshots and animation events without depending on a renderer.
- **scripts/ui/** contains the portrait UI, map, Arabic/English switching, swipe input and visual playback. The board locks input while it plays back a turn.
- **scripts/save/profile.gd** saves progress and settings in two alternating checksummed files. It can recover an earlier generation and warns when saved data cannot be read. The local clock high-water mark protects against backwards clock changes. An offline game cannot independently verify large forward clock edits.
- **data/levels/kingdom.json** contains 50 level definitions and reward thresholds.
- **assets/** contains the original procedural art and sound sources.
- **tests/run.gd** contains rule, profile, UI and balance automation.
- **.github/workflows/android-debug.yml** imports, tests, exports, verifies and uploads the APK.
