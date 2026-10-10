# QuickQuiz — Try This Build

This is the project as generated through **Step 3** (models, app shell,
Google Auth + guest/free-quiz logic). Enough is wired up to run the app
and click through: Splash → Onboarding → Home → Sign in with Google.

## Setup

1. **Create the Flutter project shell** (if you don't have one yet):
   ```bash
   flutter create --project-name quickquiz --org com.yourcompany quickquiz_app
   ```
   Then copy every file from this zip's `lib/` folder into
   `quickquiz_app/lib/` (overwriting the generated `main.dart`), and copy
   `pubspec.yaml` and `.env.example` into the project root too.

   Or, if you already have a Flutter project, just copy `lib/`,
   `pubspec.yaml`, and `.env.example` into it, overwriting as needed.

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase** (required — the app won't run without this):
   - Create a project at https://console.firebase.google.com
   - Enable **Authentication → Sign-in method → Google**
   - Enable **Cloud Firestore** (test mode is fine for now, though real
     rules are provided below)
   - Enable **Cloud Functions** (requires the Blaze pay-as-you-go plan —
     the free Spark plan can't make outbound network calls, which the
     quiz-generation function needs to reach the AI provider)
   - Install the FlutterFire CLI if you don't have it:
     ```bash
     dart pub global activate flutterfire_cli
     ```
   - From your project root, run:
     ```bash
     flutterfire configure
     ```
     This overwrites `lib/firebase_options.dart` with real values and adds
     `google-services.json` (Android) / `GoogleService-Info.plist` (iOS).

   - **Android extra step**: Google Sign-In needs your debug SHA-1
     registered in the Firebase console (Project settings → Your apps →
     Android app → Add fingerprint). Get it with:
     ```bash
     cd android && ./gradlew signingReport
     ```

4. **Deploy the Cloud Function** (needed for quiz generation to work):
   ```bash
   npm --prefix functions install
   firebase functions:secrets:set ANTHROPIC_API_KEY
   # paste your Anthropic API key when prompted
   firebase deploy --only functions
   ```
   `functions/index.js` calls Anthropic's API by default — swap the
   `callAiProvider` function's body if you'd rather use a different
   provider; nothing else needs to change.

5. **Deploy the Firestore security rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```
   `firestore.rules` restricts every user to reading/writing only their
   own profile and their own quiz history — see the file for the full
   rules and comments.

6. **Copy the env file:**
   ```bash
   cp .env.example .env
   ```

7. **Configure AdMob's native App ID** (required for ads to work at all —
   this is separate from the per-ad-unit IDs in `lib/utils/constants.dart`):
   - **Android**: in `android/app/src/main/AndroidManifest.xml`, inside
     `<application>`, add:
     ```xml
     <meta-data
         android:name="com.google.android.gms.ads.APPLICATION_ID"
         android:value="ca-app-pub-3940256099942544~3347511713"/>
     ```
     (that's Google's public **test** App ID — replace with your real one
     from the AdMob console before release)
   - **iOS**: in `ios/Runner/Info.plist`, add:
     ```xml
     <key>GADApplicationIdentifier</key>
     <string>ca-app-pub-3940256099942544~1458002511</string>
     ```
     (also Google's test App ID for iOS — replace before release)

8. **Run it:**
   ```bash
   flutter run
   ```

## What you can actually test right now

- App launches to the **Splash** screen (gradient, spinner)
- Auto-navigates to **Onboarding** (minimal placeholder) on first launch
- Tapping **Get Started** marks onboarding complete and goes to **Home**
- Home shows `Hello, Guest!` and **"You can create a quiz right now."**
  (this is `AuthViewModel.canCreateQuiz()` actually running)
- Tapping **Continue with Google** runs the real Firebase Google Sign-In
  flow — after signing in, the greeting updates to your name and a
  **Sign Out** button appears
- Force-close and reopen the app — Splash now skips Onboarding and goes
  straight to Home (onboarding flag persisted via SharedPreferences)
- Tapping **Upload File** opens the real Upload screen:
  - pick a real PDF, DOCX, PPTX, or TXT file from your device
  - unsupported types, oversized files (>20MB), and empty files are
    rejected with friendly messages
  - tap **Analyze File** to run real text extraction (PDF via Syncfusion,
    DOCX/PPTX via manual zip+XML parsing, TXT directly)
  - files with too little readable text (e.g. an image-only PDF) are
    rejected rather than silently producing a broken quiz later
  - once extraction succeeds, tap **Continue** to go to **Quiz Settings**
- **Quiz Settings**: pick question count (1-50, via slider or quick chips)
  and difficulty, tap **Generate Quiz**
  - this calls the real deployed Cloud Function, which calls the AI
    provider server-side and returns a validated quiz
  - on success you land on a temporary Quiz summary screen showing the
    question count, difficulty, and first question — confirming
    generation actually worked end-to-end
  - **as a guest**, generate a second quiz (go Home → Upload → Settings →
    Generate again) — you'll see the **"Continue Learning with QuickQuiz"**
    sign-in dialog exactly per spec, and after signing in, generation
    automatically retries and succeeds
  - the free quiz is only marked "used" after a quiz is *successfully*
    generated — a failed generation (e.g. turn off wifi) does not consume it
- **Quiz screen** (now fully interactive):
  - progress bar + "Question X of Y" header
  - tap any of the 4 options to select it — tap a different one to change
    your answer before moving on
  - Previous/Next navigation, answers are remembered as you move back and forth
  - on the last question, the button becomes **Submit Quiz**, which opens
    a confirmation dialog showing "You answered X of Y questions" with
    **Review Answers** / **Submit Quiz** actions
  - submitting takes you to the real **Result** screen: a colored score
    ring (green ≥75%, orange ≥50%, red below), your score fraction and
    percentage, the correct performance-tier message per your spec
    (Excellent/Great job/Good effort/Keep practicing), and correct/
    incorrect/total stat chips
  - **Try Again** resets all answers on the same quiz and takes you right
    back into it — no new API call, no free-quiz consumption
  - **Create New Quiz** goes to Upload
  - **Review Answers** goes to the real Review screen: every question
    listed with a status icon/label (Correct / Incorrect / Not answered
    in a distinct neutral color), your answer, the correct answer (shown
    only when you got it wrong), and the explanation for every question
  - the app bar shows a running `X/Y correct` count; a Home button sits
    at the bottom
- **Home** now has a bottom nav bar (Home / History / Profile) and, for
  signed-in users, real **Total Quizzes / Average Score / Best Score**
  stat cards pulled from Firestore
- **History**:
  - as a **guest**, shows "Sign in with Google to save and access your
    quiz history" with a working sign-in button
  - as a **signed-in user**, finish a quiz (Result screen auto-saves it
    to Firestore for you — no extra step needed) then check History: you
    should see a card like `Networking.pptx · Hard · 20 Questions ·
    Score: 18/20 · 90%`
  - pull-to-refresh reloads from Firestore; an empty state shows if you
    haven't completed any quizzes yet
  - real Firestore security rules (`firestore.rules`) mean this only
    ever shows *your own* history — verify by checking the Firebase
    console directly if you want to see the raw `quizzes` collection

- **Profile** tab:
  - as a **guest**: "You are using QuickQuiz as a Guest." with a working
    **Continue with Google** button
  - as a **signed-in user**: your real Google profile photo (or initials
    if you don't have one), name, email, the same Total Quizzes/Average
    Score/Best Score stats as Home, and a working **Sign Out** button
- **Ads**: with test AdMob IDs (the default until you flip
  `useTestAds`/pass `--dart-define=PRODUCTION=true`), you should see a
  Google test banner near the bottom of Home, Result, and History — and
  a full-screen test interstitial right after submitting a quiz, before
  the Result screen appears. None of these ever block the app: turn off
  wifi and finish a quiz — no ad loads, but everything still works
  exactly the same.

## What's built

All 24 items from the original plan are implemented: the full guest →
free-quiz → sign-in gate → upload → parse → generate → take quiz →
result → review → history → profile loop, backed by a real Cloud
Function, real Firestore rules, and AdMob with graceful fallbacks
throughout.

**Final hardening pass (this step):**
- `ConnectivityService` now actually used — quiz generation fails fast
  with a clear "no internet" message instead of waiting out a 90s timeout
- Every ViewModel that starts a network/IO operation now guards itself
  against double-taps internally (`if (isLoading) return`), not just via
  disabled buttons in the UI
- App-wide crash safety net: `ErrorWidget.builder` replaces Flutter's raw
  red error screen with a friendly fallback in release builds, and
  `runZonedGuarded` catches any uncaught async error instead of crashing
- See **`TESTING.md`** for the full manual test checklist mapping every
  scenario from the spec's Error Handling section to where it's
  implemented and how to trigger it
