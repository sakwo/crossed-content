# Deferred — crossed-content

Things intentionally **NOT DONE**. The `validate-catalogs` CI guard
(`tools/validate_catalogs.dart` + `.github/workflows/validate-catalogs.yml`) checks that each
catalog parses under the app's actual validators. It does **not** cover the items below. Each entry
has enough detail to act without re-deriving. (Authoritative behavior reference lives in the app repo:
`crossed-ai-workspace/docs/specs/catalog-constraints.md`.)

## 1. Cross-file consistency checks — NOT DONE

The current guard validates each file **in isolation**. It does not check relationships **between**
files. Missing:

- **Free-set parity across `scenes.json` and `backgrounds.json`.** The 8 free ids
  (`default, dusk, ocean, ember, beach, mountains, forest, night`) must exist in **both** files — the
  set read by 1.0.0 + 2.0.0-free (`scenes.json`) and by 2.0.0-premium (`backgrounds.json`). Today
  nothing catches a free background added to one file but not the other, so it would appear for one
  audience and silently not the other. A check should assert: `{ids in scenes.json}` ⊆
  `{free ids in backgrounds.json}` (and flag any drift).
- **Premium background↔sound pairing.** Backgrounds carry an optional `suggestedSound` that should
  reference an existing `sounds.json` `id` (or be null). Nothing verifies the referenced sound id
  actually exists. A check should assert every non-null `suggestedSound` ∈ `{ids in sounds.json}`.

To act: extend `tools/validate_catalogs.dart` with a post-per-file cross-reference pass (load all four,
assert the set relationships above), or add a second script invoked by the same workflow step.

## 2. Validator drift protection — NOT DONE

`tools/validate_catalogs.dart` is a **frozen hand-copy** of the app's validators
(`validateVerses`/`validateScenes` from `crossed-ai-workspace` commit `d64669e`;
`validateBackgrounds`/`validateSoundsCatalog` from `main`). **Nothing detects when the app-side parser
changes** and this copy goes stale — the guard would then validate against outdated rules and could
pass a file the real app rejects (or vice-versa). This is a real risk because the two repos are
independent and the copy has no link back to its source.

To act (options, pick one): (a) a scheduled/manual check that re-extracts the four `validate*` functions
from the app repo at a pinned or latest commit and diffs them against this copy, failing on drift;
(b) generate `validate_catalogs.dart` from the app source rather than hand-copying; (c) at minimum,
record the source commit SHAs in the script header and add a checklist item to re-sync whenever the
app's verse/scene/background/sound parsers change. Today only (c)'s SHAs are noted, with no automated
drift detection.

## 3. Local pre-push hook — NOT DONE

The guard runs only in CI (after the push is already on the ref — see §4). There is **no local
pre-push hook**, so a malformed file can be pushed and *then* fail CI. A `.git/hooks/pre-push` (or a
tracked `hooks/` dir + `git config core.hooksPath hooks`) that runs
`dart run tools/validate_catalogs.dart` and blocks the push on failure would catch it before it leaves
the machine. Deferred because git hooks aren't shared automatically (each clone must opt in) and need
a local Dart SDK; document the opt-in if adopted.

## 4. Branch protection to make the guard a GATE — NOT DONE (optional)

The CI guard is an **ALARM, not a gate**: `raw.githubusercontent.com` serves committed bytes
regardless of check status, and the Action runs *after* the commit lands. A malformed file pushed to
`main` is served immediately and only *then* reported.

To convert it into a real gate: protect `main` (repo Settings → Branches, or `gh api`) with
**"Require status checks to pass" = `validate-catalogs`** AND **disallow direct pushes** (require all
changes via PR). Then bad content cannot reach `main` — and therefore the raw URL — without a green
check. Deferred as a deliberate choice: it forces every catalog edit through a PR, which is heavier for
a solo content workflow. Enable it if/when catalog edits are done by more than one person, or before a
period where a bad publish would be especially costly (e.g. right after a store launch).

## 5. iOS 26 feature candidates — NOT STARTED (v3.1 / v4 only)

> **Status: NONE of these are started or scheduled.** Build 56 + the Guideline 3.1.2(c) resubmission
> come first — **3.0.0 must be LIVE on the App Store before any of these is picked up.** These are
> v3.1 / v4 candidates for evaluation, not committed work. (Unlike §§1–4, these are *app* features, not
> catalog-guard gaps — recorded here as the project's deferred-features home.)

**Shared constraints — apply to every candidate below, stated once:**

- **iOS 26+ only.** Each needs a graceful fallback / feature gate for older devices (the install base is
  mostly pre-26 at launch, so the fallback path is the common path for a while).
- **Native Swift in `platform/ios`, bridged via a platform channel** — none of these is a DSL
  (`dsl/edit.dart`) edit. They live in the owned native tree; only a real overlaid build exercises them.
- **No Android equivalent.** Each is iOS-only as scoped here; Android parity is a **separate** question
  per feature (different APIs, different Play policy), so each is really a two-platform decision, not a
  free cross-platform win.

### 5.1 Foundation Models — on-device devotional generation — HIGHEST VALUE

iOS 26 ships a **free, on-device, offline, no-API-key LLM** (~3B params, Apple Foundation Models).
Candidate uses:

- **AI devotional reflection per KJV verse** — a short generated reflection alongside the verse.
- **Auto-classify verses into topic themes** — reduce manual tagging of the 31,102-verse set. Tags are a
  persisted API (see `crossed-ai-workspace/docs/specs/catalog-constraints.md` and README §"Never rename a
  verse `tag`"), so generation would ASSIST tagging, never silently rewrite existing tags.
- **"Verse for my situation"** — natural-language input → suggested verse.

Notes: **free per request, fully private** (nothing leaves the device — a strong fit for a faith
audience), and Apple reviewers favor its adoption.
⚠️ **If marketed, describe it precisely with honest, device-gating language.** We were rejected once
under **Guideline 2.3.6** for describing an unbuilt feature — do not repeat that. This is the HONEST
version of the previously-cut "AI backgrounds/sounds" direction: devotional **TEXT** generation is
tractable and on-mission; AI **image/audio** generation remains unbuilt and must stay unclaimed.

### 5.2 AlarmKit arrival alarm — strong fit

Countdown-based scheduling maps directly onto "**alarm at the countdown's arrival date**." iOS 26's
AlarmKit gives a true ring-until-dismissed alarm (through Silent/Focus, full-screen + Dynamic Island) —
the same capability as the built-in Clock. iOS 26+, native, **no Android parity yet** (Android has its
own full-screen-intent alarm path with separate Play-policy constraints).
This supersedes the old "audible alarm is structurally impossible on iOS" assumption — see the corrected
record in `crossed-ai-workspace/MEMORY.md` (§"Platform-capability corrections"); the impossibility was
true only **pre-iOS-26**.

### 5.3 Live Activity countdown — good conceptual fit

Surface **days-remaining on the Lock Screen / Dynamic Island** as a Live Activity — a countdown is
inherently "live." Moderate effort. iOS 26+, native.

### 5.4 Liquid Glass appearance check — VERIFICATION, not a feature

iOS 26's system "Liquid Glass" redesign is automatic for SwiftUI apps but **NOT for Flutter**. Crossed
must be **checked on an iOS 26 device** to confirm the countdown, paywall, and widget still look
intentional against the new system aesthetic — not broken or dated. **Low priority, no new code
expected** — a look-and-confirm pass; it only becomes work if something reads as broken.
