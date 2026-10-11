# TDS Mobile native Flutter port

Project-local port of `@toss/tds-mobile@2.5.1` and
`@toss/tds-mobile-ait@2.5.1` for Android, iOS and Web. No React runtime or WebView
is used in the application. React is used only by the reference fixture.

## Status: in progress, not whole-library parity

The source inventory contains **416 top-level exports** and **622 recursive
members**. The latter include namespace types and wrapper metadata, not 622
visual components. The current ledger has native counterparts for all 416
top-level exports: 108 runtime exports, 27 hooks, 22 utilities and 259 types.
**All 416 mappings are partial, not parity-verified.** All 622 recursive members
also have partial native mappings. This includes explicit adaptations for 56
optional component IDs (absent in the original runtime) and seven React memo
wrappers, not 63 additional widgets. No inventory entry is left unmapped.
These counts are not a completion or visual-similarity percentage.

The user explicitly retained **100% pixel, API and Toss-host equivalence** as
the completion criterion. Documented native adaptations are not an accepted
substitute. The current implementation does not meet that criterion: React
DOM/ref/runtime contracts are not reproduced, real Toss-host behavior cannot
be verified without its implementation or reference environment, and measured
text/layout differences remain. See the [verification checkpoint](reference/verification.md)
for the release gate and scoped evidence; passing tests or builds does not clear it.

The authoritative per-API record is [native-coverage.json](reference/native-coverage.json).
It records native symbols, source files, scoped test evidence, differences and
remaining work. Its inputs are `native-mapping.json`, `native-families.json`,
`native-additions.json`, `native-completion.json` and generated
`native-constants.json` / `native-wrappers.json`; the completion filename does not
mean the migration is complete.
No empty placeholder is counted as implemented. Passing a widget test does not
prove visual, motion or whole-component parity.

`component-wrappers.json` is measured directly from the pinned original ESM
runtime. `TdsComponentWithAs.id` is optional immutable builder metadata, not a
DOM id, Flutter Key or semantics identifier. The unwrapped constructors for
SearchField, FullSecureKeypad and Post headings/paragraph replace React's
`memo.type`; Flutter does not expose or reproduce React memo/forwardRef objects
or render-call counts. These are documented framework adaptations, not verified
JavaScript reflection parity.

Implemented subsets include theme/typography/fonts, buttons, badges, checkbox,
switch, assets, loader, top/bottom information, fields, tab/segmented controls,
numeric spinner, progress bar, modal/dialog controllers, toast/controller,
list rows/header/footer/table rows, sheets/navigation/BottomCTA, grids and board
rows, slider/rating/selectors/search, agreements/keypads/date/wheel controls,
charts/skeletons/results/posts, anchored tooltips/WikiText/menus/highlights,
video assets and native host/layout/type adapters. Several compound contracts
and most full visual/motion/accessibility matrices are still incomplete.

## Integration

The root app already references this package using a local path dependency.
Use `package:tds_mobile_flutter/tds_mobile_flutter.dart`. Keep a Navigator/Overlay
in the widget tree for editable fields, modal routes and toasts:

```dart
WidgetsApp(
  color: TdsPalette.background,
  builder: (context, navigator) => TdsMobileProvider(child: navigator!),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  ),
  home: TdsToastProvider(
    child: TdsDialogProvider(
      child: Builder(builder: (context) => Center(
        child: TdsButton(
          onPressed: () => TdsToastProvider.of(context).openToast('저장했어요'),
          child: const Text('확인'),
        ),
      )),
    ),
  ),
)
```

Providers for toast/dialog belong inside a Navigator route, not alongside the
Navigator in `WidgetsApp.builder`. An externally owned controller must be
disposed by its owner. Toast replacement waits for the old exit animation and
coalesces rapid requests to the latest. `TdsToastProvider` defaults to
`exitOnUnmount: false` and retains the same root-overlay toast and timer after
its owner route leaves. `.web` defaults to true and bypasses the native host.
Persistence ends when the root overlay is destroyed. Captured themes, direction,
media and text style survive owner removal; arbitrary app contexts must live
above the target overlay.

`useToastContext` returns a nullable `TdsHostToast` capability. Inject it through
`TdsHostProvider.toast` or `TdsToastContextProvider`; an explicit null override
hides an outer host. Icon/lottie/action options map to that host or the local
fallback. The original host only exposes `show`: fallback `isOpen`/`closeToast`
cannot observe or close host-owned toasts. A real Toss host implementation is
not bundled or verified.

Use `TdsMobileAITProvider` for the original AIT defaults (light appearance and
limited font scaling). `TdsMobileProvider` supports native platform appearance
and accessibility tables. Do not apply Flutter text scaling again downstream.

## Native adaptations and known differences

Button now commits Enter on key down/repeat and Space on release, while
reserving its press visuals for pointer input. Disabled
loading has no dimmer; the dots remain mounted through their quick exit, the
glow fades from its current value, and the label waits 100ms before returning.
Interrupted loading, delayed work disposal and custom child hit testing have
regressions backed by the pinned original's lifecycle fixture. This covers
these contracts only, not the full motion or pixel matrix.

| React / browser contract | Native contract |
| --- | --- |
| ReactNode, HTML props, DOM events, refs | Widget slots, named parameters, native callbacks/controllers; incomplete mappings are listed individually |
| Hooks/context | Inherited providers, scope widgets and disposable controllers |
| Portal / fixed DOM positioning | Navigator routes, OverlayPortal or retained OverlayEntry; nullable target context and native context capture replace DOM portals |
| CSS fractional line boxes | Text/Footer use 1/64px flow geometry and the original font's first baseline without scaling glyphs; later native line advances and glyph rasterization still differ |
| Browser viewport/keyboard heuristic | MediaQuery insets; fixed-bottom metrics must not be applied again to an already-resized viewport |
| `maskImage` | 110-degree alpha ShaderMask |
| Host navigation/haptics/security | Injected `TdsHostProvider` interfaces, no-op/absent without adapters |

`TdsBottomCTA.single` / `.double` and `TdsFixedBottomCTA.double` now support
nullable double slots, intrinsic-width growth with reverse wrapping, source
gradient stops, fixed/inline spacer defaults, 50px visibility transitions and
delayed fade/scale/slide entrance. `hideOnScroll` observes the provider's root
scroll notifications; supply `scrollController` for an explicit target.
`TdsBottomCTADelayedEntrance.delay` is a Dart Duration, not source seconds.
Hidden controls leave native focus/semantics, and reduced motion skips these
transitions. Those accessibility choices differ from literal transparent DOM.
Real keyboard/safe-area behavior and motion-frame comparisons remain pending.

Ordinary plain/rich text keeps CJK graphemes together across style and link
boundaries. Oversized labels, including selectable labels, use preceding natural
spaces and reshape emergency line endings. The package source comparisons cover
108 original cases plus 24 mixed-language cases executed plain/rich. Selection
also has 164 source-backed selector/joining-control cases, each checked with
and without selection. Single BMP marks retain the preceding CJK context;
supplementary selectors and ZWNJ keep their original normal break opportunities,
while ZWJ prevents a normal break. Twelve original-browser suffix-omission cases
and wider combining/fallback-font differences remain explicit open gaps. Selection
maps layout-only joiners and line breaks back to original text and UTF-16 ranges,
preserving genuine source controls and whitespace. Width changes, equivalent
Text rebuilds and inherited font updates retain forward/reverse selection;
clear, select-all and character input during rebuilding have regression tests.
Selectable opaque/custom/WidgetSpan trees remain untouched. Full CSS whitespace,
Unicode/RTL, gesture and accessibility equivalence remain unverified.

`TdsFontScaleLimit.tdsWeb` and `.tdsMobile` limit independent typography families
without changing the host values returned by `usePlatform`, `useFontScaleCondition`
or `useFontSizeCondition`. Nested in-range limits inherit outer overrides, as
the source CSS does. `TdsPlatform.webSize`/`webLineHeight` expose web metrics to
native adapters. DOM `asChild`/`stylePropName` has no direct native counterpart.

Bubble's inline-middle line box uses the original regular font's ascent,
descent and x glyph height. The default 16px/24px host strut now produces the
source 49.796875px single-line bubble. Custom HTML ancestor font styles require
explicit `parentFontSize`/`parentLineHeight`; mixed-font and multiline visual
matrices are still incomplete. CTA disabled wiggle now uses the original four
87.5ms linear segments (350ms total), with a reduced-motion opt-out.

`TdsSecureScreenScope` invokes an injected adapter in lifecycle order. It does
**not** implement screenshot protection by itself. No screenshot-protection
platform plugin is installed. `TdsPlatformHaptic` is opt-in and is not an exact
Toss haptic implementation. Accessory-button scope includes a native no-host
fallback, but its placement and lifecycle matrix are not fully verified.

ListRow.Texts' 25 typography/color/weight presets are generated from runtime
source. Native right-content reflow currently recognizes direct supported
widget types; it cannot emulate CSS `:has` queries through arbitrary wrappers.
ListRow blink/shine and asset compounds now have native implementations.
Asset frame/scaling/card-padding/accessory and first-line alignment rules have
scoped tests. Wrapped Texts may supply `contentsType` explicitly for alignment.
Blink uses the original 80/480ms delays, content-only scaling and retained slow
exit. Its radial gradient uses the original fixed light blue500 while the dimmer
follows the current theme. The layers keep live dimensions without restarting;
the dimmer exits from its current opacity, and interrupted reentry retains the
radius with independent 80/480ms opacity delays. Imperative calls, including
their microtask continuations, batch to the last accepted effect; every accepted
blink keeps its timeout even if overwritten before render. Discrete raw input
and TDS pointer/keyboard/semantics activation commit before their asynchronous
continuations. Native event-task/frame scheduling is not an exact React
concurrent scheduler. Light/dark shine geometry, runtime quadratic easing,
repeats and repeated call behavior are tested, including iOS edge-touch
suppression. Light shine
captures integer client dimensions for its translation but keeps its gradient
box responsive; dark shine keeps percentage-based geometry. Theme changes
restart the effect with the latest requested repeat count. A changed repeat
request only retargets a light shine if its measured horizontal destination also
changes, starting at the current position. Same-commit theme/size changes use
the previous layout, matching the source's render-time DOM measurement. Live
resize, count retarget and theme replacement also pass Android/iOS integration
checks in both themes at 100/160% scale, with 16 inspected native captures.
Blink live theme/size, synchronous command ordering, canceled dimmers and
retained reentry also pass on both engines, with 16 more inspected captures.
Mixed raw pointer/controller commands now share that queue: child-down commands
yield to row touch feedback, ancestor-down commands win, touch-end ancestor
commands survive, and mouse-end clears them in its window phase. Compatibility
mouse starts are suppressed for 300ms after touch end/cancel. Click activation
waits for release to commit without reversing nested Menu activation order;
Enter/Space keydown and repeat activate without pointer feedback. Disposal,
disable-while-held and iOS first-active-touch handling have regressions. Detached
raw listeners ignore a pointer's retained hit-test path after widget disposal.

Descendant color registration belongs to **ListFooter**, not ListRow. Wrapped
Text/Icon compounds register independently in sibling order, retain the final
color after removal, and treat parent color props as initial values. Literal
palette colors stay static; `textColorToken`/`iconColorToken` and descendant
`colorToken` preserve adaptive theme identity. `iconName` implements the source
string shorthand, following the registered text color. Shared rapid motion uses
linear RGB, scale and the original 120%-wide shadow ellipse. Timeline target
snapshots, theme remount, touch-cancel retention and press/release context
reversion are tested. Source reversion can restore old pressed text/scale/shadow
after a color change, while removing the icon's animated CSS variable. These
source quirks are preserved. Untouched zero-playhead animations initialize lazily,
so a first-frame down/up pair does not invent saved inline press styles; an
advanced timeline restarts immediately. Repeated partial releases save the latest
rendered state. RGB channels and alpha round like the source CSS before becoming
the next tween's starting color. A first lazy release interpolates an unset icon
variable from transparent black, not from its SVG fallback color. Hairline
indentation and minimum-height distribution are also tested.
Press and release now keep separate dependencies, saved styles and descendant
snapshots. Changing only a pressed color resets press without cancelling an
in-flight release or discarding its previous save. A child inserted during that
change joins the new press but not the retained release. The dependency tables
are extracted from the original strings, so equal-valued semantic aliases and
dark `rgba(...,1)` versus `#ffffff` still trigger the source's distinct resets.
Eighteen new tests and 30 original-browser samples per theme cover these cases.
The mixed-input/footer-color scenario passes both native engines in light/dark
at 100/160% scale, with 32 inspected captures. Four paired Web footer crops still
show glyph and shadow pixel differences; this is not whole-component parity.
Four further 390×110 paired crops check fresh same-turn press/release followed
by a descendant color change in light/dark at 100/160%. Both text colors return
to the new value without a fabricated press snapshot. These unscaled captures
still show glyph baseline/rasterization differences and are not golden passes.
The additional async-order/replay scenario also passes both native engines in
all four theme/scale combinations. Its 32 inspected captures brought the
platform-labelled integration set to 160; painter-state and interrupted-color
assertions, not screenshots alone, verify the scoped regressions.
The independent-context scenario also passes both native engines in all four
variants. Its 32 additional inspected captures brought the platform-labelled
set to 192 at that checkpoint. Sixteen unscaled Web comparisons cover cleanup,
retained release restoration, late text and semantic aliases; glyph, arrow and
shadow pixels still differ. See [verification.md](reference/verification.md) for the logs,
capture timing and explicit limits of these checks.

Undefined adaptive targets such as `disabledBlue500` now follow the original
from-only tween: text returns to its own current rendered color, while a missing
icon custom property resolves to transparent black. A replay rereads the current
inline destination. Nested Footers keep independent color providers, but each
ancestor's selectors include descendant text, icons, content and shadow nodes.
Removed/reinserted nodes join only new snapshots, and TDS clicks bubble inner to
outer. Thirty added widget tests cover these cases, including overlapping release
saves at a controlled first frame; both original browser probes pass in light/dark.
Both full native suites pass with the new edge-case scenario in all four
theme/scale variants. Its 48 inspected captures bring the platform-labelled set
to 240. Held-pointer crosshairs are Flutter test instrumentation, not app UI.
Twenty-four paired, unscaled Web comparisons cover first press, replay, nested
press/click, reinsertion and target recapture. Text baselines, arrows and shadow
pixels still differ; these captures are not golden-parity passes.

The typography/arrow/shadow checkpoint adds source measurements for all 20
typography types, four weights, 100/160/200% and one/two lines (480 specimens).
`TdsText` and plain Footer labels now use the original font's measured first
baseline and quantized line-box height. Korean labels keep whole words when
wrapping. The text adapter retains the caller's style, semantics identifier,
scaling, alignment and selection metadata; replacement fonts and mixed Footer
spans do not receive a forced Toss baseline. Footer shadow bounds quantize the
120% width before centering, including fractional container widths. The gallery
also corrects nested Footer inline-middle text and top-aligned arrows; that is
fixture composition, not a new automatic layout rule for arbitrary children.

Eighty unscaled React/Flutter Web pairs cover typography, Footer labels/arrows,
shadows and the previous nested/color cases. These are measured differences,
not golden passes. All 448 package tests and both full native suites pass, with
56 new Android/iOS captures inspected. In particular, native text still rounds
each painted line advance: Footer xs at 160% advances by 34px rather than
33.796875px. Correct flow
height and first baseline do not imply that every later line matches. Glyph/SVG
antialiasing and gradient pixels also remain different. See
[verification.md](reference/verification.md) for reproduction commands and limits.

Arbitrary concurrent React ordering, exhaustive nested/context combinations,
cross-engine frame/task scheduling, rich inline content and original DOM
adaptations still need work. Header icon buttons preserve
standard title line height; nonstandard short titles and touch areas outside
ancestor bounds remain differences. Toast word breaking and drag frame timing
remain different. Modal nested-route/focus restoration and editable selection/menu
behavior need additional device testing.
Open modal routes retain live TDS theme, host toast and global loading callbacks;
replaced back-event streams are unsubscribed. BottomSheet's `onEntered` follows
the source open effect rather than animation completion.

BottomSheet headers accept custom widget/rich-text children through `.child`.
Select uses source medium grey700 text and the source font-scale metric table
(including 27px text / 36px line height at 160%), line marks,
reserved hidden-mark width and the 80px/800ms expo entrance with 30ms stagger.
`animationDelay` is a Duration. The original tabbable labels do not implement
Enter/Space/arrow selection; browser dispatch confirmed this. Native semantics
exposes one radio per row rather than the original nested radio/checkbox labels.
`onCheckedChange` additionally reports the source checkbox checked value,
including false when the already-selected option is clicked again.

Sheet CTA/DoubleCTA forward native BottomCTA options, disable duplicate safe-area
padding by default, and resolve nullable `background` from measured scrollability.
Their layered-background gradient overlaps content by 34px. Source drag geometry,
50px down/10px up thresholds, touch-body guards, 0.98 scale, content fade and
light/dark dimmer targets are implemented. Entrance translates from 150px plus
the bottom gap; exit runs forward rapid motion while the dimmer has an independent
quick fade. CTA entry uses the source 600ms fade, and the body slides 80px with
the header-count stagger. Native interruption, source dimmer throttling,
focus-within filtering/React child-array stagger rules, keyboard viewport
heuristics and the full device matrix remain partial. Sheet hook button builders
carry loading/disabled state and retain the invoking controller in every slot.

ProgressBar retains its 500ms CSS ease-in-out transition, including CSS reversal
shortening, initial-only `animate`, unclamped translation and source percentage
text. Six focused tests cover retargets, double reversals and teardown. Adjacent
DOM sibling margins and arbitrary CSS overrides still require native layout.

Checkbox now has the 150ms selection overshoot trigger, immediate press-scale
and tickWeak haptic, disabled icon-only wiggle, squared-channel color mixing,
disabled grey200 check and controlled/uncontrolled callback ordering. The
original disabled keyframes use quadratic ease-in-out: `linear: true` is ignored
by the bundled Framer runtime. Switch retains separate knob-size/position
springs and source click-before-change ordering. In pinned 2.5.1 its mount-only
gesture callback captures a null rally, so declared pressed/wiggle motions do
not run; the native implementation follows the observed unchanged root. Both
source labels focus but do not activate with Enter/Space. Native screen-reader
tap actions remain available. Full mixed hover/press/retarget timelines remain.

Rich Paragraph/Top.SubtitleParagraph spans now inherit typography, weight and
color independently for text and asset/badge metrics. Badge text uses 1.5em line
height. Mixed inline-middle baselines, Korean keep-all with anywhere fallback,
anonymous inline struts and selection are not browser-equivalent.

FullSecureKeypad uses the source SVGs, fixed 20px/13px/17px text, 272px height,
2:2:5:5 control widths, press-start dispatch and original blank insertion bounds.
Upper/lowercase share the same layout. Imperative reorder changes cached layouts
without forcing a render, as in the source. Live-region timing is 200ms/1s.
Native keyboard/semantics activation and secure randomness are adaptations;
OS capture protection and actual screen-reader behavior remain unverified.

Menu trigger activation now crosses nested TDS pressables after the child
callback, including disabled suppression, keyboard/semantics and child focus
return. Enter opens on key down; the original menu scales without fading.
Third-party gesture widgets still need an explicit activation adapter.
Paint-time anchor changes now refresh menu/tooltip positioning without an idle
frame loop. SliderTooltip uses the actual Tooltip, a zero-size progress anchor,
the original 30px top gap, value formatting and native Tooltip prop forwarding.

WikiText uses native line fragments for multiple highlights and bundles the four
original light/dark edge PNGs. Inline padding/icon wrapping, source highlight
geometry, theme/font/width updates and description scroll fades have scoped
tests. Scroll/clipping-aware activation now drives independent highlight/icon
springs with the original delays and retained exit padding. Inactive words stay
focusable but reject activation/haptics; Enter/Space activate on keydown.
The popup has independent word/box/scale/dimmer timelines, including interrupted
entry. `description` accepts a String or Widget: strings collapse CSS whitespace,
keep Korean words together, animate rendered lines at 100ms intervals and unlock
scrolling on completion; custom widgets bypass text animation. The DOM body-height
snapshot is adapted to the outermost native scroll extent. Browser observer
scheduling, custom-font boxes, transformed/nested scrolling, long unbreakable
words, RTL and the full device/accessibility matrix remain unverified.

Menu now has zero anchor gap, alignment/side flipping, a labelled close control
with initial focus, Tab cycling, click dismissal, controlled-close behavior,
retained spring exit and reversal. The source has no typeahead/list-navigation
hook. Nested interactive trigger-child bubbling and ancestor clipping are not
fully adapted. Tooltip arrows use all original asymmetric paths and ratio clamps.
Static menu/tooltip shadows use CSS radius/2 sigma, not Flutter's default shadow
conversion. Blur kernels and text rasterization still show pixel differences.

Skeleton entry/exit now starts at source opacity, and interrupted fades preserve
the current opacity. Delayed items stay invisible until their stagger begins and
use the source 600ms alternate curve. Full pattern/theme/device timelines remain.

TextButton now distinguishes literal colors from adaptive `colorToken` values,
copies the source palette-level press lookup, and tests immediate pointer
haptics separately from keyboard activation. Its standalone touch padding is
zero; only Paragraph ancestry provides the source link metrics. Original
touchcancel persistence and dormant CSS hover fill are reproduced. Uniform
labels use measured fractional line boxes/baselines, Korean keep-all with
oversized-word fallback, fixed arrow frames and CSS under-edge underlines.
Emoji/CJK fallback runs with unequal glyph heights now share their logical
underline line; explicit empty lines still reserve their original indices.
Package geometry regressions and Android/iOS actual-font checks cover this
grouping, not arbitrary mixed-size typography or fallback-glyph pixel identity.
Rich/mixed-font content, other CSS ancestors, early-mount overlapping timelines,
non-unit-DPR decoration snapping and exhaustive device pixels remain incomplete.

Highlight now uses the original SVG arrow and rounded cutout, independent
opacity/expansion/message timelines, six message alignments and Android's
full-alpha offset blur (the original filter bypasses its alpha-transfer node).
Original browser runs confirmed that the full overlay makes the target inert,
Escape does not dismiss it, and dismissal hides even if the owner retains
`open=true`. Standalone HighlightUI still permits input through its cutout.
Focus restoration/inert teardown timing, programmatic DOM event duplication,
nested scrollers and every animation interruption remain incomplete.

FullTooltip now has the original curved silhouette, static teal colors,
fractional 1.35 line boxes with rounded measured outer height, 400/500/700ms
inline entrance stages, overlapping layout and a floating backdrop filter.
The original's unusual contracts are deliberate: omitted inline placement
omits the child; uncontrolled mode overrides the external `onClose`; its
initial `onClickOutside` runs on every pointerdown, even inside or when closed.
Relative `offset` is unused, and explicit floating offset replaces the overlap
default. Content changes now use two independent 100ms trailing measurements:
the message resizes the surface, then the surface restarts the clip/flow heights.
The previous height holds during the 400ms delay before the explicit zero-height
restart; changing overlap restarts only the flow spacer. Heights use source CSS
integer rounding, and text opacity is not restarted. Exits keep the prior props;
reopening remounts the body, while mode changes reset timer/subtree ownership.
An interrupted reopen also reproduces the original presence quirk: only the next
close removes immediately; a fresh mount restores the normal exit animation.
This is checked for both inline and floating variants, including mode resets.
Android/iOS engine tests also cover the interrupted and clean close cycles in
light/dark at 100/160% text scale. These are lifecycle checks, not motion goldens.
Cold-mount observer timing, the full interruption matrix, DOM selector anchors,
rich messages and blur raster parity remain incomplete.

## Fonts and assets

Original Toss Product Sans fonts, not Paperlogy, are bundled for offline native
startup. Each weight was merged from 96 original Unicode subsets into 12,605
codepoints. The font builder checks outline coordinates, advance/side-bearing
metrics and units-per-em against each subset. Provenance is in
`assets/fonts/provenance.json`. Source timestamps are preserved for deterministic
output. A repeat build in this environment produced identical SHA256 hashes
for all eight TTF files and provenance.json; cross-tool-version reproducibility
has not been established.

Weights 300–900 use `Toss Product Sans`. Flutter has no 950 weight, so the 950
asset is registered separately as `Toss Product Sans Black` at weight 900.
Original SVG icons and hashes are in `assets/icons/provenance.json`; unknown
icon names still use the original network URL. Native rendering and loading
behavior of every asset is not yet verified.

## Reproduction and checks

From the repository root:

```sh
npm ci --prefix tool/tds_source
npm run generate --prefix tool/tds_source
node tool/tds_source/coverage.mjs --check
flutter analyze
flutter test
```

Also run `flutter test` from `packages/tds_mobile_flutter`; root tests do not run
dependency package tests. The root
suite also covers the app's Google/Kakao OAuth-launch buttons, repositories and
business flows. These tests do not perform real provider authentication.

Application themes can override `primaryButtonBackground`,
`primaryButtonWeakBackground`, and `primaryButtonWeakForeground`. Their default
values are null, preserving the original TDS contrast rules. Weak overrides
apply only to primary buttons; danger colors and disabled/loading behavior
remain unchanged. The weak foreground also colors its dimmer and loader.

Optional asset regeneration, from the root:

```sh
node tool/tds_source/icons.mjs
node tool/tds_source/wrappers.mjs --check
uv run tool/tds_source/fonts.py
```

These download only the original public assets and write the derived assets
and provenance; no Supabase key is used.

To compare rendering:

```sh
npm run reference --prefix tool/tds_source
flutter run -d chrome -t lib/tds_gallery.dart --web-port 5180
```

Use matching query parameters on both pages:
`family=buttons|text-buttons|fields|extended-controls|checkbox|switch|toast|lists|list-assets|list-effects|list-footer-colors|list-footer-nested|compounds|keypad|secure-keypad|bottom-cta|paragraphs|menus|tooltips|sheet|sheet-select|wiki|slider-tooltip`,
`theme=light|dark`, `scale=100|160|200`, plus applicable `size`/`state`. React also
has typography/basic-control/badge fixtures whose native gallery routes remain
pending. Use a 390px viewport; wait for the React fixture **and**
`document.fonts.ready` before capturing. For a compiled gallery, build with
`flutter build web -t lib/tds_gallery.dart --output .context/tds-gallery-web`
and serve that directory locally; leave `build/web` for the main app.

`list-effects` includes child/ancestor input and post-release click-blink modes.
`list-footer-colors` includes live color/theme/removal/order/reset controls;
`adaptive=true` selects token colors in that native fixture. Original browser
probes `list-row-input.js` and `list-footer-colors.js` assert the corresponding
event and color contracts against the unchanged React package.
The native-only `list-footer-contexts` fixture adds independent-context controls.
Pair it with the original `list-footer-colors` fixture using
`contextCase=cleanup|restore|late|alias` and the corresponding
`{react,flutter}-footer-context-capture.js` probes. `list-footer-contexts.js`
asserts the broader original dependency/serialization matrix.
The native-only `list-footer-undefined` fixture pairs with original
`list-footer-colors` for `edgeCase=from-only|repress`. Both engines use
`list-footer-nested` for `edgeCase=nested|bubbled|late|recaptured`.
Use `{react,flutter}-footer-edge-capture.js` for these paired captures;
`list-footer-undefined.js` and `list-footer-nested.js` assert the original
contracts separately. Nested outer activation targets its own text row, not
the center of the enclosing button rectangle, which also contains the child.

Native engine smoke tests and screenshots (no Supabase interaction):

```sh
flutter drive --driver=test_driver/tds_native_driver.dart \
  --target=integration_test/tds_native_test.dart -d <device-id>
```

This exercises light/dark at 100/160% with original font assets, checkables,
text entry and sheet lifecycle. Screenshots are saved in `.context/`; capture
success is not a golden-parity assertion. The user has no Toss host SDK/test
app, so host validation is restricted to injected call contracts and the
explicitly approximate Flutter platform haptic adapter, not Toss host behavior.

```sh
uv run tool/tds_source/compare_images.py \
  .context/react-lists.png .context/flutter-lists.png \
  --height 500 --output .context/lists-comparison.png
```

Screenshots/diffs are local evidence in `.context/`, not committed golden
baselines. Pixel differences have no approved pass threshold and are not a
parity score. See [verification.md](reference/verification.md) for the current
verification scope and outstanding work.
