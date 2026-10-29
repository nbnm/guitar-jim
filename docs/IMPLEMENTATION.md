# Implementation status

29 October 2026. Version 0.1.6. Native macOS prototype with an arcade practice surface, local audio analysis and recording. The PRD's release accuracy and latency targets have not been established.

## Current experience

The practice screen uses five chord lanes, descending strum gems, a strike line, current/next chords, visual count-in, section loops and several anchored lyric lines. Color is paired with chord labels and direction symbols. Large lyrics and reduced motion are supported. The metronome and four-beat count-in are audible by default, following the user’s later request. Count-in beeps accompany animated numbers, an expanding pulse ring and sound bars, followed by a distinct GO chime. Practice beats have a first-beat accent. Speaker mute and volume controls are visible, with a test countdown in Audio setup. There is no live microphone monitoring or synthetic success sound. Recording playback occurs only when the player explicitly requests it.

Five original eight-bar songs cover progressively harder strumming:

| Level | Song | Practice tempo | Focus |
| --- | --- | --- | --- |
| 1 | First Light | 65 BPM | Two shapes, steady quarter-note downstrokes |
| 2 | Open Road | 80 BPM | Eighth-note pickups |
| 3 | A little closer | 80 BPM | Folk pattern with a rest |
| 4 | Paper Satellites | 100 BPM | Syncopation and minor chord changes |
| 5 | Night Runner | 120 BPM | Continuous eighths and mid-bar changes |

The user's requested **With or Without You — U2** is an additional chord-only study. G–D–Em–C shapes with capo 7 sound D–A–Bm–G. It contains an editable eight-bar practice loop, not a complete transcription or timed copy of the recording. The default practice tempo is 80 BPM, separate from the 110 BPM reference. The player must confirm capo and suggested timing before scored practice. No third-party lyrics, melody, tablature, recording or artwork is bundled.

Sources are retained in the U2 arrangement: [official song identity](https://www.u2.com/products/with-or-without-you), [Andy Guitar's four-chord lesson](https://www.andyguitar.co.uk/videos/u2-with-or-without-you), and [Hooktheory's community tempo analysis](https://www.hooktheory.com/theorytab/view/u2/with-or-without-you). Licensed or permitted user-supplied lyrics can be added in the editor.

Existing arrangements and edits are preserved when catalog entries are seeded. Saved imported charts retain their review state and source permissions.

Version 0.1.4 added the first ten [popular-song studies](SONG_CATALOG.md): two Johnny Cash, three Coldplay, and five by Vance Joy, Noah Kahan, Benson Boone, Billie Eilish and Shaboozey. They are authored eight-bar, no-capo chord-only exercises with fixed practice tempos and linked reference notes, not complete song transcriptions. That release introduced a 16-song starter library and title/artist search. Single-section songs select the whole first section by default, so eight-bar studies play their complete loop.

Version 0.1.5 adds Photograph, Shape of You and Bad Habits by Ed Sheeran, plus Radioactive, Demons and Thunder by Imagine Dragons. The starter library now has 22 songs. These six studies use supported open shapes with no capo and separate practice tempos. Their linked source notes identify transposition, simplified voicings, omitted sections and authored strumming. Existing charts, including the user's reviewed no-capo U2 version, remain unchanged during seeding.

Native checks on 0.1.5 confirmed all six additions in the 22-song library, exactly three results for each artist search, and Radioactive opening ready at 90 BPM with no capo, eighth-note pickups and the chord table visible. The app was left stopped on that study, with looping off. Screenshots are saved as `ed-sheeran-library.jpg`, `imagine-dragons-library.jpg` and `radioactive-practice.jpg` in `docs/assets/`.

Version 0.1.6 addresses the pre-publication review findings. Stop, replay and quit wait for the same recording finalization; unreadable saved charts survive catalog seeding; early-strum chord estimates wait for their timing assignment; partial attempts replay only their recorded duration; storage usage reads actual audio file sizes; and moving a chord change keeps beats ordered and unique. See [review notes](REVIEW.md) for the checks and remaining limits.

The practice screen has a persistent eight-subdivision strumming strip alongside the lyrics/chord chart. It shows down/up/rest, identifies matching presets or a custom pattern, and highlights the current subdivision. The optional table below the stage shows chord-change anchors and strums for every bar, highlights the same subdivision, and follows the current bar. Its visibility preference persists. The arrangement editor offers eight presets globally or per bar, plus manual slot cycling. Presets preserve harmony, lyrics and event identity; Save commits draft edits and Cancel discards them. Reduced motion retains the positional beat indicator without adding pulse/scroll animations. On shorter windows, the practice content scrolls to preserve controls.

Opening the pattern editor pauses transport and initializes the preset from the current chart. It uses the current practice tempo when editing the selected song, so slowing a song to 60 BPM does not reopen its editor at the factory tempo. This was checked natively on Ring of Fire; the app was left paused at 60 BPM with the pattern and table visible.

Chord-only practice and library subtitles derive their chord shapes, capo and sounding chords from the current arrangement. Changing the capo no longer leaves the original catalog subtitle on screen. For the requested live U2 check, the user's saved chart was reviewed and transposed to G–D–Em–C with no capo, at 80 BPM. Live capture remains pending reconnection of the Fifine USB microphone; no recognition or timing result is claimed for this take yet.

## Microphone capture

The original AVAudioEngine prototype was not delivering input on the user's USB/Bluetooth route. A subsequent test exposed a 48 kHz USB input versus 44.1 kHz Bluetooth output configuration mismatch. Capture now uses a dedicated input-only Core Audio HAL unit following [Apple TN2091](https://developer.apple.com/library/archive/technotes/tn2091/_index.html). Output is explicitly disabled, and the actual selected input's sample rate and channels are used. No system default device or volume setting is changed.

A C11 single-producer/single-consumer ring publishes preallocated PCM buffers with release/acquire memory ordering. The audio callback renders and copies audio, then signals a worker. It does no FFT, file writing or UI work and does not wait on a mutex. A full buffer pool or input failure stops capture visibly rather than dropping samples silently.

The worker writes approximately two-second CAF chunks and atomic manifests. Files exist before capture starts. Setup, count-in and paused practice remain recorded. The menu bar and app footer show capture state. Mic stop, replay, quit, sleep, device loss and recording faults finalize the saved portion. Device choice is explicit, initially matching the system's default input; the app never silently changes microphones.

Finalized chunks retain sample counts, sample rate and host-time anchors. Launch recovery preserves completed chunks. Crash, disk-full and long-session fault testing still need a dedicated test matrix. Current segmented playback can have seams; WAV export concatenates the continuous sample sequence without those playback transitions.

## Local feedback

`GuitarPracticeCore` owns the arrangement schema, readiness checks, chart parsing, musical-time matcher, spectral analysis and model adapter. UI and capture code are in `GuitarPractice`; Core Audio's input driver is isolated in `HALCaptureDriver`.

Chord estimates are derived from recorded PCM, without receiving the expected chord. A Hann-windowed Accelerate FFT extracts spectral peaks and a harmonic-weighted pitch-class profile. All 24 major/minor candidates are compared. Provisional gates require sufficient triad energy, separation from the next candidate and evidence for all three chord tones. Evidence strengths are not calibrated probabilities. The algorithm abstains for quiet, clipped, noisy, incomplete or ambiguous harmony.

An onset detector groups successive string attacks with a 95 ms refractory interval. A delayed harmonic window is attached to the original audio timestamp, and is truncated before a subsequent attack. The capture worker analyzes the strongest input channel to avoid stereo cancellation and reports the actual input level, sample rate and channel count.

Timing uses sample/host timestamps and the fixed practice clock, with the PRD's ±90 ms on-time and ±180 ms assignment windows capped by neighboring attack intervals. Each detected attack can satisfy only one expected attack. Slightly early chord changes are judged against the assigned target's chord, rather than the previous chord sounding at that instant. Extra strums do not produce chord matches. Quiet usable intervals can produce missed attacks; clipped/noisy buffers are excluded from timing's usable intervals.

The interface reports chord agreement, judged count and coverage separately from on-time rate and early/late/missed/extra counts. Harmonic uncertainty reduces coverage rather than creating a false mismatch. Timing is labelled **uncalibrated** until the player confirms a measured route offset. Input quality reports connection, sound level, silence, clipping and broadband noise; it does not claim to establish exact fingering, clean ringing of every string, or stroke direction.

Both chord feedback and timing are beta features. Synthetic fixtures establish specific code behaviors, not accuracy across real players and guitars. No production accuracy, coverage or latency claim follows from this implementation.

## Recording and diagnostics

Recordings preserve immutable arrangement snapshots, continuous chunks, markers, expected/detected attacks and chord/timing assessments. Replay can seek, loop a recorded attempt, rename, delete and export WAV. Playback first turns off and finalizes microphone capture. Audio and practice history are never sent to model services.

Two local command-line diagnostics are available:

```sh
swift Scripts/inspect-recording.swift "/path/to/session-directory"
swift run GuitarJimAudioCheck "/path/to/session-directory" --details
```

The first checks finalized file lengths against manifests, timestamp continuity and audio level. The second runs the same local onset/harmonic analyzer over saved PCM. Neither plays, transcribes, uploads or modifies audio. Diagnostic output can contain practice-derived information; keep it local. Raw recordings and generated diagnostics are not committed to this repository.

## Metronome and countdown

Version 0.1.3 changes the earlier silent guide to an audible metronome, as requested by the user. `MetronomeSchedule` computes every count-in and practice beat from one timeline. `MetronomePlayer` queues original synthesized click buffers on an output-only AVAudioEngine using sample positions, rather than triggering sound from UI timer callbacks. Fractional sample rounding is applied to each absolute beat, avoiding accumulated rounding error.

The predicted audible epoch includes the output player’s reported presentation latency. Countdown digits, a pulsing ring, waveform bars and the GO cue use that same epoch. Reported latency is a device estimate, not a replacement for measured route calibration. Reduced-motion mode keeps the numbers and beat indicators without pulse scaling. Mute/volume changes do not restart the practice clock. Pause, mic stop, replay, sleep, section restart and app exit stop queued sound. An output-engine failure pauses practice and asks the player to resume after checking the route.

The output engine never receives microphone PCM. The input-only HAL recorder never receives click buffers, so the app does not digitally mix the metronome into recordings. Speakers can still be picked up acoustically by the microphone; headphones are recommended while scoring. The app does not alter the system sound volume or default device.

Tests verify 4–3–2–1 then GO, bar accents, sample timing at 44.1/48 kHz, synthesized signal amplitude and endpoints, and actual offline AVAudioEngine rendering at the scheduled beats. Stopping the player during an active GO sound yields silence on the next rendered buffer.

## Light Element

Model access remains deferred until the endpoint, token, model identifier and protocol are supplied. Settings store the token in macOS Keychain and non-secret configuration in UserDefaults. The provisional OpenAI-compatible adapter uses the complete configured URL verbatim, sends request text only, and accepts strictly decoded chord-only suggestions. No source retrieval, licensed catalog access or full lyric generation is claimed. Local practice requires no credentials or network connection.

## Verification

- `./Scripts/test.sh`: **46 tests passed** in eight suites on Apple Silicon with Swift 6.3.3; parameterized tests additionally exercise eight individual chord shapes and four explicit confusion cases. The app bundle builds and passes ad hoc signature verification.
- Automated suite checks readiness, import limits and untrusted numeric fields, capo transposition, five distinct difficulty patterns, U2's chord-only review state, one-to-one attack assignment, rhythm verdicts, fast-tempo caps and zero denominators.
- Audio fixtures cover all eight supported chord shapes; explicit C/Am and E/Em confusions; concert-pitch comparison; silence, clipping, broadband noise, single notes and incomplete chords; grouped strum timing; early chord-change assignment; and exclusion of extra strums from chord matches.
- Storage/audio integration checks immutable snapshots, recovery, permission gates, storage failure preservation, full/wrapped capture buffers and sample-exact concatenation of finalized test chunks into WAV.
- The Fifine USB microphone delivered **48,000 Hz, two-channel** audio. A 63.65-second capture saved 3,055,104 frames in 32 chunks. A subsequent live guitar check saved **3,969,536 frames over 82.70 seconds in 42 chunks**. All finalized file lengths matched their manifest sample counts; the maximum difference between adjacent chunk host-time anchors was **0.043 ms** in the latter session.
- Live input was nonzero, the level display advanced, the mic remained active while practice was paused, and stopping saved and disabled capture. The user's live guitar sample was unlabeled because its chord order was not remembered. Its mixed estimates are therefore **not an accuracy benchmark**, and recognition thresholds were not tuned against assumed labels.
- Native UI checks cover count-in, keyboard pause, song selection, multiple lyric lines, arrangement review and microphone state. Version 0.1.3 checks the countdown animation, sound preview, mute/unmute and volume controls; the user subsequently confirmed hearing the clicks. Version 0.1.4 checks the 16-song catalog, Coldplay artist search, global/per-bar presets, custom upstroke editing, cancel behavior and table show/hide. During live metronome playback on Viva la Vida, the strip and table both highlighted bar 5, beat 2 (a rest), with the table following the current bar. The bounded eight-bar take ended automatically. These checks used no microphone capture and do not establish real-guitar recognition accuracy. Visual previews are saved under `docs/assets/`.
- Automated coverage checks missing-event rests, subdivision boundaries, mid-bar chord labels, preset timing targets, edits spanning a section boundary, preservation of lyrics/chords and the no-capo U2 chart, 16 distinct source-linked studies, exactly three each by Ed Sheeran and Imagine Dragons, serialization and duplicate-free catalog reload with 22 songs.
- Review regressions cover shared stop/quit finalization, unreadable built-in chart preservation, delayed early-strum chord feedback, partial-attempt replay and legacy decoding, actual stereo recording file sizes, and ordered, collision-free chord changes.

Remaining release work: consented annotated real-guitar evaluation, confidence calibration and interference testing; automatic route calibration/tuner; measured end-to-end feedback latency and long-session drift; forced-crash/device-loss/disk-full tests; gapless replay and M4A export; and permitted content-provider integration.
