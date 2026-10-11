# Native verification checkpoint — 2026-10-11

Scope: native Flutter (Android/iOS/Web), original Toss Product Sans, reference
packages pinned at 2.5.1. This is an **incomplete migration checkpoint**, not a
whole-library parity certificate.

## Strict completion gate

The user explicitly chose **100% pixel, API and Toss-host equivalence** on
2026-10-11. Native adaptations, disclosed differences and passing supported
subsets are not accepted as the final completion standard. No export has been
promoted to parity-verified, and the requested completion-gated commits/push
have not been performed.

This gate is not satisfied. Native Dart widgets/controllers do not reproduce
the original React DOM/ref/object-reflection/rendering contracts. No real Toss
host SDK, bridge specification or test application is available; injected test
doubles cannot establish equivalence to an unobserved implementation. Existing
pixel evidence also contains differences, including later-line baselines,
underlines and the 100-line Footer at 160% (3413.484375px native flow versus
3379.6875px source flow). Arbitrary span layouts and broader motion, compound,
Unicode/RTL and accessibility matrices remain incomplete. The ordinary
selectable emergency-wrap path has new scoped evidence below; it does not
establish those wider contracts.

These are explicit blockers, not tolerances or approved exceptions. More native
regression tests alone cannot certify the missing React and real-host contracts.
Changing the runtime architecture or substituting a different completion
standard requires a separate user decision; neither has been authorized.

## API coverage

| Export kind | Original | Partial native mapping | Pending |
| --- | ---: | ---: | ---: |
| Runtime components/providers | 108 | 108 | 0 |
| Hooks | 27 | 27 | 0 |
| Utilities | 22 | 22 | 0 |
| Types | 259 | 259 | 0 |
| Total top-level exports | 416 | 416 | 0 |

Recursive members add 622 entries, all with partial native mappings. Combined
ledger: 1,038 partial, zero unmapped entries. These include properties, wrapper metadata
and namespace types, not just visual components. No export is parity-verified.
The generator validates source names,
mapped file existence, native symbol presence and referenced test-file paths.
It does not infer success from an existing file: all mappings remain partial.
See `native-coverage.json` for individual outstanding work.

## Automated checks

- `flutter analyze`: clean at the final checkpoint.
- Root `flutter test`: Google OAuth launch regression test passed; no real OAuth
  credentials/browser authorization or Supabase data changes performed.
- Package `flutter test`: 514 tests passed. Includes all typography categories;
  control activation/disabled/loading; spinner hold/drag/disposal; field raw vs
  display values, formatting and IME; tab/segment keyboard and semantics;
  intrinsic-width dialog footer wrapping; modal dimmer/Escape lifecycle;
  async dialog duplicate/failure/replacement; toast timer/replace/drag/disposal;
  all 25 ListRow.Texts presets; list disabled/reflow behavior; host scopes,
  luminance, insets and scroll throttling. Additional families cover sheets,
  navigation, grids/board rows, date/wheel, sliders/rating, agreement/keypad,
  post/chart, code/pin input, overlay adapters and native type composition.
- `text_visual_geometry_test.dart`: 12 tests include 480 original-browser
  specimens (20 typography types × four weights × 100/160/200% × one/two lines).
  `reference/visual-geometry.json` contains only pinned-source DOM/canvas
  measurements, not Flutter-derived targets. The tests check complete specimen
  coverage, flow dimensions and the **first** baseline, not every painted line.
  Other assertions cover Footer xs metrics, parent inline strut/top-aligned
  arrows, Korean whole-word wrapping and custom/mixed font handling.
  `word_break_test.dart` separately checks preserved Text metadata.
  `list_footer_test.dart` adds a regression for source shadow
  percentage-width quantization before centering at 342px and 333.25px widths.
  Final package/root test and analyzer logs:
  `.context/tds-fallback-underline-{package,root}-{tests,analyze}.log`.
- New focused coverage: tooltip strong overshoot/reversal/reduced motion;
  WikiText bottom-anchor flip, Escape and keyboard-focus return; agreement
  immediate semantics with delayed color and timer disposal; fit-content menus;
  Top compound sizing; ListRow effect-controller lifecycle; video defaults,
  externally owned controllers, replacement and shared in-flight initialization.
- `list_assets_test.dart`: all 30 icon shape/size/variant combinations, fixed
  circle/square image frames, six fixed AssetText font sizes in light/dark,
  accessory positions/masking hierarchy, all 25 content presets' first-line
  alignment, FillIcon/Lottie geometry and four header icon-button sizes.
- Number/Alphabet keypad uses fixed 30px text, source 64px line plus 1px table
  cell padding per edge (66px row), and the original 20px back arrow SVG.
  Tests assert immediate press-start dispatch, no duplicate on release/cancel,
  native keyboard/semantics activation and fixed geometry at 200% scale.
- `bottom_cta_test.dart`: 13 tests cover nullable slots, min-width freezing and
  intrinsic flex growth, odd viewport gap, reverse wrapping, RTL stacked layout,
  50px hide/show interruption, scroll threshold/throttling/reset/disposal,
  all three delayed entrances, reduced motion, keyboard and measured spacers.
  Both full and no-background paths are exercised. Visibility exclusions from
  native focus and semantics are deliberate adaptations, not literal DOM parity.
- FontScaleLimit: independent Web/Mobile scopes, nested inheritance, every iOS
  category and Android boundaries. Typography limits leave host hooks unchanged.
- Bubble: source font strut union tested for 12/24/48/72px children and 100/200%
  text scaling. Original regular face metrics derive the 1.796875px offset,
  replacing the previous missing line-box height. Custom ancestor font, mixed
  spans and platform rasterization remain unverified.
- `compound_constants_test.dart`: all paragraphVariables leaves and ListRow's
  four Typography names match a new AST-extracted compound-constants.json.
  CTA wiggle keyframe positions (four linear 87.5ms segments) and Button's
  fractional text line-box height at 160% have separate regression tests.
- Portal tests cover nullable context shadowing, actual root/nested target
  migration, visibility/unmount cleanup and inherited theme/direction/media.
  Toast lifecycle tests cover route-independent retained state/timer, ownership,
  provider replacement, root teardown and controller reattachment. Host tests
  cover context overrides, web bypass, action/icon/lottie unions and exact
  nullable position offsets (bottom17, above-CTA81, Android top26/iOS top46).
- All 44 asset frame records and 176 accessory placements are checked, including
  structural clean-frame matching and masking without an accessory. All 15
  text-button inset/radius combinations are compared to AST-extracted literals.
- Paragraph tests cover rich text/asset/badge/link metric inheritance; badges
  retain 1.5em line boxes at four sizes and 100/160/200 percent. Dialog footer
  tests now distribute free space before freezing minimum widths, including RTL.
- `secure_keypad_test.dart`: six tests cover fixed text/row/control dimensions,
  all action dispatch at pointer down, keyboard/semantics deduplication, source
  blank insertion distribution, shared case layout, deferred reorder, disabled
  colors/SVG sizes, announcement delay/cleanup and unmount. OS protection is
  still an injected capability, not implemented by the widget.
- `menu_lifecycle_test.dart`: zero-gap and edge/RTL flipping, retained spring
  enter/exit/reversal, initial close-control focus, Tab cycle, click dismissal,
  controlled close rejection and accepted focus restoration. Actual React
  browser dispatch confirmed that the fixed backdrop closes on click, not down.
  `menu_geometry_test.dart` covers borders, gaps, blur, header and scroll fades.
- `skeleton_motion_test.dart`: initial opacity, 1s show/400ms hide, interruption
  without curve-switch jumps, click forwarding, invisible stagger, original
  600ms alternate easing and timer disposal.
- `tooltip_geometry_test.dart`: all 18 size/clip/side SVGs compared to original
  extracted paths/widths/offsets; 21 ratio/clamp cases; fractional text heights;
  static CSS radius/2 shadow conversion. No whole-tooltip parity claim.
- `list_row_motion_test.dart`: 18 tests cover 80/480ms blink delays, 200ms
  rise/slow return, content-only scaling, retained fade/re-entry, theme-specific
  gradients, repeat spacing without a final delay, repeated shine calls, stale
  blink timeout ordering, press blocking and the 30px iOS edge-touch exception.
  Actual React RAF sampling confirmed quadratic easing: source `easing`/`easings`
  fields are ignored by the bundled Framer runtime, which reads `ease`. Browser
  sampling confirms repeated shine calls with an unchanged animation target do
  not restart or change in-flight repeats. Ten added regressions cover live
  layout/theme behavior: light translation captures integer client dimensions
  while its gradient box follows current height; dark geometry remains relative
  to current dimensions. Theme flips remount the layer, restart its clock and
  consume the latest requested repeat count. A changed repeat request can
  invalidate the source memo after resize; if the light X target changes, its
  motion retargets from the current position and loops from that position.
  Height-only changes and same-count requests do not retarget. Simultaneous
  theme/size updates read the pre-commit size, including in a LayoutBuilder;
  pending blink timers and disposal retain their ordering.
  Three new regressions failed before the change (both theme directions and
  width/count retarget) and passed afterward. The browser probes are
  `tool/tds_source/browser-probes/list-row-{live,retarget}.js`, with traces in
  `.context/list-row-{live,retarget}-react.json`. These use the untouched pinned
  package and the fixture's `updateRow(patch)` / `rowEffect(effect, count)` API.
  The Flutter `?family=list-effects` gallery was also exercised through its four
  TDS TextButton controls: shine, a two-repeat request, resize and theme flip.
  Light/100% and dark/160% runs captured initial, resized and opposite-theme
  states in `.context/list-row-web-*.png`; all six images were inspected.
  Browser output contained only the headless CPU-rendering fallback warning,
  not application errors. These interaction smoke checks are not timed golden
  comparisons or GPU-rendering certification.
  These tests are not a full motion-parity claim.
- `list_row_blink_batch_test.dart`: 13 added regressions cover the fixed light
  blue500 radial gradient versus live themed dimmer, responsive geometry during
  entry/exit, synchronous shine/blink ordering and final shine repeat counts.
  Every accepted blink retains its wall-clock timeout, including overwritten
  blinks and multiple requests before a commit. Timer cleanup and controller
  replacement remain safe, including a request queued while its ancestor removes
  the row in the same build. Nine tests failed before the fix and all 13 now
  pass; the existing 18 ListRow motion tests also pass.
  The dimmer now exits from its current opacity, so a short blink cannot light
  it up after cancellation. Interrupted reentry reuses the radius and current
  opacities, then resumes the two opacity channels after 80/480ms; it does not
  reset the gradient to full visibility. The earlier immediate-opacity assertion
  was corrected against actual original-browser behavior, not removed.
  Probes: `tool/tds_source/browser-probes/list-row-{blink-live,blink-exit,batch}.js`.
  Their traces are `.context/list-row-{blink-live,blink-exit,batch}-react.json`.
  The fixture's generation key supplies clean mounts without patching TDS code.
  Original captures retain layer identity across theme/size changes and blink
  reentry; a 100ms blink's dimmer stays at zero even 650ms after entry. Both
  synchronous call orders, two accepted deadlines and a three-repeat shine were
  replayed. That checkpoint covered synchronous batches only; the later async
  checkpoint below separates imperative event-task/frame commits from discrete
  input microtask commits. Arbitrary React concurrent scheduling is still not
  equivalent. Mixed synchronous input ordering is covered below.
  Final browser assertions were rerun against an unmodified-package static
  reference build on port 5182 (`.context/tds-react-static`). The development
  server's reconnect/reload interrupted earlier probes; the static run passed
  all three probes without console errors. Build log:
  `.context/tds-react-reference-build.log`.
  The Flutter gallery now has nine TDS controls, including both effect orders,
  short blink/reentry and a batched repeat-count request. Light/100% and dark/160%
  browser smoke runs exercised both orders, live resize/theme changes and
  interrupted reentry. All six `.context/list-row-blink-web-*.png` captures were
  inspected; `.context/list-row-blink-web-smoke.log` contains the interaction
  record and only the headless CPU-rendering fallback warning.
- `list_row_input_order_test.dart`: 23 new regressions cover child/ancestor
  down/up mixed with blink/shine, the committed blink guard and click-after-end
  boundary, touch cancellation/disposal, feedback suppression, disable-while-held,
  Enter/Space keydown/repeat, secondary mouse buttons, the 300ms compatibility
  mouse window and the first active iOS touch. Eleven of the initial 18 failed
  before implementation. `TdsRawPressRegion` separates raw input from gesture
  recognition; touch end bubbles locally and mouse end uses a global route after
  ancestor listeners. The entire child/ancestor activation chain is deferred,
  preserving nested Menu callback order (one added Menu regression). The source
  probe `tool/tds_source/browser-probes/list-row-input.js` passed 49 state samples:
  `.context/list-row-input-react.json`. Native pointer cancellation has no DOM
  mousecancel equivalent and is an explicit safe-cleanup adaptation. Stylus,
  every host gesture recognizer and arbitrary concurrent React scheduling remain.
- `list_footer_color_test.dart`: 16 new tests cover independent ordered Text/Icon
  registration through wrappers, nearest-footer scope, initial-only parent
  props, retention after descendant removal, static palette versus adaptive
  token identity, unknown literals and text-colored string icon shorthand.
  Initial eight regressions all failed before implementation. Press/release
  uses a shared rapid clock with linear RGB interpolation; a deterministic
  60ms sample and interrupted release are asserted. Theme-keyed subtree remount
  resets inline animation while retaining raw registered colors. Touch cancel
  deliberately retains the source pressed appearance. Target selectors are
  captured per timeline, so a later same-color child does not join an existing
  animation until dependencies change.
  Two added cleanup regressions failed before the motion-context fix: source
  contexts revert press then release, restoring old pressed text/scale/shadow
  after a completed cycle, but CSS/base geometry during the first held press.
  A further icon assertion failed before separating custom-property cleanup:
  GSAP removes `--icon-color` on reversion instead of restoring the saved ordinary
  `color` style. The asserted original probe now covers 36 samples, including
  this text/icon difference, in `.context/list-footer-colors-react.json`.
  Run `tool/tds_source/browser-probes/list-footer-colors.js` on
  `?family=list-footer-colors`; the fixture exposes `updateFooter(patch)`.
  Both final probes passed against `.context/tds-react-static` with no browser
  console errors. This is ListFooter registration, correcting the earlier
  checkpoint's mistaken attribution to ListRow. Repeated partial interruption
  is expanded in the following checkpoint; nested footer DOM selectors remain.
- `list_footer_replay_test.dart`: 19 additional regressions distinguish an
  uninitialized zero-playhead timeline from an advanced timeline restarting at
  zero. First-frame down/up does not leave a fabricated press snapshot; a lazy
  release starts from each descendant's own CSS color. Repeated down, a complete
  cycle followed by a same-turn tap, and repeated partial releases keep the
  source's independently initialized snapshots. Text keeps the latest saved
  inline color while icon custom-property cleanup returns to CSS. A 20ms partial
  release found a one-channel rounding mismatch: native interpolation now saves
  the integer RGB channels and four-decimal alpha written by the source
  CSSPlugin. A further original-browser intermediate frame showed that an unset
  icon variable initializes from transparent black, not its SVG fallback; its
  regression also failed before correction. Touch/mouse
  up/cancel after disposal is inert even when Flutter retains the old hit-test
  path, preventing a call into a disposed AnimationController. The original
  four fresh-tap regressions, unmount case and RGB regression failed before
  their respective fixes. Original probe `list-footer-replay.js` now asserts
  63 samples in each theme, including different descendant CSS starts and
  unchanged resolved adaptive/literal dependencies. Traces:
  `.context/list-footer-replay-react-{light,dark}.json`.
- `list_footer_context_test.dart`: 18 added regressions, 16 failing before the
  fix, distinguish press dependencies (normal plus pressed text/icon colors)
  from release dependencies (normal colors only). `grey200` to `hairlineBorder`
  recreates only press. The retained release keeps its saved pressed shape/text,
  running clock and selector snapshot; a newly added child can join press without
  joining release. Both text and icon registration paths are tested in light/dark.
  Semantic aliases `greyBackground` to `backgroundLevelB01` reset press despite
  equal resolved colors. Dark `opacity800` versus `greyOpacity800` also has equal
  values but different pressed strings (`rgba(...,1)`/`#ffffff`), while the 900
  aliases change normal strings too. Light aliases keep identical strings.
  The new generated `color_motion_dependencies.g.dart` preserves the original
  `me`/`aa` identities; interpolation still uses native colors. Timelines write
  rendered styles on each tick so another context can revert them between ticks
  without destroying the active interpolation. The widget test asserts exact
  65ms progress after a press-only change during release.
  Original `list-footer-contexts.js` asserts 30 samples per theme without console
  errors. Traces: `.context/list-footer-contexts-source-{light,dark}.log`.
  Package logs: `.context/tds-context-package-tests.log`; the focused 56-test run
  is `.context/tds-context-tests-after.log`. That checkpoint did not cover nested
  DOM selectors or undefined next-level adaptive targets; the next checkpoint
  adds those cases. Exhaustive dependency combinations and arbitrary original
  CSS color spellings remain unverified.
- `list_footer_undefined_test.dart`: 16 added tests, 14 failing before the fix
  with an unknown `disabledBlue600` exception. Original `aa` returns undefined
  for that next level; `j4` creates a GSAP `from` tween instead of skipping it.
  Text starts at the registered normal color and ends at each target's current
  rendered color. Icons with an unset custom property end at transparent black.
  Release restores the registered normal color; replay rereads the latest inline
  destination. Light/dark text/icon/both cases, context cleanup/restoration,
  intermediate rounded channels and same-RGBA static colors are checked.
- `list_footer_nested_test.dart`: 14 added tests. Ten of the initial twelve
  failed before ancestor target registration. Providers remain nearest-only for
  color registration, while selector snapshots include every descendant Footer's
  text, icon, content and shadow. Actual shape-node lifetimes are now tracked,
  so removed/reinserted nodes do not silently join an old timeline. Outer-only
  presses, bubbled touch/mouse, child-only cleanup, late recapture and disposal
  are checked. TDS accepted clicks bubble inner to outer through activation
  scopes. Two additional tests use a controlled 5ms first release frame to
  verify that each overlapping timeline saves the value rendered before it,
  rather than a shared guessed pressed state.
  Source probes `list-footer-undefined.js` (27 samples) and
  `list-footer-nested.js` (19 samples) pass in each theme, with no console errors.
  Logs: `.context/footer-edges-source-{light,dark}.log` and
  `.context/footer-edges-package-tests.log`. The original nested probe also
  records the scheduler-dependent saved intermediate frame after both owners
  reconfigure. That is not claimed to be an identical wall-clock/native frame.
  These are scoped contracts, not all nested CSS, rich-text or event semantics.
- `list_row_async_test.dart`: 13 additional tests cover one/five-microtask
  imperative batches, a committed-frame blink guard, an overwritten blink's
  retained deadline, raw touch/mouse commit boundaries, disposal, and an
  external TDS button's pointer/keyboard/semantics activation followed by await.
  Three imperative cases failed before the deferred default-priority commit;
  two button cases then failed until synchronous TDS activation was classified
  separately. Default work commits on a native event task or before a frame;
  discrete input upgrades pending work to a microtask commit. The internal
  dispatch marker does not leak through await. Stale frame callbacks/timers are
  cancelled on replacement or disposal. Original probe `list-row-async.js` on
  `?family=list-effects&async=true` distinguishes Promise continuations from
  React's discrete-event commit. Both light/100% and dark/160% runs asserted
  15 state samples without console errors, saved in
  `.context/list-row-async-react.json` and `.context/list-row-async-react-dark.json`.
  These are scoped event-order comparisons, not
  emulation of React concurrent lanes, transitions, flushSync or every browser
  task-queue boundary. The gallery includes both asynchronous command orders.
- Menu lifecycle coverage now includes nested TDS Button/TextButton/IconButton
  child-first activation, disabled/null handlers, drag cancellation, semantics,
  child focus return and Enter-down/Space-up. The invented opacity fade was
  removed; original Menu.Trigger only scales. Third-party recognizers do not
  automatically participate in the native activation scope.
- `wiki_inline_test.dart`: four tests cover original Vpe highlight geometry,
  per-line fragments/edge flags, inline padding/icon flow, font/width/theme
  updates and 5px scroll thresholds with 40/80px fades. The four original edge
  PNGs are bundled without modification. Original font-box rounding is adapted
  using Toss Product Sans metrics; custom fonts and full bidi/viewport motion
  behavior remain unverified.
- `wiki_viewport_motion_test.dart`: 11 added tests cover independent kf spring
  channels (150/250ms icon delays, exit padding retention, reentry/reset and
  explicit highlight exit values), the 60% viewport boundary, nested clipping,
  initial-above guard and document-end latch. Pointer/haptic/keyboard activation
  is gated outside the viewport; Enter/Space activate on keydown without keyup
  duplicates. Popup word/box/scale/dimmer clocks are independent and an entry
  interrupted by dismissal retains its full exit duration. String descriptions
  normalize CSS whitespace while preserving NBSP, use keep-all CJK wrapping,
  reveal rendered lines with a 100ms delay/stagger and lock scroll until the last
  line settles. Custom widget descriptions bypass this animation.
  Reference trace: `.context/wiki-motion-react.json`. Source `Ppe` captures
  body height once; the native adaptation uses the outermost scroll content
  extent once. Browser observer delivery, transformed ancestors, long
  unbreakable words, custom fonts, RTL and exhaustive interrupted motion remain
  unverified. These tests do not confer whole-export parity.
- `list_footer_test.dart`: inherited/explicit zero/negative hairline offsets,
  minimum height including custom hairlines, centered custom children and
  clipped light/dark 120%-wide elliptical shadow/rapid press-release. Descendant
  custom color registration has scoped coverage in the subsequent Footer suites
  above; the full visual matrix remains incomplete.
- `slider_tooltip_test.dart`: original progress-origin coordinates and 30px top
  gap, numeric formatting, live controlled value/anchor updates, native Tooltip
  option forwarding, close/reopen, scope enforcement and teardown. The previous
  inline value bubble is replaced by the real Tooltip. Slider labels retain a
  20px row and thumb shadows use static CSS sigma conversion.
- Shared anchored-overlay geometry now refreshes after paint-time transforms,
  fixing a measured stale x-coordinate after slider value changes. A menu test
  also moves a cached child with an ancestor Transform and asserts tracking
  without continuously scheduling idle frames. Non-painted/repaint-boundary-only
  changes and original ancestor clipping still require further verification.
- `modal_context_test.dart`: open routes preserve/update theme, host toast and
  global loading callbacks; old back streams unsubscribe without replacing the
  route. BottomSheet `onEntered` follows the original open effect, once per
  false-to-true transition, not animation completion. Ignored sheet dimmers no
  longer start an unused dialog wiggle. Arbitrary application inherited scopes
  and nested native navigation still need their complete lifecycle matrix.
- `bottom_sheet_compounds_test.dart`: eight tests cover string/custom/rich header
  inheritance, source 57.5px Select rows, disabled text, line marks and reserved
  hidden slots, 80px/800ms expo plus 30ms stagger/delay, repeated checked-change
  events, disabled press effects, original lack of key activation, measured
  overflow-driven CTA gradients/34px overlap, 600ms CTA fade and native prop
  forwarding. The 160% fixture uses the original 27px/36px metric table, not an
  invented fixed 1.5em override.
- `sheet_motion_test.dart`: six tests cover literal two-axis logarithmic drag
  geometry/dimmer thresholds, fixed 150px-plus-gap entrance, forward rapid exit
  with independent quick dimmer fade, content opacity, touch-only handler
  callbacks, controlled-close rejection, scrollable touch-body guard versus
  original mouse behavior, expansion/cancellation and teardown. Original browser
  drag (+50,-50) produced `matrix(0.98,0,0,0.98,6.9315,-30.7944)` including the
  -10px bottom gap, matching the source formula. Source closure is displacement-
  based, not velocity-based. Full transient frame/interruption equivalence,
  dimmer throttling and device viewport behavior are not yet verified.
- `bottom_sheet_controller_test.dart`: four tests cover retained controller
  scope in header/description/body/CTA, string headers, custom async button
  builders, loading/error/retry/stale completion and close forwarding. Browser
  owner removal confirms closeOnDestroy=false does not preserve the source
  overlay, because its useOverlay still defaults exitOnUnmount=true.
- `global_loading_test.dart`: four tests cover aggregated first-start/final-finish
  callbacks, default context, latest callback refs, Loader mount/unmount and
  its 700ms delay/300ms CSS fade. Original browser 2→1→0 loaders emitted
  start/(none)/finish. Button and standalone LoaderAnimation do not invoke Yoe.
- `progress_transition_test.dart`: six tests cover 500ms CSS ease-in-out,
  reversal shortening (including a second reversal), full-duration retargets,
  unchanged targets, initial-only animate, unclamped out-of-range translation,
  fractional percentage text and disposal. Browser reversal sampling confirmed
  duration shortening; a complete frame-by-frame platform matrix remains.
- `checkable_motion_test.dart`: eight tests cover Checkbox's selection trigger
  and 150ms return, immediate press and tickWeak calls, selected radio behavior,
  quadratic disabled wiggle/unchanged label, disabled check color, gamma-mixed
  line fill, optimistic checked callback vs raw input callback, and no synthesized
  keyboard click. Switch geometry, independent knob springs, softWeak contract,
  click-before-change, inert and mount-captured touch options are covered.
  Original W registers gestures once with TB's initial null rally: root tap
  motion is dormant in 2.5.1, confirmed with click/mousedown sampling.
  Full hover/press/controlled-update color and interruption timelines remain.
- Host self-validation tests cover every platform haptic mapping and the no-op
  adapter, secure-host replacement ordering while enable is pending, and failed
  enable followed by queued disable. These validate injected contracts, not
  Toss-specific vibration patterns or actual OS screenshot protection.
- `text_button_test.dart`: 11 tests use the original font faces for six sizes,
  100/160/200% scales, fixed 5px arrow flow frames with overflowing original SVGs,
  inline x-height alignment, 1/64px line boxes and measured first-line baselines.
  Korean keep-all preserves whole words, splits oversized words, and wraps a
  trailing arrow onto its own line. Uniform underlines use normalized typo
  descent, CSS auto thickness and measured six-size positions without growing
  layout. Mixed fonts/rich spans and non-unit DPR decoration snapping remain.
  Immediate tickWeak, rapid scale/quick gamma ink, retained touchcancel press,
  Enter-down/Space-up without pointer effects, disabled state, color updates
  and disposal are covered. Original browser sampling confirmed no hover fill
  after the initial release's inline style and no standalone hit padding.
  Paragraph ancestry alone supplies inherited padding; custom static palette
  colors advance one level while unknown literals stay unchanged. Native
  colorToken retains adaptive-token identity; Color cannot preserve CSS spelling.
- Re-running `uv run tool/tds_source/fonts.py` produced identical SHA256 hashes
  for all eight TTFs and provenance.json. All 12,605 codepoints per face and
  outlines/advance metrics passed validation against 96 original subsets.
- `highlight_test.dart`: eight tests cover rounded cutout/hit geometry,
  padding/clamping including zero-padding negative coordinates, exact original
  SVG arrow, six message alignments and original-font 100/160% multiline metrics.
  Separate basic opacity/slow expanding exit, 2.2s message keyframes, reduced
  motion, interruption continuity, captured callback/prop snapshots, delayed
  cancellation, controlled-close rejection and teardown have scoped tests.
  Original browser sampling confirmed full Highlight's target is inert and
  Escape does not invoke onClose; Tab reaches the hidden close button. Standalone
  HighlightUI is not modal and its hole still passes input through. Android's
  original filter merges offsetblur directly, bypassing the .1 alpha-transfer
  result; its full-alpha blur is reproduced. Programmatic React target clicks
  invoke native/synthetic handlers twice; this DOM-only path is not reproduced.
- `full_tooltip_test.dart`: 19 tests cover mat's two-contour silhouette and
  vertical reflection, unclamped arrow ratios, static teal colors, 1.35 line
  boxes, integer clientHeight rounding, 400/500/700ms inline entrance stages,
  12px overlap footprint/translation and explicit floating offset precedence.
  Timers handle controlled callbacks, callback replacement, zero/negative
  durations, uncontrolled override and disposal. Original browser checks confirm
  omitted relative placement omits the target, uncontrolled onClose is replaced,
  and the initial outside callback fires even for a closed tooltip's pointerdown.
  Seven added regressions cover the two independent 100ms trailing observers,
  resize bursts/cancellation, held previous heights before the 400ms from:0
  restart, independent overlap/spacer motion, source integer height rounding,
  frozen exit props, fresh reopening and mode/timer/callback ownership.
  The original browser trace is `.context/full-tooltip-motion-react.json`;
  `window.tdsReference.updateFullTooltip(patch)` in the reference fixture drives
  repeatable prop transitions without changing the package source.
  Cold-mount source observers can delay the nominal height timeline by another
  100ms; native first-layout measurement does not reproduce all such settling.
  Four more regressions cover eo's interrupted-reopen quirk: both relative and
  floating children remount without the presence wrapper, so their next close
  removes immediately. A fresh mount, floating-mode replacement or controlled
  mode replacement restores retained exits. The sequence was replayed on the
  original in `tool/tds_source/browser-probes/full-tooltip-presence.js`; traces
  are `.context/full-tooltip-presence-{relative,floating}.json`. At the sampled
  second close no message remained by 11ms; a third, clean close retained the
  message at 60ms. Native unit tests also check intervening open-state updates
  and cancelled timers. Floating blur has a paired comparison but its
  filter rasterization still differs. Selector anchors, complete interruption
  timelines and rich-message metrics remain incomplete.
- `npm run generate --prefix tool/tds_source`: inventory, 298 palette entries,
  32 text metric sets, 44 asset frames, 25 list text presets and coverage generated
  successfully from pinned npm source.
- `node tool/tds_source/coverage.mjs --check`: current.
- `git diff --check`: clean for tracked edits.

Automated tests are scoped examples, not exhaustive platform accessibility or
motion tests. Most widget tests use Flutter's test font; the font geometry test
loads the actual regular face. Visual fixtures load the bundled font faces.

## Build checks

- Gallery Web build succeeded with `lib/tds_gallery.dart`. Subsequent captures
  use the separate `.context/tds-gallery-web` output served on port 5181, so
  rebuilding the gallery does not replace the app at `build/web`.
- Main Web build succeeded with `lib/main.dart`; `build/web` was left as the
  main app output, not the gallery.
- Main Android debug APK succeeded with `lib/main.dart`.
- Main ARM64 iOS Simulator build succeeded with signing disabled:

  ```sh
  xcodebuild -quiet -workspace ios/Runner.xcworkspace -scheme Runner \
    -configuration Debug -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .context/ios-derived-data \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
  ```

After the final native test runs, Android was rebuilt for `lib/main.dart` and
the iOS generated target was restored to `lib/main.dart` before the successful
ARM64 build. Run these target-restoration steps sequentially: a concurrent
Android/iOS preparation attempt failed deleting generated Swift package files;
the same iOS command passed after Android finished, without manual deletion.
The independent-context checkpoint repeated this sequence successfully after
both full native runs and both final scoped capture reruns.
The undefined/nested checkpoint repeated it again after both full native suites.
The typography/arrow/shadow checkpoint has also passed both full native suites,
followed by Android, ARM64 iOS Simulator and main Web builds in that order;
its separate gallery Web build passed before the captures.
`ios/Flutter/Generated.xcconfig` again points to
`FLUTTER_TARGET=lib/main.dart`. Latest logs are
`.context/visual-main-android-build.log`,
`.context/visual-main-ios-config.log` and
`.context/visual-main-ios-build.log` (quiet xcodebuild, exit 0).
The gallery and main Web logs are
`.context/visual-final-gallery-build.log` and
`.context/visual-main-web-build.log`. The final Simulator Runner binary
was checked with `lipo` and is ARM64; `build/web` contains the main app.

The default Flutter multi-architecture simulator command failed earlier with
Xcode 27 dependency-graph/architecture handling errors. ARM64-only success does
not establish x86_64 simulator support. No signing, store/release distribution,
physical device rendering or device OAuth was validated. No platform settings
were changed to hide this limitation.

## Native engine self-validation

`integration_test/tds_native_test.dart` passed on the iOS 26.2 iPhone 17 Pro
Simulator and Android API 36.1 Medium Phone emulator. The scenario covers
Checkbox/Switch toggling, text entry, progress and BottomSheet opening/closing
at light/dark and 100/160% text scale. iOS 160% uses the actual A11y_Medium
category, and the test asserts the resulting font size. A second scenario checks
TextButton activation, keep-all and underlines in the same four theme/scale
combinations. Android screenshot-surface preparation is performed per test.
Two more scenarios cover Highlight's inert target, mask and dismissal lifecycle,
and FullTooltip's inline reflow, floating blur and pointer callbacks, in the same
theme/scale combinations. FullTooltip also mutates a two-line message into three
lines, enables overlap and reopens during exit, asserting the final flow height
and continued presence. The final expanded run also checks both inline and
floating interrupted reopen: the next close removes immediately, and a later
fresh open restores the retained exit (still mounted 60ms after closing).
Each platform passed these checks in all four theme/scale combinations.
The 16 controls/sheet, eight TextButton, eight Highlight,
eight baseline FullTooltip and eight resized/reopened FullTooltip captures are
smoke evidence. WikiText adds viewport gating, touch activation, entry/exit/reentry,
definition open/dismiss and string-description captures in all four theme/scale
combinations on each platform (16 more captures). After the final whitespace,
keep-all and word-centering corrections, the WikiText scenario was rerun on both
platforms with `--dart-define=TDS_WIKI_ONLY=true`. The 16 WikiText images are also
collected in `.context/wiki-native-{ios,android}-contact.png`.

The shine checkpoint added `integration_test/list_row_live_test.dart` on both
engines. Its four initial-theme/text-scale combinations check captured integer
shine endpoints, responsive light/dark gradient bounds, width/count retargeting,
theme-triggered restart and retention beyond one cycle after a two-repeat
request. Both full runs passed, including the existing scenarios. Eight
images per platform capture resized and opposite-theme states. Those 16
are collected in `.context/list-row-native-{ios,android}-contact.png`, with
top-of-screen details in `.context/list-row-native-{ios,android}-detail.png`.

The latest full runs also passed `integration_test/list_row_blink_test.dart` on
both engines, preserving all existing scenarios. The added scenario checks
synchronous shine/blink ordering, live resize/theme updates, cancellation
before the dimmer's delay and retained exit/reentry in the same four
theme/scale combinations. A final standalone run of that scenario passed on
each platform. Eight additional images per platform capture resized and
reentered blink states. That checkpoint brought the inspected native screenshot
set to **96**. Its latest 16 are collected in
`.context/list-row-blink-native-{ios,android}-contact.png`, with details in
`.context/list-row-blink-native-{ios,android}-detail.png`.

The input/color checkpoint reran the complete suite on both engines and added
`integration_test/list_input_color_test.dart`. It checks child-down shine yielding
to touch, ancestor-down/up shine surviving, click-triggered blink after release,
adaptive Text/Icon registration, press/release colors, independent text/icon
context cleanup, theme remount, descendant removal and touch-cancel retention.
All four light/dark ×100/160% variants passed on Android and iOS. Thirty-two new
captures show press, context reversion, opposite theme/removal and retained cancel
states, bringing the stored native set to **128**. All 32 new images were
inspected in `.context/list-input-color-native-{android,ios}-{press,revert,theme,cancel}.png`
sheets. Held-press images include the Flutter test binding's colored pointer
crosshair; it is test instrumentation, not an application graphic. Reversion,
theme and cancelled-pointer captures have no such overlay. The sheets resize
images for inspection only and are not golden/difference inputs.

Input/color checkpoint logs: `.context/tds-input-color-{android,ios}-drive.log`.
Its screenshots:
`.context/tds-native-list-input-color-{press,revert,theme,cancel}-{android,ios}-{light,dark}-{100,160}.png`.
The theme segment identifies the **initial** theme; `theme` and `cancel` captures
show the opposite theme. For a scoped rerun use
`--target=integration_test/list_input_color_test.dart` with the existing driver.
Android converts its screenshot surface per test and theme mutations receive an
extra 100ms raster frame before capture. `TDS_WIKI_ONLY` still skips these later
scenarios. Native runs did not exercise browser mouse compatibility or keyboard
repeat on physical hardware; those have separate source/widget tests.

The replay/async checkpoint reran the complete suite on both engines, including
`integration_test/list_replay_async_test.dart`, with all scenarios passing. In
each light/dark ×100/160% variant, five-microtask imperative shine/blink ends in
blink, while a TDS button's discrete shine/await/blink preserves the committed
shine guard. The test also checks a fresh pre-frame tap's intermediate icon
alpha, descendant color update without stale press snapshots, repeated partial
press/release cleanup and pointer-up after Footer removal. Exact saved text
colors and scale are asserted in the running Flutter engines.

Thirty-two additional captures are stored as
`.context/tds-native-list-replay-{batch,discrete,fast-tap,revert}-{android,ios}-{light,dark}-{100,160}.png`.
All were inspected in eight
`.context/list-replay-native-{android,ios}-{batch,discrete,fast-tap,revert}.png`
contact sheets. That checkpoint brought the platform-labelled integration set
to **160**; older unlabelled diagnostic images remain separate and were not deleted.
These sheets are resized for layout/color inspection, not goldens. Effect-state
assertions identify blink versus shine; the captures alone do not establish
frame-by-frame animation parity. A test-only AnimatedScale finder was narrowed
to the Footer after adding a second animated control, then both full runs
passed. Latest logs: `.context/tds-replay-{android,ios}-drive.log`.
For a scoped rerun use `--target=integration_test/list_replay_async_test.dart`
with the existing driver. `TDS_WIKI_ONLY` continues to skip the later scenarios.

The independent-context checkpoint reran both complete native suites, including
`integration_test/list_footer_context_test.dart`, with all scenarios passing.
In each light/dark ×100/160% variant, text and icon press-only changes keep the
release save and let an in-flight release finish. A later normal-color change
restores the previous release snapshot. Additional assertions check separately
captured late text, equal-valued semantic aliases, colors, scale, shadow and
pointer-up after removal. Exact 65ms progress remains a fake-clock widget
assertion, not a wall-clock device assertion. Full-suite logs:
`.context/tds-context-{android,ios}-drive.log`.

The 32 new final screenshots are
`.context/tds-native-footer-contexts-{cleanup,restore,late,alias}-{android,ios}-{light,dark}-{100,160}.png`.
All were inspected in eight
`.context/footer-contexts-native-{android,ios}-{cleanup,restore,late,alias}.png`
sheets, resized for inspection only. That checkpoint brought the
platform-labelled integration set to **192** PNGs; nine older
unlabelled/diagnostic native PNGs remain untouched.
The first Android dark/160% restore capture showed the preceding explicit-blue
raster frame even though both saved-text assertions passed. The test now pumps
an additional 100ms stable frame before capture, matching the existing native
harness pattern. Both targeted platform runs then passed, and all 32 final
captures were rechecked, including the corrected grey text in that case.
The old capture is retained separately at
`.context/footer-contexts-android-dark-160-capture-diagnostic.png`.
Final scoped logs: `.context/tds-context-{android,ios}-final-drive.log`.
Use `--target=integration_test/list_footer_context_test.dart` with the existing
driver for this scenario. `TDS_WIKI_ONLY` still skips it. Neither native set is
paired with original physical-device screenshots or a motion-golden threshold.

The undefined/nested checkpoint reran both full suites, including
`integration_test/list_footer_edges_test.dart`, with all scenarios passing.
The new scenario covers from-only adaptive colors, replay after release,
outer-only descendant targeting, inner-to-outer activation, removal/reinsertion
without joining old snapshots, and recapture after an owner dependency changes.
All four light/dark ×100/160% variants pass on each native engine. Colors,
shape state and activation order have assertions; the overlapping 5ms first
release frame is a fake-clock widget regression, not a native timing claim.
Latest full-suite logs: `.context/footer-edges-{android,ios}-drive.log`.

The 48 new captures are
`.context/tds-native-footer-edges-{from-only,repress,nested,bubbled,late,recaptured}-{android,ios}-{light,dark}-{100,160}.png`.
All were inspected using twelve
`.context/footer-edges-native-{android,ios}-{from-only,repress,nested,bubbled,late,recaptured}.png`
sheets. These crop/resize for inspection only and are not pixel-comparison
inputs. The platform-labelled integration set now contains **240** PNGs, plus
the nine historical unlabelled/diagnostic PNGs. Held-pointer captures include
Flutter test crosshairs; released `bubbled` captures have no crosshair. These
markers must not be mistaken for an app graphic or suppressed in production
input handling. For a scoped rerun use
`--target=integration_test/list_footer_edges_test.dart` with the existing driver.
`TDS_WIKI_ONLY` preserves its early return before the added scenarios.

The typography/arrow/shadow checkpoint reran all 12 native scenarios on both
the Android emulator and ARM64 iOS Simulator, including
`integration_test/text_visual_geometry_test.dart`. Both suites passed. The new
scenario checks uniform-text first-baseline/flow geometry, Footer normal/held
press state, whole-word wrapping, fixed arrow dimensions and shadow bounds at
integer/fractional widths. It runs light/dark ×100/160% on each engine; iOS
160% uses the source A11y_Medium category. The assertions concern layout and
state, not exact painted line advances or cross-engine raster equivalence.

All 56 new native captures (28 per platform) were inspected using fourteen
`.context/visual-review-native-{android,ios}-{phase}.png` sheets. The four
large multiline typography images were also opened uncropped, since the
contact-sheet preview cuts off their last line. Native filenames are
`.context/tds-native-visual-{type,type-multiline,footer,footer-pressed,footer-multiline,shadow,shadow-fractional}-{android,ios}-{light,dark}-{100,160}.png`.
The preview sheets may crop/resize for inspection; native screenshots are not
inputs to the DPR-1 Web pixel comparisons. Held-pointer crosshairs remain test
instrumentation. Latest full-suite logs: `.context/visual-{android,ios}-drive.log`.
For a scoped rerun, use `--target=integration_test/text_visual_geometry_test.dart`
with the existing driver. The WikiText-only early return is unchanged.

Initial Android resize/100% captures still contained the previous raster frame
despite the logical theme/width assertions passing. The test now pumps a further
100ms before taking the resize screenshot; both standalone platform runs were
repeated successfully. All 16 corrected captures were opened and inspected,
including the contact sheets and detail sheets. Text stayed within its row at
100/160% scale, and the corrected images show the asserted size and theme.
Screenshot acquisition is not frame-synchronized between engines, so different
shine/blink intensity in individual captures is not evidence of pixel parity
or a measured timing discrepancy. These successes are not pixel-parity
certificates.

The initial expanded run failed on both platforms because the native test
delayed applying a floating reopen: `pumpAndSettle()` waits 100ms before its
first frame. The diagnostic trace reached 115ms after the first close before
requesting reopen; another delayed frame completed the 200ms exit before the
new widget could rebuild. This exercised a clean mount, not an interruption.
The test now pumps the reopen immediately before settling, asserts that the
departing surface is still present, and keeps the immediate-removal assertion.
No production animation duration or expectation was relaxed. The original
failure is retained in `.context/tds-native-tooltip-diagnostic.log`.
The latest FullTooltip screenshots are collected for inspection in
`.context/full-tooltip-native-{ios,android}-contact.png`.

```sh
flutter drive --driver=test_driver/tds_native_driver.dart \
  --target=integration_test/tds_native_test.dart -d DEVICE_ID
```

Logs: `.context/tds-native-{ios,android}-integration.log`. Current screenshots:
`.context/tds-native-{controls,sheet,text-buttons,highlight,full-tooltip,full-tooltip-resized}-{ios,android}-{light,dark}-{100,160}.png`.
WikiText: `.context/tds-native-{wiki,wiki-definition}-{ios,android}-{light,dark}-{100,160}.png`.
ListRow: `.context/tds-native-list-row-resized-{ios,android}-{light,dark}-{100,160}.png`
and `.context/tds-native-list-row-theme-{ios,android}-{light-to-dark,dark-to-light}-{100,160}.png`.
ListRow blink: `.context/tds-native-list-row-blink-{resized,reentry}-{ios,android}-{light-to-dark,dark-to-light}-{100,160}.png`.
Final targeted logs: `.context/tds-native-wiki-{ios,android}-final.log`
and `.context/tds-native-blink-{ios,android}-final.log`.
For the blink-only rerun, use the same drive command with
`--target=integration_test/list_row_blink_test.dart`.
Earlier filenames without a platform suffix are superseded and not evidence.
These are native smoke checks, not paired original-device golden comparisons.
No physical device, VoiceOver/TalkBack, real OAuth or Toss host was exercised.
The user confirmed no host SDK/test app is available; self-validation proceeds
without treating mock/Flutter channel success as real host certification.

## Visual evidence

Browser skill workflow: **DONE_WITH_CONCERNS** for the sampled comparisons.
Screenshots were opened and inspected; this is not a completed full-library QA
run. Evidence lives in the gitignored `.context/` directory.

The fixture uses the original components without editing npm package source.
Standalone host safe-area data is explicitly zero. `ColorSchemeArea` supplies
original adaptive tokens. Because AIT installs light tokens at `:root` and
motion overlays portal outside the local area, the fixture mirrors the
original area's CSS variables to the document root for a dark-capable host.
An earlier dark capture without this setup was invalid and was replaced.

Capture after `#fixture` exists and `document.fonts.ready` resolves, with a
390px viewport and equal query parameters. Flutter uses headless Chromium's
CPU fallback renderer here. Browser/Flutter rasterizers and font hinting differ.
Do not interpret low average pixel error on a mostly empty canvas as parity.

| Sample | Compared area | Pixels with channel delta >16 | Mean max-channel delta (0–255) |
| --- | --- | ---: | ---: |
| List/header/footer/table, light 100% | 390×500 | 7,274 | 3.0049 |
| List/header, dark 160% | 390×700 viewport crop | 10,732 | 2.9231 |
| Top/bottom action toast, dark 100% | 390×700 | 2,762 | 0.8948 |
| List assets/header, light 100% | 390×600 | 7,019 | 2.6628 |
| List assets/header, dark 160% | 390×650 viewport crop | 9,355 | 2.6485 |
| Top/Bubble/LeftText/Paragraph.Link, light 100% | 390×600 | 6,414 | 2.1417 |
| Number keypad, light 100% | 390×320 | 920 | 0.5365 |
| Number keypad, dark 200% | 390×320 | 1,018 | 0.5642 |
| BottomCTA Single/Double/accessories, light 100% | 390×580 | 6,150 | 2.2060 |
| BottomCTA Single/Double/accessories, dark 160% | 390×650 | 8,126 | 2.5270 |
| Rich Paragraph/Top/Badge, light 100% | 390×440 | 9,447 | 4.7237 |
| Checkbox checked, dark 100% | 390×200 | 0 | 0.0330 |
| TextButton block arrow, six sizes, light 100% | 390×320 | 1,724 | 0.6722 |
| TextButton underline, six sizes, light 100% | 390×320 | 2,232 | 0.8185 |
| TextButton multiline inline arrow, dark 160% | 390×950 | 7,344 | 1.1605 |
| Highlight left/bottom message, light 100% | 390×650 | 1,187 | 0.2209 |
| Highlight centered/top message, dark 160% | 390×650 | 2,008 | 0.4362 |
| FullTooltip multiline relative/bottom, light 160% | 390×450 | 2,548 | 1.1712 |
| FullTooltip floating/top/overlap, dark 100% | 390×450 | 6,527 | 1.7148 |
| FullTooltip three-line relative/overlap, dark 160% | 390×450 | 1,379 | 0.6103 |
| Menu dropdowns, light 100%, before CSS sigma correction | 390×440 | 1,868 | 2.2784 |
| Tooltip 18 size/clip/side variants, light 100% | 390×1180 | 5,061 | 1.3753 |
| WikiText multiline highlights, light 100% | 390×140 | 2,042 | 1.6978 |
| WikiText viewport entry settled, light 100% | 390×650 | 374 | 0.0675 |
| WikiText string definition, light 100% | 390×650 | 2,630 | 0.9859 |
| SliderTooltip/default slider, light 100% | 390×220 | 464 | 0.6815 |
| BottomSheet headers/Select, light 100% | 390×330 | 3,555 | 2.0070 |
| BottomSheet scrolling/CTA, light 100% | 390×844 | 3,412 | 0.7141 |
| BottomSheet scrolling/CTA, dark 160% | 390×844 | 5,036 | 0.7480 |

Files: `lists-comparison.png`, `lists-dark-comparison.png`,
`toast-dark-comparison.png` with matching JSON reports. Image panels are
original React, native Flutter, absolute difference, in that order.
New files: `list-assets-comparison.png`, `list-assets-dark-comparison.png`,
`compounds-comparison.png`, each with a matching JSON report. New captures were
opened and inspected after the Asset transparent-background and header
icon-height fixes. The dark list-assets crop does not include the last row.
Earlier list/toast samples above predate the latest compound changes; they are
retained as historical evidence, not rerun claims.
Keypad evidence: `keypad-comparison.png` and `keypad-dark-comparison.png`, with
JSON reports. These captures were repeated after correcting fixed font sizing,
row geometry and the back-arrow graphic. Remaining differences include glyph
rasterization and the inline SVG's baseline positioning.

The paired fixtures caught and corrected Top.LowerCTA stretching, Paragraph.Link
default styling, Asset transparent backgrounds and header icon flow height.
The latest compounds capture was repeated after the Bubble strut fix: default
single-line flow height now matches 49.796875px. It still shows text/inline
differences and is not a visual parity pass. New bottom CTA fixtures exposed
incorrect equal-width distribution: CSS grows from the unclamped auto basis,
then freezes min-width violations and redistributes free space. This is fixed.
Files: `bottom-cta-comparison.png`, `bottom-cta-dark-comparison.png`, and their
JSON reports. The latter was captured at 390×1000, then cropped to 390×650;
all fixture rows are included. Source and Flutter screenshots/diffs were opened.

New evidence: `paragraphs-comparison.png`, `menus-comparison.png`,
`tooltips-comparison.png`. The badge correction reduced the paragraph sample's
delta>16 pixels from 19,080 to 9,447; remaining Korean line breaks and baselines
are visible. Tooltip line-box/shadow correction reduced mean max-channel delta
from 1.7620 to 1.3753, not to zero. `react-secure-keypad.png` and
`flutter-secure-keypad.png` were also inspected, but their independently randomized
blank positions make full-image pixel comparisons invalid. An early tooltip
capture with 112px row spacing overlapped variants; the final fixture uses 180px
rows and all 18 variants fit in 390×1180. Menu evidence predates the latest sigma
correction and is not a rerun claim.

Latest separate-gallery captures: `wiki-comparison.png` and
`slider-tooltip-comparison.png`, with JSON reports and original/native PNGs.
All were opened and inspected. WikiText now highlights both lines with original
edge assets; SliderTooltip is a real original-shaped tooltip at the source
30px gap. Glyph rasterization, fractional coordinates and slider-track pixels
still differ. The mostly empty comparison area must not be read as a parity
percentage or a full state/scale/theme pass.

BottomSheet static comparisons: `sheet-select-comparison.png` and
`sheet-long-comparison.png` with original/native captures and JSON reports,
all opened and inspected. These were captured after the compounds/layout fixes
and before the subsequent drag/transition edits. Text rasterization and
fractional coordinates still differ; these are not motion comparisons.
The dark 160% `sheet-dark-large-comparison.png` capture includes the metric-table
correction (previously 13,729 pixels over delta 16, mean 4.1378). It was opened
and inspected; the aggregate metrics are not parity percentages.

New checkable/TextButton evidence: `checkbox-dark-checked-comparison.png`,
`text-buttons-arrow-comparison.png`, `text-buttons-underline-comparison.png`,
and `text-buttons-inline-dark-large-comparison.png`, with JSON reports. All
were opened and inspected. Checkbox's ambient plain-string color is fixed to
the original fixture body's #212529 even in dark mode, not to a component
token. The previous adaptive-white fixture comparison was invalid. TextButton
keep-all corrected Korean mid-word breaks and trailing-arrow placement; the
six-size underline fixture tests exact source under-edge positions. Remaining
font rasterization/width differences are visible. A cold-start empty Flutter
capture was discarded; capture only after flutter-view exists and painting
has settled, not solely after a fixed short delay.

New overlay evidence: `highlight-left-comparison.png`,
`highlight-center-dark-comparison.png`, `full-tooltip-inline-comparison.png`
and `full-tooltip-floating-dark-comparison.png`, with paired original/native
images and JSON reports. All were opened and inspected. Correcting Highlight's
Android offsetblur reduced delta>16 pixels in the light fixture from 3,041 to
1,187. FullTooltip's floating blur retains visible kernel/compositing differences;
the aggregate number must not hide that concern. Temporary browser filter
overrides were diagnostic only and are not the final reference captures.

`full-tooltip-resized-comparison.png` adds the three-line overlapped dark/160%
end-state fixture. Its originals, native image, difference image and JSON report
were inspected. Layout edges align in this sample, while glyph rasterization and
small color differences remain. The headless Flutter Web renderer reported its
CPU-only fallback; this sample is not a GPU/browser/device-wide equivalence test.

ListFooter ordered-color evidence uses four 390×100 crops: initial and
post-release color-change states in light/100% and dark/160%.
`.context/list-footer-comparison-{light-100,dark-160}-{initial,revert}.png`
and companion JSON reports compare untouched React with the native gallery.
The four delta>16 pixel counts are 476, 580, 818 and 989 respectively; mean
max-channel deltas are 1.0307, 1.7082, 2.1030 and 2.5771. These are sample
measurements, not parity percentages or passing thresholds. Glyph baseline/
rasterization and shadow interpolation differences are visible in the inspected
comparisons; matching color state does not establish pixel equality.

Eight inspected gallery captures in `.context/list-footer-web-*.png` and
`.context/list-input-web-*.png` exercise footer click delivery, live color/theme,
removal, registration order/reset and all three row input modes at light/100%
and dark/160%. Record: `.context/list-input-color-web-smoke.log`. Accessibility
clicks deliver SemanticsAction.tap without the raw pressed lifecycle, so those
color-change screenshots alone are not motion-context reversion evidence.
`tool/tds_source/browser-probes/flutter-footer-pointer.js` separately dispatches
mouse PointerEvents to the Flutter event surface, verifies exactly one click,
then the fixture's color-change control triggers context reversion. Its two
`.context/list-footer-web-raw-revert-*.png` captures supply the native half of
the paired reversion comparisons. Record: `.context/list-footer-paired-smoke.log`.
All captures/comparisons were inspected. Browser output contained only the
known headless CPU-rendering fallback warning, not application errors.

The replay checkpoint adds four unscaled 390×110 paired crops in light/dark
at 100/160%. `react-footer-fast-tap.js` and `flutter-footer-replay.js` send the
first down/up before an animation frame and then change the descendant color.
The original asserts both text colors and unit scale; the Flutter browser probe
asserts exactly one raw-pointer click and the color-control activation. Exact
Flutter color/scale and the intermediate transparent icon are asserted in the
widget and native engine tests, not inferred from the semantics tree.
All four `.context/footer-replay-paired-{light,dark}-{100,160}.png` comparisons
were opened and inspected. In light/100, light/160, dark/100, dark/160 order,
their delta>16 pixel counts are 491, 822, 460 and 735; mean max-channel deltas
are 1.2651, 2.2120, 0.8223 and 1.3923. Those measurements describe this fixture,
not a similarity score or a parity threshold. Text baseline/rasterization and
arrow pixels still differ despite matching the observed color lifecycle.
Individual images use `.context/{react,flutter}-footer-replay-*.png`; companion
JSON reports sit beside the comparisons. The remaining three capture pairs are
logged in `.context/list-footer-replay-web-captures.log`. The browser emitted
only its known CPU-rendering fallback warning, with no application errors.

`flutter-list-row-async.js` activates both gallery async-order buttons at
light/100% and dark/160% and verifies that their semantics remain present after
completion. The two `.context/list-row-async-web-*.png` captures were inspected;
`.context/list-row-async-web-smoke.log` has no application error. This is browser
activation/lifecycle smoke evidence only. The internal blink-versus-shine guard
is asserted by widget/native tests; the canvas semantics tree cannot prove
which painter ran, and these end-state screenshots are not motion goldens.

The independent-context checkpoint adds sixteen unscaled 390×100 comparisons:
`cleanup`, `restore`, `late` and `alias` in light/dark at 100/160%. The original
`react-footer-context-capture.js` asserts saved text/shape and separate late
targets. `flutter-footer-context-capture.js` delivers raw pointer events and
asserts exactly one click plus fixture-control/late-text semantics; widget/native
tests assert the actual Flutter colors, scale and shadow. The original route is
`list-footer-colors`, while the native gallery uses `list-footer-contexts`.
Both accept `contextCase=cleanup|restore|late|alias` for the capture probes.
All 32 source/native crops and all 16 difference panels were inspected, using
four unscaled overview sheets where useful. The captures and paired reports are
`.context/{react,flutter}-footer-contexts-{cleanup,restore,late,alias}-{light,dark}-{100,160}.png`
and `.context/footer-contexts-paired-{cleanup,restore,late,alias}-{light,dark}-{100,160}.{png,json}`.
Their per-image delta>16 pixel counts range from 48 to 690 of 39,000 pixels,
and mean max-channel deltas from 0.1255 to 0.9518. These measurements are not a
similarity percentage or pass threshold; glyph baselines/rasterization, arrows
and the restored shadow still differ. Logs:
`.context/footer-contexts-web-captures-{light,dark}-{100,160}.log`.
No application errors occurred; the known headless CPU-rendering fallback
warning remains. An initial all-in-one chain hit the browser CLI's 30-second
request timeout, so the final passing runs are four separate theme/scale chains.
The incomplete initial log is not passing evidence.

The undefined/nested checkpoint adds twenty-four unscaled comparisons across
six cases (`from-only`, `repress`, `nested`, `bubbled`, `late`, `recaptured`) in
light/dark at 100/160%. The first two use 390×100 crops; the four nested cases
use 390×130. `react-footer-edge-capture.js` asserts original color/shape and
click ordering; `flutter-footer-edge-capture.js` verifies raw pointer delivery
and fixture semantics. Widget/native tests separately assert Flutter rendered
colors, scale, shadow and callback order. Canvas semantics are not treated as
pixel or painter-state evidence.

All 48 individual crops and 24 difference panels were inspected, with four
unscaled overview sheets. Paths:
`.context/{react,flutter}-footer-edges-{case}-{light,dark}-{100,160}.png`,
`.context/footer-edges-paired-{case}-{light,dark}-{100,160}.{png,json}` and
`.context/footer-edges-web-{light,dark}-{100,160}-overview.png`.
Per-image delta>16 counts range from 427 to 1105, with mean max-channel deltas
from 0.762256 to 2.283412. The crops have 39,000 or 50,700 pixels, respectively;
these measurements are not a similarity score or a pass threshold. Glyph
baselines/rasterization, arrows and shadow gradients remain visibly different.
The eight final capture chains each contain three cases and six images, keeping
each chain below the browser CLI timeout. Logs:
`.context/footer-edges-web-{light,dark}-{100,160}-{from-only,bubbled}.log`.
All final logs have zero probe errors and zero font-fetch warnings; only the
known headless CPU-rendering fallback warning remains. The runner checks eval
errors and screenshot counts because the CLI can exit zero despite a failed
eval. Flutter can combine sibling texts into a newline-separated semantic
label; the outer nested Footer's button rectangle includes the child, so the
probe targets the outer text row explicitly.

### Typography, arrows and Footer shadows

The latest checkpoint adds 80 unscaled React/Flutter Web pairs: 32 typography
pairs (four weights, one/two lines, light/dark, 100/160%), 24 Footer pairs and
24 reruns of the previous color/nested cases. The Footer set includes default,
held press, multiline, whole-label multiline and integer/fractional-width
shadow crops. Sizes are 390×360/630 for typography, 390×200/280 for Footer and
390×100/130 for the existing edge cases. All individual source/native images
and difference panels were inspected via the unscaled
`.context/visual-review-{type-*,footer-*,edge-*}.png` sheets. Measurements always
use the original PNGs, never resized previews.

The implementation now preserves Chromium's 1/64px used line height and the
bundled Toss font's first baseline for uniform Text/plain Footer labels.
Footer keeps Korean words together, and its shadow resolves 120% width to a
layout unit before centering: 342px → 410.390625px wide and -34.1953125px left;
333.25px → 399.890625px wide and -33.3203125px left. The underlying SVG arrow
paths are unchanged. Separately, the gallery's nested/footer-color fixtures
now model the original anonymous inline strut, middle-aligned labels and
top-aligned outer arrow. Their improvements include **fixture composition**
changes, not just package fixes or an automatic DOM-like child layout feature.

For the 76 pairs with a historical baseline, the original React PNGs are
byte-identical before/after. The remaining four new pairs show the full
multiline label and have no before measurement. Aggregate delta>16 counts are:

| Comparable pairs | Before | After |
| --- | ---: | ---: |
| 32 typography | 117,904 | 116,698 |
| 20 Footer | 24,859 | 12,038 |
| 24 color/nested cases | 17,437 | 10,670 |

No comparable pair increased this count. These are absolute pixel-difference
counts, **not** acceptance thresholds, similarity percentages or golden passes.
For example, the 390×200 light/160% default Footer changes from 669 to 282
delta>16 pixels (mean maximum channel delta 0.805128 → 0.167128). Its multiline
historical crop changes from 7,234 to 2,594. The eight isolated shadow crops
still have maximum channel differences of 1–3 despite zero delta>16 pixels.
Current evidence:
`.context/visual-after-{react,flutter}-{case}-{light,dark}-{100,160}.png` and
`.context/visual-after-paired-{case}-{light,dark}-{100,160}.{png,json}`.
All 80 final capture logs have zero probe/application/font-fetch errors; the
known CPU-only headless renderer warning remains.

Original geometry is measured without inserting baseline markers or changing
the pinned package/CSS. `visual-metrics.mjs --all` reads 24 original-only pages
to generate all 480 specimens in `reference/visual-geometry.json`. The original
Text fixture must use `display="block"`: `as="div"` and `style.display` do not
override its default inline display. With the reference/gallery builds served
at ports 5182/5181, reproduce from the repository root:

```sh
node tool/tds_source/visual-capture.mjs after
node tool/tds_source/visual-metrics.mjs after --all
```

Only use `before` against an actual pre-change gallery build; it overwrites that
phase's artifacts. No comparison target is derived from Flutter output.

**Remaining multiline difference:** SkParagraph rounds each painted line
advance, not just the outer height. Footer xs advances by 21px versus CSS
21.28125px at 17px font size, and 34px versus 33.796875px at 27px. Thus the fourth
and later lines can differ by about 1px even when the first baseline and total
flow height match. `forceStrutHeight` does not remove this rounding. The adapter
does not scale glyphs or repaint clipped line fragments to conceal it. Mixed
spans, arbitrary font overrides, text selection/copy and full word-break behavior
are not established by the uniform-label tests. Glyph/SVG antialiasing and
gradient rasterization also remain different.

No pass threshold is approved. Current captures do not validate complete
pressed/hovered/disabled animation timelines, every font scale, full multiline
behavior or pixel equality on physical iOS/Android devices.

### Long uniform paragraph flow (2026-10-11)

The follow-up fixes a safely expandable accumulated **layout-height** error in
`TdsLineBox`. It previously divided a native paragraph's height by the fractional
CSS advance when recovering its line count. Native height is already the sum of
individually rounded advances, so this eventually lost or invented a whole line.
For example, 40 Footer.Text lines at 100% occupy 840 native pixels; the old
calculation inferred 39 lines and returned 829.96875px instead of the original
851.25px. A regression failed with those exact values before the change.
For native advances that round down, the wrapper now divides by the rounded
native advance before restoring the larger CSS flow height.
Dry layout, intrinsic height and the following sibling's position use the same
correction. A zero rounded advance is handled without division by zero.

`line_box_test.dart` adds ten tests. Its long Text matrix has 480 native cases
(20 types × four weights × three scales × 40/100 lines), using the original
single-line measurements already recorded in `visual-geometry.json`. It checks
exact expanding CSS flow and preservation of the pre-existing rounded-up path,
not CSS parity for all 480 cases. It adds no new original-browser specimens.
Footer cases cover 1/2/40/100 lines
at 100/160/200%; further cases cover soft wrapping after width/scale changes,
ellipsis, native empty/trailing lines, tight constraints and dry baseline/paint
offset agreement. Empty/trailing-line preservation is a native regression, not
a claim of CSS whitespace equivalence. Full package tests pass (458), as does
the root OAuth-launch regression. No credentials or backend data are used.

The engine cause is verified against Flutter 3.44.5's pinned Skia revision
`e9ed4fc9f1544c58d8a9347c1fc9471d8dd7c465`:
[`InternalLineMetrics::height()`](https://github.com/google/skia/blob/e9ed4fc9f1544c58d8a9347c1fc9471d8dd7c465/modules/skparagraph/src/Run.h#L480)
unconditionally rounds the line height;
[`TextWrapper`](https://github.com/google/skia/blob/e9ed4fc9f1544c58d8a9347c1fc9471d8dd7c465/modules/skparagraph/src/TextWrapper.cpp#L378)
accumulates that advance. Flutter already disables SkParagraph's separate
`applyRoundingHack` flag, which does not disable this height rounding. The
shared SDK was not changed.

An unconditional correction was **rejected after screenshot inspection**.
At 160% and 100 Footer lines, the native paragraph occupies 3400px. Shrinking
flow to the true CSS height of 3379.6875px made the tail overlap the following
marker. This path therefore retains its pre-change 3413.484375px flow, with an
explicit regression guard. Native advances that round up still have inaccurate
long-paragraph CSS flow. The 40-line/100% expanding case is corrected; the
100-line/160% case is deliberately not claimed as corrected.

The separate `test/tds_line_box_web_test.dart` exercises the foundation in Chrome
with the runner's Ahem test face. It is intentionally skipped by the VM runner;
original Toss faces are loaded in the package and device suites. Flutter 3.44.5's
browser test server intercepts URLs containing `host.dart.js`, including this
package's host-adapter module, and does not serve bundled fonts. The test uses a
narrow foundation import and no asset loads, without changing the application,
renaming its host module or patching the SDK. This browser engine check is not
an original-font visual comparison.

This is still a uniform-line adapter, not a general rich-text renderer. The
painted-baseline discrepancy above remains and grows with line count: restoring
flow alone cannot make every glyph align or guarantee clipping/hit-test parity
for a long paragraph. No per-line clipping/repainting or glyph scaling was added.

Final focused Android emulator and iOS Simulator runs passed
`integration_test/text_visual_geometry_test.dart` after the guard was applied.
Each checks normal/multiline typography, Footer presses/arrows/shadows and
40/100-line flow in light/dark at 100/160%. The earlier full native runs passed
12 scenarios per platform on the unconditional candidate, but screenshot review
rejected that candidate; those earlier runs are not evidence for the final guard.
Final 16 long-tail captures were inspected through
`.context/tds-multiline-final-tail-{android,ios}-{40,100}.png`; resized review
sheets are not used for pixel measurements. Rejected raw captures remain in
`.context/tds-multiline-candidate-{android,ios}-{40,100}-{light,dark}-{100,160}.png`.

Final logs: `.context/tds-multiline-safe-{package,root}-{tests,analyze}.log`,
`.context/tds-multiline-safe-web-tests.log` and
`.context/tds-multiline-safe-{android,ios}-drive.log`. Production targets were
restored to `lib/main.dart`; Android debug APK, ARM64 iOS Simulator and Web
builds passed sequentially. Build logs use the
`.context/tds-multiline-main-*` prefix. No physical device was used.
Reproduce the focused checks with:

```sh
cd packages/tds_mobile_flutter
flutter test --no-pub test/line_box_test.dart
cd ../..
flutter test --no-pub --platform chrome test/tds_line_box_web_test.dart
flutter drive --no-pub --driver=test_driver/tds_native_driver.dart \
  --target=integration_test/text_visual_geometry_test.dart -d <emulator-or-simulator-id>
```

### Multiline TextButton underline indices (2026-10-11)

`RenderTdsTextUnderline` used to discard zero-width selection boxes before
grouping lines. Flutter emits those boxes for explicit empty lines, so a label
such as `토스 Ag\n\n끝 gyp` painted its second underline in the empty middle
line. Leading empty lines shifted every underline up. The Android before-run
failed with a second-underline top of 42.8245616224649px instead of
64.1030616224649px at the medium/100% setting.

Empty line boxes now retain their line index but do not paint a stroke. A
zero-width box does not widen an existing visible run, including centered/RTL
labels. Nonempty range extents, native glyph shaping/painting, layout,
semantics and activation are unchanged. Underline advances now use the same
1/64px used CSS height as the outer line box, rather than accumulating the raw
`fontSize * 1.252` value. This does **not** correct the native glyph advances
described above.

The original browser check uses the pinned TextButton's existing label slot
with text and `BR` nodes, without modifying package code or CSS. Its computed
`white-space` is `normal`, so literal React string newlines collapse; they are
not equivalent to the explicit-break native stress fixtures. A leading BR and
two intervening BRs preserve line indices 1/3, while two intervening BRs alone
preserve indices 0/2. This distinction also applies when interpreting the
earlier native Footer newline stress tests: those tests do not establish
literal-string CSS whitespace parity.

`.context/tds-underline-long-source.json` records 36 original-only long-label
specimens: six button sizes × 100/160/200% × 40/100 explicit lines. Every
last-minus-first baseline advance equals `(count - 1) * usedLineHeight`.
For example, medium/160% uses 33.796875px; 100 lines have first/last baselines
26px and 3371.890625px. These measurements are separate from the existing
480-specimen `visual-geometry.json`; that original fixture is unchanged.
The content-only measurement scripts are
`.context/tds-underline-source-probe.js` and
`.context/tds-underline-measure.mjs`.

Five new package tests cover all six button sizes at 100/160/200%, leading and
intervening blank lines, blank-only/trailing lines, centered/RTL range extents
and semantics, ellipsis range preservation and 40/100-line used advances.
An exploratory ellipsis-width assertion was discarded: native
`LineMetrics.width` and selection range extents differ for trailing blanks and
ellipsis. The fix deliberately retains the existing range extents rather than
substituting that metric. The package suite passes 463 tests; both package and
root analyzers are clean. The root OAuth regression passes, and the two
browser-only tests are intentionally skipped on VM. Both Chrome foundation
checks pass using the Ahem test face, not original-font pixel comparison.

Focused Android/iOS original-font captures cover hard breaks, leading empty
lines, natural wrapping and activation in light/dark at 100/160%. All eight
captures were inspected through `.context/tds-underline-review-{android,ios}.png`.
The Android before/after raw-image differences occupy only the changed stroke
rows, with unchanged glyph pixels in this specimen. The compact review is
`.context/tds-underline-before-after.png`; cropped/resized sheets are for visual
review, not source/native pixel measurements. The original source crops are
`.context/tds-underline-source-{100,160}.png` and
`.context/tds-underline-source-leading-160.png`.

Fresh full native suites pass all 12 scenarios per platform on the retained
line-box guard plus this underline fix. The expanded focused suite passes two
scenarios per platform, including 100-line tail captures at 100/160%. The four
tails are reviewed in `.context/tds-underline-long-tail-review.png` and explicitly
marked unresolved: across 99 advances, native glyphs and CSS decoration differ
by 27.84375px at 17px font size and 20.109375px at 27px. Those tail assertions
record the current difference; they are not parity passes. After scrolling,
the fixture waits for a painted frame before capturing and checks that the
following blue marker is present in each raw screenshot used by the review.

An independent original-font Flutter Web fixture is built from
`.context/tds_underline_gallery.dart`, with four inspected light/dark/100/160%
captures at `.context/tds-underline-web-{light,dark}-{100,160}.png`. It has no
application, probe or font-fetch errors; only the known headless CPU-rendering
warning remains. This is a rendered smoke check, not a source/native pixel
threshold. Its entrypoint and build artifacts are confined to `.context/`.
Native logs are `.context/tds-underline-full-{android,ios}-drive.log` and
`.context/tds-underline-final-{android,ios}-drive.log`; the failing-before Android
run remains at `.context/tds-underline-before-android-drive.log`.

Final application builds pass sequentially from `lib/main.dart`: Android debug
APK, unsigned arm64 iOS Simulator debug build (Flutter configuration followed by
`xcodebuild`) and Flutter Web. `ios/Flutter/Generated.xcconfig` again records
`FLUTTER_TARGET=lib/main.dart`, so the native integration target is not left as
the application entrypoint. Build logs use the `.context/tds-underline-main-`
prefix (`android`, `ios-config`, `ios-build`, `web`). These are build checks,
not physical-device or real Toss-host validation. The auxiliary Web fixture
server was stopped after verification; the existing original-reference server
was left running.

This is a scoped underline correction, not a new text renderer. Long native
labels can still have separated/crossing glyphs and underlines because glyph
advances remain integer-rounded while the decoration follows CSS. Mixed-font
fallbacks, arbitrary rich spans and source whitespace behavior remain outside
this uniform-font adapter. No glyph scaling, clipped per-line repaint or shared
SDK change was introduced. The rounded-up `TdsLineBox` overlap guard is retained.
No export is newly marked parity-verified.

Reproduce the focused checks from the repository root:

```sh
flutter test --no-pub --platform chrome test/tds_line_box_web_test.dart
flutter drive --no-pub --driver=test_driver/tds_native_driver.dart \
  --target=integration_test/text_underline_test.dart -d <emulator-or-simulator-id>
```

### Rich keep-all and grapheme integrity (2026-10-11)

The shared `TdsKeepAllText` adapter previously transformed only `Text.data`.
An ordinary `Text.rich` tree therefore lost the original inherited
`word-break: keep-all` across nested color/link spans. The medium TextButton
at 160% and 130px width produced `자세한 내용 / 을 확인하기`, while the original
produced `자세한 / 내용을 / 확인하기`. A package regression and an Android
failing-before run reproduce this discrepancy.

The adapter now transforms contiguous ordinary TextSpan text as one run, then
redistributes joiners to the original span boundaries. It keeps styles,
recognizers, pointer callbacks, cursor, locale, spell-out settings, accessibility
labels and identifiers. Source objects are not mutated; unchanged subtrees retain
identity. WidgetSpan and custom span subclasses are opaque boundaries and remain
unchanged, rather than losing their custom behavior through cloning.

Joiners are inserted only between extended grapheme clusters. Previously the
decomposed spelling `한글` received joiners between its constituent jamo,
visibly separating them. It now shapes as `한글`, without normalizing or replacing
the caller's string. Package tests compare composed/decomposed original-font
advances at 17/27/34px. Tests also cover combining accents, BMP/supplementary
variation selectors and graphemes crossing valid TextSpan boundaries. Each
TextSpan still must contain valid UTF-16, as required by Flutter; invalid
individual surrogate halves are not repaired by this adapter.

Rich accessibility labels use the original text, never inserted joiners.
Ordinary selectable text now retains keep-all through a selection-container
adapter that maps layout UTF-16 offsets back to source offsets. Previously plain
selection copied the injected U+2060 characters, while rich text bypassed
keep-all to avoid that corruption. Both paths now return the original selected
substring, including partial/reversed ranges, genuine source joiners, decomposed
graphemes and whitespace. Selection content lengths compose correctly with other
text widgets. Flutter still owns hit testing, handle layers, selection paint,
word/paragraph gestures and context-menu actions. The original span objects
remain unchanged. Opaque custom spans and WidgetSpan subtrees bypass rewriting
when selectable, because their content/offset model is not known here.

At this earlier checkpoint, selectable text did not receive width-dependent
emergency correction. The newer selectable-emergency follow-up below supersedes
that limitation for ordinary TextSpan trees. Arbitrary rich spans, the full
gesture/accessibility matrix and CSS whitespace equivalence are not established.

`word-break.json` contains 108 new original-browser specimens: six TextButton
sizes × three font scales × three widths × plain/nested color-only children.
The content-only probe is `.context/tds-rich-keepall-source.js`, run against the
pinned `text-buttons` fixture with `variant=clear`. Only the fixture host width
and label contents change; package code and stylesheets do not.
All 108 specimens now match original line membership. The ten former failures
were reproduced with strict source expectations in
`.context/tds-emergency-wrap-before.log`. Before emergency splitting an oversized
word, the adapter now uses its preceding natural space. The original and native
result is `자세 / 한 / 내용 / 을 / 확인 / 하기`, not the former native
`자세 / 한 내 / 용을 / 확인 / 하기`.

Another 24 independently measured original cases cover mixed Korean/Latin words
at 60/90/130/210px and 40px semibold, each executed for plain and nested-color
forms (48 additional executions). Latin fragment endings are reshaped after
the native full-context break. At 90px, the `Latin` prefix inside
`LatinTextCombined` measures 89.921875px because of nT kerning, but standalone
`Latin` measures 93.6328125px. The source backtracks to `Lati`. It does not then
greedily expand other lines: at 60px the source keeps `La`, even though reshaped
`Lat` would fit. The tests cover both boundaries. The capture probe explicitly
waits for `document.fonts.load`; the font-ready recapture exactly matches the
earlier 24 rows. No Flutter-derived expectation replaced source measurements.

Width-dependent rewrites use cloned spans in a render proxy before its normal
RichText child lays out. The supported synchronous layout callback updates the
child; the paragraph does not mutate itself during layout. Intrinsic/dry
measurements use independent TextPainters and do not mutate live text. Width
changes restore source spaces. Justification, nowrap, non-finite widths and
opaque span trees retain their native path. This is a line-membership contract,
not pixel, baseline or whole-library parity.

Fifteen rich/emergency package tests cover the source matrices, grapheme
boundaries and shaping, metadata, links/pointer callbacks, source identity,
custom/widget boundaries, width-only relayout and dry/intrinsic purity. Nine
selection tests cover actual Copy-menu dispatch, original content/range mapping,
multiple labels, replacement/empty/disabled scopes, opaque spans and link/word
selection. This earlier package checkpoint passed 490 tests with a clean analyzer.
The earlier separate Chrome probe passes
two glyph-independent layout-string/semantics tests. Its Ahem face does not
provide Korean glyph advances, so an exploratory hard-coded CJK height assertion
was discarded; it is not original-font wrapping evidence. The probe is saved at
`.context/tds_word_break_web_test.dart`; Flutter's browser runner requires placing
it under `test/` while running, and the temporary test copy was removed afterward.

At the earlier rich/grapheme checkpoint, the full Android emulator and iOS
Simulator regression suites each passed 12 scenarios. Its focused reruns, after
the then-current selectable-rich guard, each passed one scenario covering
plain/rich labels, activation and light/dark at 100/160%.
All eight original-font captures were regenerated and inspected via
`.context/tds-word-break-review-{android,ios}.png`.
The compact `.context/tds-word-break-before-after.png` shows corrected nested
wrapping and NFD Hangul shaping on Android/100%. Cropped/resized sheets are visual
review aids, not pixel-comparison inputs. An independent actual-font Web fixture
has four inspected captures at `.context/tds-word-break-web-{light,dark}-{100,160}.png`;
its accessible text contains no injected joiners. These are rendered smoke
checks, not pixel parity thresholds.

The Web fixture loads the bundled Toss faces, but also requests fallback Noto
fonts for the decomposed sample and reports that it cannot find coverage for
every missing character. The labels visibly compose correctly after the fix;
that does not establish original-font glyph identity for the fallback path.
The headless CPU-rendering warning also remains. Both warnings are retained in
`.context/tds-rich-keepall-web-console.log`; no extra font was bundled to conceal
the difference.

Reliable logs are `.context/tds-rich-keepall-package-complete-{tests,analyze}.log`,
`.context/tds-rich-keepall-chrome-verified-tests.log`,
`.context/tds-rich-keepall-full-{android,ios}-drive.log`,
`.context/tds-rich-keepall-final-{android,ios}-drive.log` and the original failing
Android run `.context/tds-rich-keepall-before-android-drive.log`. The root OAuth
regression passes, with two existing browser-only tests skipped on the VM, and
the root analyzer is clean; logs are `.context/tds-rich-keepall-root-{tests,analyze}.log`.
The earlier `package-tests.log` was written by overlapping diagnostic runs and
is not verification evidence; the clean final run uses the `package-complete`
prefix. Earlier test-harness failures are not attributed to the implementation.

The earlier rich/grapheme checkpoint's application builds passed sequentially
from `lib/main.dart`: Android debug APK, unsigned arm64 iOS Simulator debug build
(Flutter configuration followed by `xcodebuild`) and Flutter Web. That checkpoint
restored `FLUTTER_TARGET=lib/main.dart` in `ios/Flutter/Generated.xcconfig`.
These historical builds do not verify the later emergency/selection changes.
Build logs use the `.context/tds-rich-keepall-main-`
prefix (`android`, `ios-config`, `ios-build`, `web`). These are build checks,
not physical-device or real Toss-host validation. The auxiliary Web fixture
server on port 5183 was stopped after verification; the existing
original-reference server on port 5182 was left running.

This fix does not change line heights, later native glyph baselines, underline
geometry, arrow painting or shadows. The long-line drift and rounded-up overlap
guard described above remain. Custom spans, full Unicode line-break coverage,
rich-font fallback/RTL matrices and complete selection behavior are not parity-verified.
No export is newly marked parity-verified. Google auth and disabled Kakao are
unchanged.

Reproduce the permanent regressions:

```sh
cd packages/tds_mobile_flutter
flutter test --no-pub test/word_break_test.dart test/word_break_rich_test.dart \
  test/word_break_selection_test.dart
cd ../..
flutter drive --no-pub --driver=test_driver/tds_native_driver.dart \
  --target=integration_test/text_word_break_test.dart -d <emulator-or-simulator-id>
```

### Emergency wrapping and selection follow-up

The latest focused native suite passes three scenarios on both Android and iOS:
the earlier rich/grapheme cases, oversized Korean/Latin endings, and selectable
plain/rich labels in light/dark at 160%. The Copy action is dispatched through
the actual native selection menu callback, with only the platform clipboard
channel captured so no simulator/host clipboard is overwritten. Both platforms
produce the original source string. This verifies native layout and Flutter
selection contracts, not physical-device handles or real OS clipboard services.

All eight latest native selection captures were inspected through
`.context/tds-selection-review-{android,ios}.png`. Selection highlighting is
visible for both plain/rich labels in both themes. The fixture explicitly owns
and focuses the SelectionArea's FocusNode, then schedules an additional raster
frame before capturing; it does not alter production selection painting. The
latest focused logs are `.context/tds-selection-final-{android,ios}-drive.log`.

After the focus/capture adjustment, the complete native regression suite was
rerun on both engines. Both passed all 12 scenarios, including existing mixed
input order, Footer descendant color/context lifecycles, arrows, shadows and
text geometry. Latest full-suite logs are
`.context/tds-selection-full-{android,ios}-drive.log`. Driver teardown adds one
to Flutter's displayed counter; it is not a thirteenth application scenario.
Android's slow-frame/IME diagnostics and the driver's long-request notices are
retained in the logs, not reclassified as passing performance/IME coverage.

All 12 emergency captures were inspected through
`.context/tds-emergency-review-{android,ios}.png`. A separate actual-font Web
fixture asserts the same three line-membership cases for plain/rich labels in
light/dark. All six pages report PASS, preserve original accessible text and
retain button activation. The six captures were inspected through
`.context/tds-emergency-review-web.png`. These cropped/resized sheets are visual
review aids, not pixel-diff inputs. The Web run reports the headless CPU-rendering
warning, but no missing-font-coverage warning for these six cases. The earlier
NFD fallback warning described above is not reclassified as fixed.

`test/tds_selection_web_test.dart` adds two permanent Chrome copy/replacement/
disabled-scope checks. Together with the existing line-box/underline browser
tests, all four pass. They deliberately import only the foundations to avoid
the unrelated Flutter browser test-server `host.dart.js` collision and use Ahem,
not original-font pixel expectations. Native captures and the actual-font Web
fixture provide separate rendering evidence.

The reliable latest package logs are
`.context/tds-selection-final-package-{tests,analyze}.log` (490 tests, clean
analyzer). Chrome output is `.context/tds-selection-chrome-tests.log`.
The latest root analyzer and Google OAuth launch regression also pass, with
logs `.context/tds-selection-final-root-{analyze,tests}.log`. The OAuth test is
local and does not authorize a real account or change Supabase data.
The failed-before selection proof is `.context/tds-selection-before.log`.
Temporary selection-harness failures were traced to nested registrars queuing
post-frame callbacks from idle microtasks; `tester.pump()` without a scheduled
frame does not flush those callbacks. The permanent tests schedule and flush
the nested registrar frames before directly dispatching selection events.
They do not change expected text to accommodate the implementation.

The final application builds for this emergency/selection checkpoint all passed
sequentially from `lib/main.dart`: Android debug APK, unsigned arm64 iOS Simulator
and Flutter Web. Logs are
`.context/tds-selection-main-{android,ios-config,ios-build,web}.log`.
The Simulator binary was checked with `lipo` and is arm64;
`ios/Flutter/Generated.xcconfig` records `FLUTTER_TARGET=lib/main.dart`.
These build checks do not establish pixel, physical-device or Toss-host parity.

An initial selectable emergency-wrap experiment was **not retained**. Its
character-extension regression expected `LatinTextComb` but selected
`LatinTextCombined 다음`. The candidate and its test are preserved only under
gitignored `.context/tds-selectable-emergency-candidate{,-test}.dart`, with the
failure recorded in `.context/tds-selectable-emergency-candidate.log` and
`.context/tds-selectable-emergency-character-probe.log`. At that checkpoint the
root cause was unresolved. Production `word_break.dart` was restored to the
earlier verified implementation; its content hash matched those historical
application build records. The restored package suite passed all 490 tests:
`.context/tds-strict-restored-package-tests.log`. No failing experimental test
or diagnostic logging was retained in the package. The follow-up below is a new
implementation and verification, not a retroactive claim that this candidate passed.

Post-restoration package/root analyzers are clean; the local Google OAuth launch
regression passes one test and the Chrome regressions pass all four tests again.
Fresh logs are `.context/tds-strict-restored-{package,root}-analyze.log`,
`.context/tds-strict-restored-root-tests.log` and
`.context/tds-strict-restored-chrome-tests.log`. Wrapper/coverage checks, Dart
formatting and `git diff --check` also pass. These checks confirm the retained
checkpoint, not satisfaction of the strict completion gate.

### Selectable emergency wrapping and rebuild lifecycle

Ordinary selectable TextSpan trees now use the same emergency-wrap layout as
non-selectable text. Source offsets are mapped across both inserted keep-all
joiners and width-dependent separators. Genuine source controls, spaces and
newlines remain in Copy. Word/paragraph selection and reversed dragging use
original source boundaries rather than treating layout-only newlines as content.
Opaque/custom/WidgetSpan selectable trees still bypass rewriting.

The rejected character-extension case is now reproduced and fixed: the exact
right edge of a selectable rectangle is excluded by `Rect.contains`. A synthesized
caret on that edge was treated as a drag beyond the paragraph and selected the
suffix. Synthesized coordinates are kept inside the boundary; genuine zero-width
source controls are disambiguated with logical character movement. No Flutter
SDK file or original reference expectation was modified.

Equivalent Text rebuilds dispose native selection fragments before layout.
The adapter caches original offsets before that disposal and restores them after
registration. Clearing during the gap previously unregistered a child while its
parent was iterating the live list. Clear now traverses a snapshot; logical content
length/presence stays stable throughout layout-only fragment replacement. Clear
cancels restoration and deferred input. Source-based select-all/character commands
return their logical result immediately; commands needing native fragments retain
their order until registration finishes. Scheduled work is invalidated by source
replacement, newer events and disposal.

`word_break_selection_emergency_test.dart` adds 18 tests. They cover all 108 pinned
TextButton specimens and all 24 mixed-language specimens in plain/rich forms;
original Copy/ranges; width-only and rebuilt reflow; inherited font changes;
forward/reverse selection; clear and select-all during rebuilding; ordered
character input and deferred word/character ordering; real zero-width controls
and graphemes; word/paragraph dragging;
and SelectionArea long press. The source matrices remain unchanged.

Latest automated checks on this implementation:

- Package suite: 508 passed; package/root analyzers clean.
- Root Google OAuth-launch regression: one passed, with no real authorization.
- Chrome: seven passed across `tds_line_box_web_test.dart` and
  `tds_selection_web_test.dart`. Tests distinguish SelectionArea's synchronous
  public callbacks from direct child-delegate content/range updates, which do
  not invoke that callback in Flutter. Clipboard writes remain mocked.
- Logs: `.context/tds-selection-emergency-final-package-{tests,analyze}.log`,
  `.context/tds-selection-emergency-final-root-{tests,analyze}.log` and
  `.context/tds-selection-emergency-final-chrome-all.log`.

Android emulator and iOS Simulator each pass four focused scenarios and all
12 full native regression scenarios on the same production source. The fourth
focused scenario uses real long press to select `LatinTextCombined`, checks
recreated Text at 90→60→240→90 widths, asserts original 60px/90px line membership,
then invokes the actual Copy menu with only the clipboard platform call mocked.
It also tests clear and select-all/ordered character commands during rebuilding.
The full suites retain mixed input order, descendant/footer color propagation,
reentry/retargeting, original-font geometry, arrows and shadow assertions.
Logs: `.context/tds-selection-emergency-final-{focused,full}-{android,ios}.log`.
Driver teardown adds one displayed result; it is not an application scenario.

The final native light/dark, plain/rich captures show only the source Latin word
highlighted after emergency wrapping. All eight raw captures and both review
sheets were inspected:
`.context/tds-native-selection-emergency-{android,ios}-{light,dark}-{plain,rich}.png`
and `.context/tds-selection-emergency-review-{android,ios}.png`.
The cropped/resized sheets are visual review aids, not pixel-diff evidence.

The browser runner's Ahem request does not prove original-font glyph geometry.
The separate release-Web fixture explicitly loads original 400/600 Toss fonts.
Light and dark runs pass the original 90px and 60px line-membership assertions,
whole-word selection, rebuilt 90→60→240→90 reflow, source offsets and original
selected content in both plain/rich forms. Both captures were visually inspected:
`.context/tds-selection-emergency-web-{light,dark}.png`. The fixture initially
inherited Material's 0.25px body letter spacing, whereas the original computed
style is 40px/600/Toss Product Sans/normal spacing/50.08px line height. Moving the
fixture's TDS provider inside Scaffold removed that harness contamination without
changing original expectations or forcing application text to ignore caller styles.
The browser reports CPU-only CanvasKit rendering; that is recorded, not hidden
or treated as pixel equality. These captures are not image-diff certificates.

Main application builds also pass on the same production implementation:
Android debug APK, unsigned arm64 iOS Simulator and Flutter Web, run sequentially.
`ios/Flutter/Generated.xcconfig` targets `lib/main.dart`, and `lipo` confirms the
Simulator executable is arm64. Logs use the
`.context/tds-selection-emergency-main-{android,ios-config,ios-build,web}.log`
paths. The quiet Xcode build returned exit code 0; its log may be empty.
The temporary gallery server on port 5183 was stopped after verification; the
existing original-reference server on port 5182 was preserved.

Native real-host behavior, every rendering pixel, arbitrary spans and complete
gesture/accessibility matrices remain outside these claims.

### Fallback-font underline line grouping

`RenderTdsTextUnderline` previously grouped selection boxes by their tight top
coordinate. One logical line can contain multiple fallback fonts with different
glyph bounds. On the iOS Simulator, `A🙂B` produced Latin boxes at approximately
0.7–22px and an emoji box at -2.9–24px. The renderer treated these as separate
lines and painted two underlines. Hanja and other emoji sequences reproduced
the same grouping problem.

The renderer now requests `BoxHeightStyle.max`, which gives every run on the
same line a shared vertical extent. Horizontal range boxes remain tight.
Zero-width newline boxes still reserve their line indices without widening a
visible underline. This does not change glyph layout/painting, text selection,
the existing multiline flow guard or the source's undecorated ellipsis.
The [Flutter API contract](https://api.flutter.dev/flutter/dart-ui/BoxHeightStyle.html)
explicitly distinguishes per-run `tight` heights from shared per-line `max`
heights.

Two permanent `text_button_test.dart` regressions reproduce unequal run heights
and preserve leading/intervening empty lines across LTR/RTL and start/center/right
alignment. The VM test runner does not load system fallback fonts, so these
tests deliberately use different explicit run sizes to exercise the geometry.
They do **not** claim mixed-size typography equivalence. The first regression
fails before the production change with two rectangles instead of one; all 18
TextButton tests pass afterward. Logs:
`.context/tds-fallback-underline-unit-{before,after}.log`.

The focused native fixture `integration_test/text_underline_test.dart` now has
three scenarios. Its new actual-font scenario covers `A🙂B`, `토스 😀 글자`,
`A❤️B`, `A漢B`, family/skin-tone emoji, intervening empty lines and a leading
empty line. Underline counts, original CSS line indices and activation pass
on Android and iOS in light/dark at 100/160%. The preexisting explicit-break
and long-baseline-drift scenarios also pass. Driver teardown adds one displayed
test result; it is not a fourth application scenario. Logs:
`.context/tds-fallback-underline-focused-{android,ios}.log`.

The pinned React TextButton content-only probe shows a single underline for
`A🙂B` in all six sizes, without package/CSS changes. An ellipsis probe also
confirmed that the original does not decorate the ellipsis; no speculative
ellipsis change was applied. Explicit native newlines remain stress fixtures,
not evidence that literal React string newlines bypass normal CSS whitespace
collapse. Original probe/capture:
`.context/tds-fallback-underlines-source.js` and
`.context/tds-fallback-underlines-source-ios.png`.

The before/after review image
`.context/tds-fallback-underline-before-after.png` visibly removes the duplicate
stroke. All eight native light/dark and 100/160% captures were reviewed via
`.context/tds-fallback-underline-review-{android,ios}.png`. These are resized
visual aids, not source/native pixel-diff certificates. System emoji/fallback
glyph identity and every arbitrary span/RTL combination remain unverified.

On the current production implementation, the package suite passes 510 tests,
root/package analysis is clean, the root mocked Google OAuth regression passes,
and the combined Chrome foundation/selection suite passes seven tests. Logs:
`.context/tds-fallback-underline-package-{tests,analyze}.log`,
`.context/tds-fallback-underline-root-{tests,analyze}.log` and
`.context/tds-fallback-underline-chrome-tests.log`.

The full native suite also passes all 12 application scenarios on each platform,
including input ordering, descendant colors, tooltip lifecycles, original-font
geometry, arrows and Footer shadows. Teardown again adds a displayed result.
Logs: `.context/tds-fallback-underline-full-{android,ios}.log`.

The release Web fixture explicitly loads the bundled Toss 500 face, then uses
the platform's fallback path for characters that face does not contain. After
network idle and two further animation frames, its exported verification
callback resamples the actual render geometry. All eight specimens pass in
light/dark at 100/160% Android mobile-typography profiles (32 checks); all four
captures were viewed. Evidence:
`.context/tds-fallback-underline-web-{light,dark}-{100,160}.{json,png}`.
Console logs at the corresponding `-console.log` paths contain both the known
CPU-only CanvasKit warning and a warning that Noto cannot cover all missing
characters. These are **not** suppressed or treated as proof of fallback-glyph
identity. There were no application exceptions in these captures. Geometry
success does not establish complete Unicode rendering or original pixels.

Main application builds pass sequentially for Android debug APK, unsigned arm64
iOS Simulator and Flutter Web. `ios/Flutter/Generated.xcconfig` was restored to
`FLUTTER_TARGET=lib/main.dart`, and `lipo` confirms the Simulator binary is arm64.
Logs: `.context/tds-fallback-underline-main-{android,ios-config,ios-build,web}.log`.
The quiet Xcode build returned exit code 0 with an empty log. Wrapper/coverage
checks still report 1,038 partial mappings, with no whole-export parity claims.

This fixes logical underline grouping only. Later-line glyph/underline drift,
rounded-up long Footer flow, complete mixed-font pixels, React runtime contracts
and real Toss-host behavior remain strict completion blockers.

### Cluster-boundary keep-all and joining controls (2026-10-11)

The keep-all adapter lost the preceding CJK classification when a grapheme ended
in a BMP combining mark or variation selector. A following Latin letter/number
could therefore start a new line, unlike the original. `_keepAllOffsets` now
looks behind exactly one BMP mark, retaining the original single-code-unit rule.
It does not treat a sequence of marks or a supplementary selector as its base
letter. This is backed by actual 2.5.1 TextButton measurements and the matching
browser's [ShouldKeepAfterKeepAll implementation](https://github.com/chromium/chromium/blob/145.0.7632.6/third_party/blink/renderer/platform/text/text_break_iterator.cc#L139).
No joiner is inserted inside an extended grapheme, even across styled spans.

The emergency-word matcher also incorrectly combined normal break opportunities
after such clusters into one oversized word. It now retains unjoined CJK cluster
boundaries, and can start an oversized suffix there without forcing its preceding
short cluster onto another line. Caller-supplied U+2060 still joins the word.
ZWJ/ZWNJ are retained when finding candidate words; ZWJ follows UAX #14 LB8a and
prevents a normal break after its cluster, whereas ZWNJ does not. This fixes, for
example, the original 40px/90px split `앞 / 한AB / C 뒤` when the Hangul syllable
ends in U+FE0F or ZWJ, while U+E0100 instead permits `앞 한 / ABC / 뒤`.

`reference/word-break.json` retains 176 new plain/nested source specimens at four
widths, including numeric suffixes, oversized Korean/Latin suffixes and genuine
source joiners. Of these, 164 have matching full-text line membership. Each is
checked in the VM both with and without selection (328 comparisons), including
exact copied content and source UTF-16 lengths. New tests cover reverse ranges,
equivalent label rebuilds at 90/130/210px, character-wise selection across source
graphemes and genuine source controls. Existing span metadata and emergency-wrap
tests still pass. Measurement helpers now use whole graphemes and line-wide
vertical boxes so zero-width marks cannot disappear from the expected text.

The other 12 specimens remain explicitly marked `knownDifference`, not accepted
exceptions. The original Chromium renderer actually omits the visible suffix for
three strings when ZWNJ alone is in a color-only span. Both DOM-content probes and
fresh keyed mounts through the original React props reproduce the same omission.
The native adapter still displays the complete string. Screenshots
`.context/tds-cluster-zwnj-{source,react}.png` were inspected; the omitted text is
still in the original DOM, but its ranges have zero width. Those rows are retained
as failed equivalence evidence, not silently regenerated from native output.

A broader 312-specimen diagnostic also agrees exactly between the DOM probe and
fresh React mounts. Native VM line comparisons still differ in 48 specimens:
the 12 suffix-omission rows above and 36 combining/fallback/shaping rows. Several
probed accents, tone marks and Hanja are absent from the original bundled font's
cmap; U+0326 is present and still has a separate shaping/advance discrepancy.
These failures remain in `.context/tds-cluster-boundary-joincontrols-after.log`.
The original reference is `.context/tds-cluster-boundary-react-v6.json`; its input
probe is `.context/tds-cluster-boundary-source.js`. No character normalization,
fallback-font substitution, hidden suffix workaround or source CSS/package patch
was used to turn these failures into passes.

Verification on the new code:

- Package 514 tests and 46 focused wrapping/selection tests passed; root/package
  analysis is clean. Root mocked Google OAuth test and seven Chrome
  line-box/selection tests passed, without actual authentication or data writes.
- Android and iOS focused suites each passed five scenarios (driver teardown adds
  one result). The added scenario verifies original-font line membership, width
  changes and Copy on five selector/control strings, plain/rich and light/dark.
  Both host settings resolve the measured text size to 40px. All 44 focused
  captures were reviewed in `.context/tds-cluster-review-{android,ios}-*.png`.
- The full Android and iOS suites each passed all 12 application scenarios
  (plus driver teardown). All 156 captures per platform were inspected through
  `.context/tds-cluster-full-review-{android,ios}-1.png` through `-13.png`.
  These resized contact sheets check for visible regressions, not exact pixels.
- The actual-font Web gallery checks 352 samples per theme. Both light and dark
  pass all 328 comparable samples and all 352 copy/content checks. The 24 known
  mismatches per theme are the 12 original suffix-omission rows in both selection
  modes; the exported result deliberately has `strictPassed: false`. Both Web
  captures were viewed. CPU-only rendering and Noto missing-character warnings
  remain in the browser logs; this is not a glyph-completeness or pixel certificate.
- Main-app builds passed sequentially: Android debug APK, unsigned arm64 iOS
  Simulator, then Web. The generated iOS config was restored to
  `FLUTTER_TARGET=lib/main.dart`; `lipo` confirmed the Simulator executable is
  arm64. This does not verify the previously failing x86_64 Simulator build.
- Logs use `.context/tds-cluster-boundary-{package,root}-{analyze,tests}.log`,
  `tds-cluster-boundary-chrome-corrected.log`,
  `tds-cluster-boundary-native-{android,ios}.log`,
  `tds-cluster-boundary-full-{android,ios}.log`,
  `tds-cluster-boundary-main-{android,ios-config,ios-build,web}.log` and
  `.context/tds-cluster-web-{light,dark}.{json,png}`.

The earlier long-paragraph baseline/flow guard remains untouched. React DOM/ref
contracts, real Toss host behavior and the strict completion gate remain unmet.
No export was promoted to parity-verified, and no commit/push was performed.

### Component wrapper metadata audit

`tool/tds_source/wrappers.mjs` reads the same pinned original ESM entrypoint as
the browser reference and checks its SHA-256 against the inventory. All 56
declared optional `ComponentWithAs.id` fields are absent (`undefined`) at runtime.
All seven `.type` fields are React memo wrappers around forwardRef objects.
No source component is assigned an invented ID or rendered/mutated by this audit.

`component-wrappers.json` records these source facts. `native-wrappers.json`
records partial native adaptations: the existing nullable `TdsComponentWithAs.id`
builder metadata and seven unwrapped native constructor tear-offs. Three tests
check source shape, optional metadata vs native keys, constructor props, callbacks
and keys. This removes the 63 unmapped inventory entries, not 63 visual bugs.
There are now 1,038 partial mappings and no unmapped entries; zero exports are
whole-component parity-verified. React object reflection, mutable static metadata
and memo render-call counts are not Flutter contracts.

```sh
node tool/tds_source/wrappers.mjs --check
node tool/tds_source/coverage.mjs --check
flutter test --no-pub --platform chrome test/tds_line_box_web_test.dart \
  test/tds_selection_web_test.dart
```

### Button loading lifecycle and keyboard follow-up (2026-10-11)

A fresh source audit found six concrete differences: ordinary Button committed
Enter on release instead of keydown/repeat and incorrectly showed pointer
press visuals for keyboard input; disabled-loading painted a dimmer;
loading dots and glow disappeared immediately on exit; and the label skipped the
source's 100ms return delay. The new `test/button_lifecycle_test.dart` initially
failed all seven source-contract cases. The corrected implementation also tests
custom child hit testing, disposal during the label delay, and a disabled state
interrupting that delay.

The unchanged `@toss/tds-mobile@2.5.1` was exercised in Chromium using
`?family=button-lifecycle`. Trusted Enter down/repeat/up followed by Space
down/up produced click totals 1/2/2/2/3. Holding Enter retained scale 1; the
native regression initially failed at scale .96 before separating pointer visuals. Both fill and weak disabled-loading
states have zero dimmer opacity. During exit, the original retains the dots and
glow while the label stays at zero; after exit the dots are removed, glow is
zero and label is one. Reproduce the state checks with
`tool/tds_source/browser-probes/button-lifecycle.js`. Local original-only
observations are in `.context/tds-button-original-observations.json`.

Native fixes retain dot instances through interrupted exits, cancel stale label
timers, fade the glow from its current opacity and stop animation tickers after
exit/disposal. The decorative glow ignores hit testing while remaining mounted.
TdsButton's public constructor is unchanged. The internal pressable has an
optional keyboardPressEffect flag, defaulting to its existing behavior. Enter-repeat behavior also applies to
other controls that explicitly opt into `activateOnEnterDown`.

Final validation: 525 package tests passed (11 Button lifecycle regressions),
seven Chrome selection/line-box tests passed, root application regression passed,
`flutter analyze` reported no issues, and the standalone gallery web release
build passed. The pinned-source inventory/wrapper checks and original-browser
Button probe passed. The source-tool lockfile was repaired so `npm ci` also
passes in the source workspace without changing pinned library versions.

This does not
resolve the documented multiline renderer discrepancy, arbitrary React DOM/ref
contracts, real Toss-host integration, or the full component/state pixel matrix.
Android/iOS device tests were not rerun for this follow-up.

## Next required work

1. Finish existing public prop/compound contracts, motion interruption,
   native text selection/context menus and nested modal focus restoration.
2. Finish remaining compound contracts beyond their current partial mappings.
   BottomCTA compounds, FontScaleLimit Web/Mobile, ListRow.Typography and
   paragraphVariables and all asset-frame constant descendants now have audited
   partial mappings. PortalContext Provider/Consumer now have nullable native
   target adapters; arbitrary React context and wrapper metadata still differ.
   BottomCTA's DOM containerStyle/ref and remaining Button props, arbitrary
   child sizing and device keyboard/safe-area behavior are not fully equivalent.
3. Audit native type/utility/hook adapters without treating documented DOM-only
   differences as accepted equivalence. Real host security and toast integrations remain unimplemented;
   local toast persistence and an injected host bridge are now tested;
   native accessory fallback needs its full placement/lifecycle matrix. The user
   confirmed there is no host SDK/bridge documentation or test app. Self-validation
   uses injected contract tests, platform haptic channel tests and local engines;
   it cannot establish real Toss host/security behavior.
4. Expand paired fixtures to error/disabled/pressed/loading, multiline, all
   sizes, all scales, dark/light and frame-by-frame motion. Record exact
   per-component differences; nonzero differences remain open gaps under the
   strict criterion, not an aggregate similarity percentage or an accepted tolerance.
   All 20 typography types now have source-backed first-baseline/flow checks;
   correct each later native line advance together with rounded-up multiline
   flow without breaking selection, semantics, glyphs/diacritics or mixed spans,
   then expand the measured visual matrix.
5. Extend Bubble to custom ancestor/mixed-span cases; expand WikiText observer
   timing, transformed/nested-scroll and rich-font/RTL matrices; finish other
   anchor/ancestor clipping, third-party menu trigger adapters and ListRow's
   arbitrary asynchronous event-loop boundaries. Child/ancestor raw input,
   pointer/controller batches and post-release click ordering now have scoped
   browser-backed regressions, as do ListFooter descendant registration and
   lazy/advanced timeline restart, RGB rounding and repeated partial context
   reversion. Imperative microtask chains versus discrete input also have scoped
   regressions. Independent press/release cleanup, clocks, target lists and
   original semantic/serialization identities now have scoped regressions.
   Undefined next-level adaptive colors, nested Footer selector ownership,
   overlapping release saves and inner-to-outer activation now also have scoped
   source-backed tests. Exhaustive nested/context interleavings, live owner
   replacement/reparenting, arbitrary CSS literal spelling, rich text and
   React concurrent scheduling remain outside that scope.
   Blink/shine live size/theme, blink exit/reentry and synchronous imperative
   batches also have scoped browser-backed regressions. Native
   multiline WikiText, TDS nested menu activation and source ListRow timelines
   now have scoped tests.
   Tooltip clipped paths are now ported;
   menu typeahead is not an original feature and must not be invented.
6. Test real Android/iOS touch, keyboard, VoiceOver/TalkBack, safe areas and
   navigation/OAuth return handling. Repeat-build font hashes are stable in the
   current environment; other fonttools/platform versions remain unverified.

Google auth is preserved. Kakao stays commented out.
