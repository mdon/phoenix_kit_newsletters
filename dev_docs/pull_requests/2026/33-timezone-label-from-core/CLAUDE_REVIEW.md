# Code Review: PR #33 — Label timezones with core's label, drop the copied picker list

**Reviewed:** 2026-09-06
**Reviewer:** Claude (claude-opus-5)
**PR:** https://github.com/BeamLabEU/phoenix_kit_newsletters/pull/33
**Author:** Max Don (mdon)
**Head SHA:** 3d6fc141c8942e1cab9ef89e2229e2416a05fdf0
**Status:** Merged (1714faa)

## Summary

`Web.Timezone` carried a private copy of core's old timezone picker list purely
to label the viewer's zone without paying for `Settings.get_setting_options/0`
(which queries `Roles.list_roles/0`). Core grew a cheap dedicated accessor —
`Settings.get_timezone_label/1` → `Utils.TimeZone.label/1` — so the copy is
deleted and the label comes from core again.

The copy had gone wrong in two ways the PR describes accurately: it labelled a
legacy `"2"` with cities that sit on UTC+2 only half the year, and it had no
entry at all for an IANA id, which is what every account holds once it has
touched core's picker since 2.13.9 — so `Europe/Warsaw` fell through to a raw
fallback.

A follow-up commit in the same PR replaced `user_tz_offset/1` with `viewer_tz/1`:
it reads `:user_timezone` off the assigned user itself instead of handing a
possibly-partial map to core's resolver (which does `user.user_timezone` and so
raises `KeyError` on a map without the column — the old `rescue` then answered
`"0"`, UTC, rather than the site's zone). The `tz_offset` assigns/params across
the three broadcast pages were renamed `tz`, since the value has been a zone and
not an offset since core 2.13.9.

## Verification performed

Claims in the PR description were checked against core (`deps/phoenix_kit`,
2.15.1), not taken on trust:

- `Settings.get_timezone_label/1` exists and delegates to
  `Utils.TimeZone.label/1`; it resolves against `timezone_options/0` only and
  never builds `get_setting_options/0`, so the DB-cost argument the deleted copy
  existed for is genuinely satisfied — no `Roles.list_roles/0` per call.
- **Version floor is safe.** The pin is `~> 2.0` and `test/core_pin_conformance_test.exs`
  forbids narrowing it, so a newly-called core function has to exist in *every*
  2.x. `Settings.timezone_options/0` and `get_timezone_label/1` landed in core
  **1.7.207**, well below the floor. No `UndefinedFunctionError` on an old-but-
  admitted core.
- `Utils.Date.get_user_timezone/1` does `user.user_timezone` — it does raise on a
  map without the column, so the rescue the PR removed was real and its `"0"`
  answer was wrong for a site with a non-UTC `time_zone`.
- `phoenix_kit_current_user` is genuinely assigned on these pages:
  `mount_phoenix_kit_current_scope/3` calls `mount_phoenix_kit_current_user/2`,
  and the admin `live_session` runs `:phoenix_kit_ensure_admin`. Profile-first
  resolution is not dead code.
- `TimeZone.shift/2` and `from_wall/2` take the IANA branch only for values in
  core's curated `@identifiers`; `Europe/Tallinn` and `Europe/Warsaw` are both in
  it, so the DST test added by the PR exercises the real path rather than the
  silent offset fallback.
- `parse_offset/1` strips a leading `+`, so a `"+5"` row (core's own docstring
  example) still resolves — the rename does not strand it.
- No remaining `tz_offset` / `user_tz_offset` reference anywhere in `lib/` or
  `test/`; the rename is complete.

## Issues Found

### 1. [NITPICK] Test comment describes the pre-IANA world the PR is removing — FIXED
**File:** `test/phoenix_kit/newsletters/web/timezone_test.exs` lines 18–21
**Confidence:** 95/100

The surviving comment on the profile-timezone test said the `"3"` fixture is
"unsigned, matching how both the profile dropdown (reusing core's
`Settings.get_setting_options()["time_zone"]` values, e.g. "3") and the 'use
browser timezone' one-click button actually store it."

Neither half holds any more, and the PR's own commit message says so: core's
picker is `TimeZone.options/0`, whose values are IANA representatives
(`Europe/Warsaw`), and `use_browser_timezone` in
`PhoenixKitWeb.Live.Components.UserSettings` writes the detected identifier
explicitly ("Writes the IANA identifier, never the offset"). Left as-is, the
comment tells the next reader that the legacy fixture is the *current* shape, so
the case that actually matters now looks covered when it is not.

**Fix applied:** comment rewritten to name `"3"` as the legacy row it is, and the
test extended to assert `viewer_tz/1` also returns an IANA id unchanged —
locking in the value shape every account holds today.

### 2. [OBSERVATION] A blank site `time_zone` would travel on as a blank zone — deliberately not fixed
**File:** `lib/phoenix_kit/newsletters/web/timezone.ex` lines 39–53
**Confidence:** 90/100

`viewer_tz/1` normalizes a blank *user* value to the site setting, but returns
the site setting as-is. Were that setting ever `""`, core reads a blank zone as
`"Use System Default"` for the label and as *no shift at all* for the value — the
pages would render UTC times under a caption that never says UTC.

I wrote the guard and the test, then removed both: the state is unreachable
through core's API. `time_zone` is not in `Setting.optional_settings/0`, so
`validate_setting_value/1` applies `validate_length(:value, min: 1)` and
`Settings.update_setting("time_zone", "")` is rejected outright — verified by
running it (the setting kept its prior value). Guarding it would add a branch and
a test documenting a state only a direct `UPDATE` can produce.

### 3. [OBSERVATION] `Timezone.user_tz_offset/1` → `viewer_tz/1` is a public rename
**File:** `lib/phoenix_kit/newsletters/web/timezone.ex`
**Confidence:** 100/100

`Web.Timezone` carries a `@moduledoc`, so it ships in the published docs and the
rename is visible to anyone who reached for it. Nothing in this repo, its README
or its guides refers to the old name (only prior review docs, correctly frozen),
and the module is a LiveView-internal helper, so a deprecation shim would be
noise. Recorded in `CHANGELOG.md` for 0.2.2 instead.

### 4. [OBSERVATION] `tz` / `tz_label` are a snapshot taken in `handle_params/3`
**File:** `broadcasts.ex:58`, `broadcast_details.ex:82`, `broadcast_editor.ex:581`
**Confidence:** 85/100

Both assigns are resolved once per navigation. A viewer who changes their profile
timezone in another tab keeps the old zone — caption and rendered times — until
they navigate. That is the deliberate trade from PR #19's review: resolving per
render would restore the uncached settings read on every render, and doing it in
`mount/3` would double it (mount runs twice). Core's mid-session
`:phoenix_kit_scope_roles_updated` refresh reloads the user, but it fires on a
*roles* change only, so it does not narrow the window either way. Not worth a fix.

### 5. [OBSERVATION] Core's label reads oddly inside "Times shown in %{tz}"
**File:** `broadcasts.html.heex:23`, `broadcast_details.html.heex:75,225`, `broadcast_editor.ex:597`
**Confidence:** 80/100

`TimeZone.label/1` appends `" — summer time"` from a *static* group property
(`group.dst`), not from whether DST is in effect, so in January the caption reads
"Times shown in (UTC+02:00) Athens, Helsinki, Tallinn, Riga — summer time". The
schedule preview nests it in its own parentheses: "Sends at 14:30 ((UTC+02:00)
Warsaw, …) · 12:30 UTC".

Both are core's string used verbatim, which is the entire point of the PR;
trimming it here would recreate the local copy that was just deleted. If it
bothers anyone, the fix belongs in core (a short-label accessor), not here.

## What Was Done Well

- The right instinct, executed: a local mirror of someone else's list is a
  liability the moment the upstream list changes shape, and this one had already
  silently drifted past a data-model change (offsets → IANA ids). Deleting it
  rather than re-syncing it is the durable fix.
- The follow-up commit fixed the *real* bug hiding behind a `rescue`: a bare
  `rescue _ -> "0"` had been converting "this user map lacks the column" into
  "this site is on UTC". Replacing a catch-all rescue with an explicit read is
  the correct direction.
- The rename `tz_offset` → `tz` is not cosmetic — the value stopped being an
  offset at core 2.13.9, and a name that lies about its type is how the
  `Float.parse`-returns-0 class of bug spreads. Carried through assigns, params,
  templates and tests with no leftovers.
- Tests were extended where the behaviour changed, not just renamed: the DST case
  (`Europe/Tallinn` in January vs July) actually distinguishes the per-instant
  helper from the old fixed-offset arithmetic, and the partial-map/blank-value
  test pins the exact regression the follow-up commit fixed.
- Docs corrected alongside the code: the moduledoc's "a fixed numeric offset, not
  a real tz database" caveat was untrue once the conversions went through core's
  per-instant helpers, and it was removed rather than left to mislead.

## Verdict

**Approved with fixes** — the change is correct, well-motivated, and verified
against core rather than against its own description. One stale comment in the
test file (fixed here, with an IANA-value assertion added); everything else worth
saying is an observation, not a defect. Gate is clean: `mix precommit` (format,
`compile --warnings-as-errors`, `credo --strict`, dialyzer) passes and all 310
tests pass against a live test database.
