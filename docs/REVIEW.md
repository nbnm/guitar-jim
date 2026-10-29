# Pre-publication review

29 October 2026. Version 0.1.6, build 7.

The initial implementation was reviewed before its first push to `main`. The review covered recording lifecycle, local data preservation, chord and rhythm feedback, replay, chart editing, build scripts, repository hygiene and documentation. A Codex code review of the initial commit (`3a97866`) was followed by targeted fixes and a second review of those changes.

The follow-up review found no actionable regressions in the changes, including the new files. Tests and bundle verification were run separately from the review's read-only environment.

## Findings addressed

| Area | Before | After | Why |
| --- | --- | --- | --- |
| Recording finalization | Quit could exit after capture stopped but before its save finished. | Stop, replay and quit join the same pending finalization task; the interface shows saving progress. | Preserve the recording tail and final manifest. |
| Saved arrangements | Seeding the catalog could replace an unreadable saved built-in chart. | Existing chart files are preserved even when decoding fails. | Keep damaged or newer-format data available for recovery. |
| Early strums | A harmonic result arriving before its timing window settled could remain unassigned. | Estimates wait for a settled attack assignment before producing chord feedback. | Judge early chord changes against the assigned target. |
| Attempt replay | Paused attempts used the nominal full passage duration. | New attempts save their actual duration; older manifests retain the legacy fallback. | Keep replay loops within the recorded attempt. |
| Storage display | A mono frame-size assumption undercounted stereo audio. | Cached usage sums actual finalized audio file sizes. | Report stored audio accurately without repeated file queries during rendering. |
| Chord editing | Moving a change could leave beats unsorted or duplicated. | The picker rejects occupied beats, keeps the first change anchored, and sorts valid moves. | Keep editable charts ready for practice. |

Each behavior has a regression test. These checks exercise specific failure cases and do not establish real-guitar recognition accuracy.

## Validation

- `./Scripts/test.sh`: 46 tests pass in eight suites on Apple Silicon with Swift 6.3.3.
- `swift build -c release`: succeeds.
- The development app bundle is built and its ad hoc signature is verified before publication.
- `git diff --check`, shell syntax, property-list syntax, workflow YAML syntax and local Markdown asset links are checked.
- Screenshot file extensions match their actual JPEG or PNG formats. Builds, credentials, environment files and local practice recordings are excluded from Git.

The GitHub workflow runs tests, builds the app bundle and verifies its signature on pushes to `main` and pull requests. Its checkout action is pinned to a commit and uses read-only repository permissions.

## Remaining limits

This is a development prototype. Annotated real-guitar evaluation, timing calibration, long-session and fault testing, distribution signing and notarization remain outstanding. Light Element access awaits the endpoint, model identifier, token and protocol confirmation. See [implementation status](IMPLEMENTATION.md) for the full scope and validation history.
