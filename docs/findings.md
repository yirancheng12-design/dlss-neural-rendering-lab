# Findings and evidence timeline

[Home](../README.md)

These are English summaries of historical records, not new runtime tests. Configuration ON, a loaded DLL, a valid signature and a successful render are distinct observations. Short runs cannot establish universal stability or the sole cause of a crash.

## Cyberpunk 2077: preserve the sequence

1. **Oct 16, removal after repeated crashes.** The [retired-state JSON](../01_Cyberpunk2077/Data_JSON/Cyberpunk2077_NR_RETIRED_STATE.json) records removal and a compatibility block. The [removal report](../01_Cyberpunk2077/Reports/Cyberpunk2077_NR_REMOVED_STABILITY_REPORT.txt) describes a five-minute original-game observation, an unsuccessful final screenshot and later manual confirmation of working picture/controls. This is an earlier state, not the last experiment.
2. **Oct 16, later selected-profile trials.** [No-FG profile](../01_Cyberpunk2077/Data_JSON/Cyberpunk2077_NR_NO_FG_VERIFIED_PROFILE.json) and [2×-FG profile](../01_Cyberpunk2077/Data_JSON/Cyberpunk2077_NR_FG2_VERIFIED_PROFILE.json) record ten-minute observations. The latter reports zero new crash reports, blocks 3×/4× and marks long-term stability `UNKNOWN`. Read the [FG2 report](../01_Cyberpunk2077/Reports/Cyberpunk2077_NR_FG2_FINAL_REPORT.txt) alongside earlier failures.
3. **Oct 17, controller v2.** [verification.json](../01_Cyberpunk2077/Cyberpunk2077_NR_Controller_v2/verification.json) records 19.4 minutes at 67% scale, one pass, native 2× FG, fresh runtime-log observations and zero new crash reports. Average FPS and 1% low are `UNKNOWN`; higher precision/passes were not stability-tested in this trial. See the [controller report](../01_Cyberpunk2077/Cyberpunk2077_NR_Controller_v2/REPORT.txt).
4. **Oct 17, photo comparison.** [Capture notes](../01_Cyberpunk2077/Cyberpunk2077_NR100_3Pass_COMPARE_20261017/README.txt) describe OFF versus 100% scale / three-pass captures, then restoration to 67% / one pass. Full-resolution model input does not make resized JPEGs full-resolution evidence. This photo session does not extend the earlier gameplay stability result to three passes.

## Historical benchmark records

The [OFF record](../01_Cyberpunk2077/Data_JSON/Cyberpunk2077_OFF_Quality_benchmark.json) reports average 116.3 FPS; the [ON record](../01_Cyberpunk2077/Data_JSON/Cyberpunk2077_ON_Quality_benchmark.json) reports 99.47 FPS, at 2560×1600, DLSS Quality, `MFGSetting: 3X`. These are single built-in benchmark observations, not repeated controlled trials. Neither measures 1% low. This differs from the later 2× profile; do not use it to promote 3× compatibility or an FPS gain.

`python tools/archive.py summary` prints these values separately from the later gameplay observation.

## Wuthering Waves

The [read-only audit](../02_WutheringWaves/Data_JSON/WutheringWaves-readonly-audit.json) and [Chinese report](../02_WutheringWaves/Reports/WutheringWaves-DLSS5-audit-zh.txt) preserve the machine-specific investigation. The [85% configuration change](../02_WutheringWaves/Data_JSON/WutheringWaves_NR_Quality85.json) records before/after hashes, one pass and cache disabled, but explicitly says `RuntimeTest: NOT_RUN`. A saved setting is not a successful runtime or quality measurement.

## Better future evidence

Repeat matched-scene runs with exact versions; publish frame-time data and measurement methods; distinguish rendered and generated display FPS; keep failures and restoration records. Follow [the contribution guide](../CONTRIBUTING.md). The NR label alone supports no latency-reduction claim.
