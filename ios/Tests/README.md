# Scroll motion checks

From the repository root, run:

```sh
bash ios/Tests/run-chrome-checks.sh
```

This compiles the actual motion controller into a temporary executable and checks fractional drags, immediate reversal, header/article continuity, top and bottom bounce, short and empty feeds, invalid geometry, controller suspension/reset, and 10,000 sampled positions. It requires the local Xcode Swift toolchain and adds no package dependencies.

For native verification, check slow drags and fast flicks in both directions, reversing before the header is fully hidden, bounce at both ends, single-topic feeds, switching collections, horizontal topic scrolling, menu swipes, paper navigation, and pull-to-refresh. The scroll viewport and content dimensions must remain constant during gestures; content changes are a separate rebase event.

Optional simulator launch arguments:

- `--scroll-diagnostics`: collect up to 12,000 native geometry samples in the app's cache as `reader-chrome-diagnostics.json`, written after scrolling becomes idle. Includes native offset, maximum offset, chrome distance, viewport and content height. Normal launches do not collect diagnostics.
- `--skip-intro`: skip the existing brand entrance while testing repeated launches.

These flags add no visible product controls. Geometry samples verify motion and layout stability; they do not measure frame rate or CPU cost.

Brand colour-flow checks: `bash ios/Tests/run-brand-checks.sh`. These compile the real palette/flow model and verify shader channel packing, preservation of interrupted fronts, safe compaction after completion, and settled input for Reduce Motion. Native recordings are used to check the spatial pigment front, single-orb silhouette and monochrome topic controls.
