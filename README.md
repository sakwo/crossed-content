# crossed-content

Remote content catalogs served to the shipped Crossed apps via
`raw.githubusercontent.com/sakwo/crossed-content/refs/heads/main/<file>.json`:
`verses.json`, `scenes.json`, `backgrounds.json`, `sounds.json` (+ `release.json`, `broadcast.json`).

## ⚠️ Editing these files is PUBLICATION — read before you touch anything

- **A push to `main` is a live release.** The apps fetch these URLs directly; the raw CDN serves your
  committed bytes within minutes. There is no staging.
- **One malformed entry discards the WHOLE file.** Every catalog parser is all-or-nothing — a single
  bad entry makes the app reject the entire catalog and fall back to its bundled/cached copy. On the
  **1.0.0** app that fallback is the **wrong Bible translation (WEB, not KJV)**, not just stale data.
- **Never rename a verse `tag` string.** Tags are a persisted API — premium users' saved topic choices
  store the raw tag, so renaming one silently drops those verses from their pool with no error. Add new
  tags; never rename or repurpose existing ones. Keep `"ALL"` on any verse that should show by default.
- **A new FREE background must be added to BOTH `scenes.json` AND `backgrounds.json`.** They are read by
  different app paths (scenes.json → 1.0.0 + 2.0.0-free; backgrounds.json → 2.0.0-premium). Adding to
  only one makes it appear for only one audience.
- **The `validate-catalogs` CI check is an ALARM, not a gate** — it reports *after* the push; it does
  not block serving. Run it locally first: `dart run tools/validate_catalogs.dart`.

Full behavior + edit rules: `crossed-ai-workspace/docs/specs/catalog-constraints.md`.
Known gaps in the guard: [`DEFERRED.md`](DEFERRED.md).
