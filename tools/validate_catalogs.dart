// Catalog validation guard for crossed-content.
//
// Runs the app's ACTUAL parser-validation logic (NOT a hand-written schema) against
// the four remote catalogs the shipped apps fetch. Every function below is ported
// VERBATIM from crossed-ai-workspace/dsl/edit.dart:
//   - validateVerses      <- 1.0.0 commit d64669e  (verses.json; 2.0.0 identical)
//   - validateScenes      <- 1.0.0 commit d64669e  (scenes.json;  2.0.0 identical)
//   - validateBackgrounds <- 2.0.0 main            (backgrounds.json; 2.0.0-only file)
//   - validateSoundsCatalog <- 2.0.0 main          (sounds.json;      2.0.0-only file)
//
// WHY 1.0.0 for verses/scenes: 1.0.0 is awaiting store approval and will briefly be
// the entire install base; it fetches verses.json + scenes.json. Those two validators
// are byte-identical across 1.0.0 and 2.0.0, so passing here means BOTH versions accept
// the file. backgrounds.json/sounds.json exist only for 2.0.0.
//
// CONTRACT MIRRORED: each validator returns false (whole file rejected) on the FIRST
// malformed entry — exactly the app's all-or-nothing behavior. In the app a false
// result silently falls back to bundled/cache; here we FAIL the CI run so the bad file
// never reaches main. Any file that fails => exit 1.
//
// The only faithful adaptation: the app's _hexColor/_bgHex return a dart:ui Color?;
// their callers use `== null` purely as a validity test. _isHex6 below reproduces that
// exact acceptance set (String, optional '#', 6 hex digits) without the Flutter dep.
//
// Run: dart run tools/validate_catalogs.dart   (from repo root)

import 'dart:convert';
import 'dart:io';

// ---- helpers (verbatim predicates from edit.dart) ----
bool _nonEmptyStr(dynamic v) => v is String && v.trim().isNotEmpty; // _nonEmptyStr / _neStr
const Set<String> _kValidMotions = <String>{'gradient', 'kenBurns'};

/// Validity predicate of the app's _hexColor/_bgHex (which return Color?; callers only
/// test `== null`). Same acceptance: a String, optional leading '#', exactly 6 hex digits.
bool _isHex6(dynamic v) {
  if (v is! String) return false;
  var h = v.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length != 6) return false;
  return int.tryParse(h, radix: 16) != null;
}

// ---- validateVerses (1.0.0 d64669e, verbatim) ----
bool validateVerses(dynamic json) {
  if (json is! Map) return false;
  final verses = json['verses'];
  if (verses is! List || verses.isEmpty) return false;
  for (final v in verses) {
    if (v is! Map) return false;
    if (!_nonEmptyStr(v['text']) || !_nonEmptyStr(v['reference'])) {
      return false;
    }
  }
  return true;
}

// ---- validateScenes (1.0.0 d64669e, verbatim; _hexColor(c)==null -> !_isHex6(c)) ----
bool validateScenes(dynamic json) {
  if (json is! Map) return false;
  final scenes = json['scenes'];
  if (scenes is! List || scenes.isEmpty) return false;
  for (final s in scenes) {
    if (s is! Map) return false;
    if (!_nonEmptyStr(s['id']) || !_nonEmptyStr(s['label'])) return false;
    final motion = s['motion'];
    if (motion is! String || !_kValidMotions.contains(motion)) return false;
    if (motion == 'kenBurns' && !_nonEmptyStr(s['imageUrl'])) return false;
    if (motion == 'gradient') {
      final g = s['gradient'];
      if (g is! List || g.length < 2) return false;
      for (final c in g) {
        if (!_isHex6(c)) return false;
      }
    }
  }
  return true;
}

// ---- validateBackgrounds (2.0.0 main, verbatim; _bgHex(c)==null -> !_isHex6(c)) ----
bool validateBackgrounds(dynamic json) {
  if (json is! Map) return false;
  final items = json['backgrounds'];
  if (items is! List || items.isEmpty) return false;
  for (final b in items) {
    if (b is! Map) return false;
    if (!_nonEmptyStr(b['id']) ||
        !_nonEmptyStr(b['label']) ||
        !_nonEmptyStr(b['category'])) {
      return false;
    }
    final kind = b['kind'];
    if (kind is! String || (kind != 'image' && kind != 'gradient')) return false;
    if (kind == 'image' && !_nonEmptyStr(b['imageUrl'])) return false;
    if (kind == 'gradient') {
      final g = b['gradient'];
      if (g is! List || g.length < 2) return false;
      for (final c in g) {
        if (!_isHex6(c)) return false;
      }
    }
  }
  return true;
}

// ---- validateSoundsCatalog (2.0.0 main, verbatim) ----
bool validateSoundsCatalog(dynamic json) {
  if (json is! Map) return false;
  final items = json['sounds'];
  if (items is! List || items.isEmpty) return false;
  for (final s in items) {
    if (s is! Map) return false;
    if (!_nonEmptyStr(s['id']) ||
        !_nonEmptyStr(s['label']) ||
        !_nonEmptyStr(s['category'])) {
      return false;
    }
    if (!_nonEmptyStr(s['audioUrl'])) return false;
  }
  return true;
}

typedef Validator = bool Function(dynamic);

void main() {
  final checks = <String, Validator>{
    'verses.json': validateVerses, // 1.0.0 + 2.0.0
    'scenes.json': validateScenes, // 1.0.0 + 2.0.0
    'backgrounds.json': validateBackgrounds, // 2.0.0
    'sounds.json': validateSoundsCatalog, // 2.0.0
  };

  var failed = false;
  print('== crossed-content catalog validation (app parser logic) ==');
  checks.forEach((file, validate) {
    final f = File(file);
    if (!f.existsSync()) {
      print('  FAIL  $file — missing');
      failed = true;
      return;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(f.readAsStringSync());
    } catch (e) {
      print('  FAIL  $file — not valid JSON: $e');
      failed = true;
      return;
    }
    if (validate(decoded)) {
      // Report the entry count so a passing run is legible.
      final n = (decoded is Map && decoded.values.whereType<List>().isNotEmpty)
          ? decoded.values.whereType<List>().first.length
          : '?';
      print('  PASS  $file ($n entries)');
    } else {
      print('  FAIL  $file — REJECTED by the app parser (one bad entry rejects the whole file)');
      failed = true;
    }
  });

  if (failed) {
    print('\nRESULT: FAIL — a catalog would be discarded by the app. Do NOT merge/push to main.');
    exit(1);
  }
  print('\nRESULT: PASS — all catalogs accepted by the app parser logic.');
}
