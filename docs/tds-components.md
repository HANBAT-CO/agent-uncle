# TDS 컴포넌트 카탈로그

<!-- 자동 생성: dart tool/tds_guard/tds_guard.dart catalog --write · 직접 수정 금지 -->

앱 UI는 이 목록의 공개 API만 사용한다. import는 `package:tds_mobile_flutter/tds_mobile_flutter.dart` 하나다. 생성자와 파라미터는 해당 소스 파일에서 확인한다. 규칙은 [TDS UI 정책](tds-ui-policy.md)을 따른다.

## TDS 패키지 (`packages/tds_mobile_flutter/lib/`)

### `src/foundation/tokens.g.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsPalette` | class |  |
| `tdsAdaptiveColors` | const |  |
| `tdsStaticPressColors` | const |  |
| `tdsTextMetrics` | const |  |
| `tdsIconHeights` | const |  |
| `tdsBadgeMetrics` | const |  |
| `tdsLinkMetrics` | const |  |
| `tdsIosFontSizes` | const |  |
| `tdsIosFontScales` | const |  |
| `tdsWebIosFontSizes` | const |  |
| `tdsWebFontSizeCaps` | const |  |
| `tdsWebLineHeights` | const |  |

### `src/foundation/theme.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsTypography` | enum |  |
| `TdsFontWeight` | enum |  |
| `TdsColorPreference` | enum |  |
| `TdsOS` | enum |  |
| `TdsPlatform` | class |  |
| `TdsA11yCondition` | class |  |
| `TdsThemeData` | class |  |
| `TdsTheme` | class extends InheritedWidget |  |
| `TdsMobileProvider` | class extends StatelessWidget | Native counterpart of TDSMobileProvider. System font scaling is resolved once |
| `TdsMobileAITProvider` | class extends StatelessWidget | The original AIT provider forces light appearance and disables font scaling |
| `TdsColorSchemeArea` | class extends StatelessWidget |  |
| `TdsFontScaleLimit` | class extends StatelessWidget |  |
| `getTypographyRule` | function |  |
| `calculateSizeAsFontScale` | function |  |
| `usePlatform` | function |  |
| `useAppearance` | function |  |
| `useFontScaleCondition` | function |  |
| `useFontSizeCondition` | function |  |
| `useSafeAreaBottomHeight` | function |  |
| `safeAreaInset` | function |  |
| `safeAreaInsetTop` | function |  |
| `safeAreaInsetBottom` | function |  |
| `safeAreaInsetPaddingTop` | function |  |
| `safeAreaInsetPaddingBottom` | function |  |

### `src/foundation/motion.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsSpringCurve` | class extends Curve | Original TDS uses RK4 spring integration at 60Hz, with a .01 rest threshold. |
| `TdsMotion` | class |  |

### `src/foundation/host.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsHapticType` | enum |  |
| `TdsHaptic` | class | The Toss host has more haptic patterns than Flutter's platform API. Inject |
| `TdsNoopHaptic` | class |  |
| `TdsPlatformHaptic` | class | Opt-in native approximation, never silently substituted for the Toss host. |
| `TdsAccessoryButton` | class |  |
| `TdsAccessoryTextButton` | class extends TdsAccessoryButton |  |
| `TdsAccessoryIconButton` | class extends TdsAccessoryButton |  |
| `TdsAccessoryIconDoubleButton` | class extends TdsAccessoryButton |  |
| `TdsNavigation` | class |  |
| `TdsSecureScreen` | class |  |
| `TdsHostSkeleton` | class |  |
| `TdsToastIconType` | enum |  |
| `TdsToastActionColor` | enum |  |
| `TdsToastActionStyle` | enum |  |
| `TdsToastAction` | class |  |
| `TdsHostToastOptions` | class |  |
| `TdsHostToast` | class | The source ToastContext exposes show only. No dismissal/lifecycle event is |
| `TdsHostProvider` | class extends InheritedWidget | Native replacement for host-injected hooks. Missing capabilities remain |
| `tdsHapticOf` | function |  |
| `tdsAppNavigationOf` | function |  |
| `tdsSecureScreenOf` | function |  |
| `tdsSkeletonOf` | function |  |
| `tdsScreenReaderOf` | function |  |
| `TdsGlobalConfig` | class |  |
| `TdsGlobalConfigContext` | class |  |
| `TdsGlobalConfigProvider` | class extends StatefulWidget |  |
| `useGlobalConfigContext` | function |  |
| `TdsViewport` | class |  |
| `TdsUserAgent` | class |  |
| `TdsScrollingDirection` | enum | ScrollController counterpart of useScrollingDirection. Leading/trailing |
| `TdsScrollingDirectionController` | class |  |

### `src/foundation/dialog_controller.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsDialogController` | class extends ChangeNotifier | Stateful counterpart of useDialog. A provider owns the portal and cleans up |
| `TdsDialogProvider` | class extends StatefulWidget |  |

### `src/foundation/toast_controller.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsToastOptions` | class |  |
| `TdsToastController` | class extends ChangeNotifier | Native useWebToast. Replacements wait for the old toast's exit animation; |
| `TdsToastProvider` | class extends StatefulWidget | Place inside a Navigator's route so an Overlay is available. This provider |
| `TdsToastContextProvider` | class extends InheritedWidget | Host context is separate from the web-overlay controller context. |
| `useToastContext` | function |  |

### `src/foundation/layout_adapters.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsBackground` | enum |  |
| `TdsNavigationTextType` | enum |  |
| `useBackgroundStyle` | function | CSS backgroundColor becomes a native decoration rather than a DOM style. |
| `useTopNavigationHeight` | function |  |
| `getTopOffsetInMobile` | function |  |
| `getNavTypeByBackgroundColor` | function | Source intentionally uses weighted 8-bit RGB, not WCAG gamma-corrected |
| `TdsGradientMask` | class extends StatelessWidget | Exact 110-degree CSS alpha-gradient geometry at any aspect ratio. The |
| `TdsFixedBottomMetrics` | class |  |
| `TdsSecureScreenScope` | class extends StatefulWidget | Lifecycle counterpart of useSecureScreen(enabled). This delegates only; |
| `TdsAccessoryButtonScope` | class extends StatefulWidget | Host-backed useAccessoryButton lifecycle. The original no-host web |

### `src/components/text.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsText` | class extends StatelessWidget |  |
| `TdsParagraphText` | class extends TextSpan | Typed inline text stays breakable and selectable in the containing paragraph. |
| `TdsParagraph` | class extends StatelessWidget | Paragraph uses inline spans to keep mixed text/assets in a single text flow. |
| `TdsSpacing` | class extends StatelessWidget |  |
| `TdsParagraphIcon` | class extends StatelessWidget |  |
| `TdsParagraphLinkType` | enum |  |
| `TdsParagraphLink` | class extends StatelessWidget | Use in a WidgetSpan. Navigation is explicit and keeps router ownership in the app. |
| `TdsBorderVariant` | enum |  |
| `TdsBorder` | class extends StatelessWidget |  |

### `src/components/button.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsButtonColor` | enum |  |
| `TdsButtonVariant` | enum |  |
| `TdsButtonDisplay` | enum |  |
| `TdsButtonSize` | enum |  |
| `TdsButtonColors` | class |  |
| `TdsButton` | class extends StatelessWidget |  |
| `TdsButtonLoader` | class extends StatefulWidget |  |
| `TdsCTAButton` | class extends StatefulWidget |  |

### `src/components/text_button.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsTextButtonSize` | enum |  |
| `TdsTextButtonVariant` | enum |  |
| `TdsArrowPlacement` | enum |  |
| `TdsTextButton` | class extends StatelessWidget | TextButton's DOM-specific as/href becomes an explicit onPressed callback. |

### `src/components/icon_button.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsIconButtonVariant` | enum |  |
| `TdsIconButtonImage` | class extends StatelessWidget |  |
| `TdsIconButton` | class extends StatelessWidget |  |

### `src/components/badge.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsBadgeSize` | enum |  |
| `TdsBadgeVariant` | enum |  |
| `TdsBadgeColor` | enum |  |
| `TdsBadge` | class extends StatelessWidget |  |
| `TdsParagraphBadge` | class extends StatelessWidget |  |

### `src/components/checkbox.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsCheckboxVariant` | enum |  |
| `TdsCheckboxInputType` | enum |  |
| `TdsCheckbox` | class extends StatefulWidget |  |
| `TdsCheckboxLineGraphic` | class extends StatelessWidget | The original line path reused by agreement marks without nesting inputs. |

### `src/components/switch.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsSwitch` | class extends StatefulWidget |  |

### `src/components/loader.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsLoaderSize` | enum |  |
| `TdsLoaderType` | enum |  |
| `TdsLoader` | class extends StatefulWidget |  |
| `TdsLoaderAnimation` | class extends StatefulWidget |  |

### `src/components/top.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsTop` | class extends StatelessWidget |  |
| `TdsTopLowerButton` | class extends TdsButton |  |
| `TdsTopLowerCTA` | class extends StatelessWidget |  |
| `TdsTopLowerCTAButton` | class extends TdsButton |  |
| `TdsTopRightButton` | class extends TdsButton |  |
| `TdsTopRightAssetContent` | class extends StatelessWidget |  |
| `TdsTopUpperAssetContent` | class extends StatelessWidget |  |
| `TdsTopRightArrow` | class extends StatelessWidget |  |
| `TdsTopTitleTextButton` | class extends TdsTextButton |  |
| `TdsTopSubtitleTextButton` | class extends TdsTextButton |  |
| `TdsTopTitleSelector` | class extends StatelessWidget |  |
| `TdsTopSubtitleSelector` | class extends StatelessWidget |  |
| `TdsTopSubtitleBadge` | class |  |
| `TdsTopSubtitleBadges` | class extends StatelessWidget |  |
| `TdsTopTitleParagraph` | class extends StatelessWidget |  |
| `TdsTopSubtitleParagraph` | class extends StatelessWidget |  |
| `TdsBottomInfo` | class extends StatelessWidget |  |

### `src/components/asset.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsAssetScaleType` | enum |  |
| `TdsAssetAccessoryPosition` | enum |  |
| `TdsAssetFrameShape` | class |  |
| `TdsAssetFrame` | class extends StatelessWidget |  |
| `TdsAssetIcon` | class extends StatelessWidget |  |
| `TdsAssetImage` | class extends StatelessWidget |  |
| `TdsAssetLottie` | class extends StatelessWidget |  |
| `TdsAssetText` | class extends StatelessWidget |  |
| `TdsSquircleSize` | enum |  |
| `TdsSquircleMasking` | class extends StatelessWidget |  |

### `src/components/asset_content.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsAssetContentIcon` | class extends TdsAssetIcon | Content-only variants omit the frame background. Frames are composed separately. |
| `TdsAssetContentImage` | class extends TdsAssetImage |  |
| `TdsAssetContentLottie` | class extends TdsAssetLottie |  |
| `TdsAssetVideo` | class extends StatelessWidget |  |
| `TdsAssetContentVideo` | class extends StatefulWidget | Native playback (AVPlayer/ExoPlayer/HTML video); injected controllers remain |

### `src/components/asset_frames.g.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsAssetFrames` | class |  |

### `src/components/progress_bar.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsProgressBarSize` | enum |  |
| `TdsProgressBar` | class extends StatefulWidget |  |

### `src/components/numeric_spinner.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsNumericSpinnerSize` | enum |  |
| `TdsNumericSpinner` | class extends StatefulWidget |  |

### `src/components/modal.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsModal` | class extends StatefulWidget | Controlled native portal. The source's DOM portal container becomes a |
| `TdsModalContent` | class extends StatelessWidget |  |
| `TdsModalOverlay` | class extends StatelessWidget | A dimmer for custom native overlay compositions. TdsModal supplies its own |

### `src/components/dialog.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsDialogTitle` | class extends StatelessWidget |  |
| `TdsDialogDescription` | class extends StatelessWidget |  |
| `TdsAlertDialog` | class extends StatelessWidget |  |
| `TdsConfirmDialog` | class extends StatelessWidget |  |
| `TdsAlertDialogButton` | class extends StatelessWidget |  |
| `TdsConfirmDialogButton` | class extends StatelessWidget |  |
| `TdsDialogFooter` | class extends MultiChildRenderObjectWidget | Source footer: flex-grow: 1; min-width: calc(50% - 8px); wrap-reverse. |

### `src/components/text_field.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsTextFieldVariant` | enum |  |
| `TdsTextFieldLabelOption` | enum |  |
| `TdsTextFieldFormat` | class | Mirrors TextField.format's raw/display pair. A Flutter controller holds the |
| `TdsTextField` | class extends StatefulWidget |  |
| `tdsTextFieldStyle` | function |  |
| `TdsTextFieldContainer` | class extends StatelessWidget |  |
| `TdsTextFieldSurface` | class extends StatelessWidget |  |
| `TdsTextFieldClearable` | class extends TdsTextField |  |
| `TdsTextFieldPassword` | class extends TdsTextField |  |
| `TdsTextArea` | class extends TdsTextField |  |
| `TdsTextFieldButton` | class extends StatelessWidget |  |

### `src/components/selection.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsTabSize` | enum |  |
| `TdsTabItem` | class |  |
| `TdsTab` | class extends StatefulWidget |  |
| `TdsSegmentedControlSize` | enum |  |
| `TdsSegmentedControlAlignment` | enum |  |
| `TdsSegmentedControlItem` | class |  |
| `TdsSegmentedControl` | class extends StatefulWidget |  |

### `src/components/toast.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsToastPosition` | enum |  |
| `TdsToast` | class extends StatefulWidget | Controlled, non-modal overlay. [persistent] maps the original Infinity |
| `TdsToastContent` | class extends StatelessWidget | Non-overlay surface, also used by the comparison fixture. |
| `TdsToastButton` | class extends StatelessWidget |  |
| `TdsToastIcon` | class extends StatelessWidget |  |
| `TdsToastLottie` | class extends StatelessWidget |  |

### `src/components/list.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsListRowVerticalPadding` | enum |  |
| `TdsListHorizontalPadding` | enum |  |
| `TdsListRowAlignment` | enum |  |
| `TdsListRowBorder` | enum |  |
| `TdsListRowDisabledStyle` | enum |  |
| `TdsListRowArrow` | enum |  |
| `TdsList` | class extends StatelessWidget | Original List is a zero-margin/padding group, not an independently scrolling |
| `TdsListRow` | class extends StatelessWidget |  |
| `TdsListRowTextStyle` | class | Native equivalent of EssentialTextProps. Explicit child Text styles retain |
| `TdsListRowTexts` | class extends StatelessWidget |  |

### `src/components/list_compounds.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `tdsListRowTypography` | const | Original ListRow.Typography keys retain their source spelling. |
| `TdsListRowImageType` | enum |  |
| `TdsListRowImageContainer` | class extends StatelessWidget |  |
| `TdsListRowImage` | class extends StatelessWidget |  |
| `TdsListRowIconShape` | enum |  |
| `TdsListRowIconSize` | enum |  |
| `TdsListRowIcon` | class extends StatelessWidget |  |
| `TdsListRowIconButton` | class extends TdsIconButton |  |
| `TdsListRowText` | class extends TdsText |  |
| `TdsListRowLeftText` | class extends StatelessWidget |  |
| `TdsListRowLoaderType` | enum |  |
| `TdsListRowLoaderPadding` | enum |  |
| `TdsListRowLoader` | class extends StatefulWidget |  |

### `src/components/list_assets.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsListRowAssetSize` | enum |  |
| `TdsListRowAssetShape` | enum |  |
| `TdsListRowAssetIconShape` | enum |  |
| `TdsListRowAssetIconVariant` | enum |  |
| `TdsListRowAssetIcon` | class extends StatelessWidget | ListRow.AssetIcon: source shape-specific scaling and fixed circle frames. |
| `TdsListRowAssetImage` | class extends StatelessWidget |  |
| `TdsListRowAssetText` | class extends StatelessWidget |  |
| `TdsListRowAssetLottie` | class extends StatelessWidget |  |
| `TdsListRowLeftContainer` | class extends StatelessWidget |  |
| `TdsListRowFillIconShape` | enum |  |
| `TdsListRowFillIcon` | class extends StatelessWidget |  |

### `src/components/list_presets.g.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsListRowTextType` | enum |  |
| `tdsListRowTextPresets` | const |  |

### `src/components/list_support.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsListHeaderSize` | enum |  |
| `TdsListHeaderVerticalPadding` | enum |  |
| `TdsListHeaderDescriptionPosition` | enum |  |
| `TdsListHeaderRightAlignment` | enum |  |
| `TdsListHeader` | class extends StatelessWidget |  |
| `TdsListHeaderTitleParagraph` | class extends StatelessWidget |  |
| `TdsListHeaderTitleSelector` | class extends StatelessWidget |  |
| `TdsListHeaderRightIconButton` | class extends StatelessWidget |  |
| `TdsListFooterHairline` | class extends StatelessWidget |  |
| `TdsListFooterShadow` | class extends StatefulWidget |  |
| `TdsListFooterShadowPainter` | class extends CustomPainter |  |
| `TdsListHeaderDescriptionParagraph` | class extends StatelessWidget |  |
| `TdsListHeaderRightText` | class extends StatelessWidget |  |
| `TdsListHeaderTitleTextButton` | class extends StatelessWidget |  |
| `TdsListHeaderRightArrow` | class extends StatelessWidget |  |
| `TdsListFooterBorder` | enum |  |
| `TdsListFooter` | class extends StatefulWidget |  |
| `TdsListFooterText` | class extends StatefulWidget |  |
| `TdsListFooterIcon` | class extends StatefulWidget |  |
| `TdsTableRowAlign` | enum |  |
| `TdsTableRow` | class extends StatelessWidget |  |

### `src/components/collections.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsBoardRow` | class extends StatefulWidget | Controlled when [isOpened] is supplied; otherwise owns its expanded state. |
| `TdsBoardRowArrowIcon` | class extends StatelessWidget |  |
| `TdsBoardRowPrefix` | class extends StatelessWidget |  |
| `TdsBoardRowText` | class extends StatelessWidget |  |
| `TdsGridList` | class extends StatelessWidget |  |
| `TdsGridListItem` | class extends StatelessWidget |  |
| `TdsSelectorType` | enum |  |
| `TdsSelector` | class extends StatelessWidget |  |

### `src/components/chip.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsChipKind` | enum |  |
| `TdsChipShape` | enum |  |
| `TdsChipSize` | enum |  |
| `TdsChipVariant` | enum |  |
| `TdsChipMargin` | enum |  |
| `TdsChip` | class extends StatelessWidget |  |
| `TdsChipItem` | class extends StatelessWidget |  |
| `TdsChipItemLeftIcon` | class extends StatelessWidget |  |
| `TdsChipItemLeftImage` | class extends StatelessWidget |  |
| `TdsChipItemLeftCard` | class extends StatelessWidget |  |
| `TdsChipRightIconType` | enum |  |
| `TdsChipItemRightIcon` | class extends StatelessWidget |  |
| `TdsChipItemRightNumber` | class extends StatelessWidget |  |

### `src/components/feedback.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsFadeIn` | class extends StatefulWidget |  |
| `TdsLoadingCompleteView` | class extends StatefulWidget |  |
| `TdsFullScreenLoader` | class extends StatelessWidget | Put this in the route's full-screen Stack. It blocks interactions below it. |
| `TdsSkeletonPattern` | enum |  |
| `TdsSkeletonModule` | enum |  |
| `TdsSkeletonBackground` | enum |  |
| `TdsSkeletonPart` | class |  |
| `TdsSkeleton` | class extends StatelessWidget |  |
| `TdsSkeletonWrapper` | class extends StatefulWidget |  |
| `TdsSkeletonItem` | class extends StatefulWidget |  |
| `TdsRatingSize` | enum |  |
| `TdsRatingVariant` | enum |  |
| `TdsRating` | class extends StatelessWidget |  |
| `TdsResult` | class extends StatelessWidget |  |
| `TdsResultButton` | class extends StatelessWidget |  |

### `src/foundation/portal.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsPortalContext` | class | Native counterpart of the original portal target context. Flutter's Overlay |
| `TdsPortalProvider` | class extends StatelessWidget |  |
| `TdsPortalContextProvider` | class extends InheritedWidget | The context Provider is distinct from the provider that creates a target. |
| `TdsPortalContextConsumer` | class extends StatelessWidget | React context Consumer's render callback; this does not create a portal. |
| `TdsPortalConsumer` | class extends StatefulWidget |  |
| `TdsFixedPanel` | class extends StatefulWidget | A layout-aware native replacement for fixed CSS positioning. The overlay |
| `TdsMeasuredFlowSpacer` | class extends StatefulWidget | Explicit non-fixed `takeSpace` duplicates the source's measured flow spacer. |

### `src/components/bottom_cta.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsBottomCTAAnimation` | enum |  |
| `TdsBottomCTADelayedEntrance` | class | Native duration counterpart of `showAfterDelay` (source delay is seconds). |
| `TdsBottomCTA` | class extends StatefulWidget |  |
| `TdsFixedBottomCTA` | class extends TdsBottomCTA |  |

### `src/components/bottom_sheet.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsBottomSheetHeight` | class |  |
| `TdsBottomSheet` | class extends StatelessWidget |  |
| `TdsBottomSheetHeader` | class extends StatelessWidget |  |
| `TdsBottomSheetHeaderDescription` | class extends StatelessWidget |  |
| `TdsBottomSheetCTA` | class extends StatelessWidget |  |
| `TdsBottomSheetDoubleCTA` | class extends StatelessWidget |  |
| `TdsBottomSheetSelectOption` | class |  |
| `TdsBottomSheetSelect` | class extends StatelessWidget |  |

### `src/foundation/bottom_sheet_controller.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsTwoButtonSheetAction` | enum |  |
| `TdsSheetButtonBuilder` | typedef | Native adapter for cloning a custom React button and its loading property. |
| `TdsSheetButtonState` | class |  |
| `TdsBottomSheetOptions` | class |  |
| `TdsBottomSheetController` | class extends ChangeNotifier |  |
| `TdsBottomSheetProvider` | class extends StatefulWidget |  |
| `useBottomSheet` | function |  |

### `src/components/navigation.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsTopNavigation` | class extends StatelessWidget |  |
| `TdsRootTopNavigation` | class extends StatelessWidget |  |
| `TdsTopNavigationBackButton` | class extends StatelessWidget |  |
| `TdsTopNavigationIconButton` | class extends StatelessWidget |  |
| `TdsTopNavigationTextButton` | class extends StatelessWidget |  |

### `src/components/liquid_glass.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsLiquidGlass` | class | Opt-in host adapter, separate from the reference TDS controls. The iOS host |
| `TdsLiquidTab` | class |  |
| `TdsLiquidTabBar` | class extends StatelessWidget | Apple's system tab bar on supported iOS hosts; a TDS composition elsewhere. |
| `TdsGlassIconButton` | class extends StatelessWidget | Standard UIButton.Configuration.glass on iOS. No custom lens or shader. |

### `src/components/input_controls.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsSearchField` | class extends StatefulWidget |  |
| `TdsSliderLabel` | class |  |
| `TdsSlider` | class extends StatefulWidget |  |
| `TdsSliderTooltip` | class extends StatelessWidget |  |

### `src/components/date_picker.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `tdsDateOnly` | function |  |
| `tdsDaysInMonth` | function |  |
| `tdsClampDate` | function |  |
| `TdsWheelPerspective` | enum |  |
| `TdsWheel` | class extends StatefulWidget |  |
| `TdsWheelDateSheet` | class extends StatefulWidget |  |
| `TdsWheelDatePicker` | class extends StatefulWidget |  |
| `TdsDateRange` | class |  |
| `TdsDatePicker` | class extends StatelessWidget |  |
| `TdsDateRangePicker` | class extends StatelessWidget |  |

### `src/components/post.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsPost` | class | Namespace counterpart; each member is also a normal composable Dart widget. |
| `TdsPostHeading` | class extends StatelessWidget |  |
| `TdsPostH1` | class extends TdsPostHeading |  |
| `TdsPostH2` | class extends TdsPostHeading |  |
| `TdsPostH3` | class extends TdsPostHeading |  |
| `TdsPostH4` | class extends TdsPostHeading |  |
| `TdsPostParagraph` | class extends StatelessWidget |  |
| `TdsPostList` | class extends StatelessWidget |  |
| `TdsPostOl` | class extends TdsPostList |  |
| `TdsPostUl` | class extends TdsPostList |  |
| `TdsPostLi` | class extends StatelessWidget |  |
| `TdsPostHr` | class extends StatelessWidget |  |

### `src/components/stepper.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsStaggerIn` | class extends StatefulWidget |  |
| `TdsStepper` | class extends StatelessWidget |  |
| `TdsStepperRow` | class extends StatelessWidget |  |
| `TdsStepperTextType` | enum |  |
| `TdsStepperRowTexts` | class extends StatelessWidget |  |
| `TdsStepperRowNumberIcon` | class extends StatelessWidget |  |
| `TdsStepperRowAssetFrame` | class extends StatelessWidget |  |
| `TdsStepperRowRightArrow` | class extends StatelessWidget |  |
| `TdsStepperRowRightButton` | class extends StatelessWidget |  |
| `TdsProgressStepperVariant` | enum |  |
| `TdsProgressStepper` | class extends StatelessWidget |  |
| `TdsProgressStep` | class extends StatelessWidget |  |

### `src/components/charts.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsDoughnutData` | class |  |
| `TdsDoughnut` | class extends StatefulWidget |  |
| `TdsDoughnutLabel` | class extends StatelessWidget |  |
| `TdsDoughnutLabelPosition` | enum |  |
| `TdsDoughnutChart` | class extends StatelessWidget |  |
| `TdsBarTheme` | enum |  |
| `TdsBarItem` | class |  |
| `TdsBarChartFill` | class |  |
| `TdsAllBarFill` | class extends TdsBarChartFill |  |
| `TdsSingleBarFill` | class extends TdsBarChartFill |  |
| `TdsAutoBarFill` | class extends TdsBarChartFill |  |
| `TdsBarChart` | class extends StatelessWidget |  |

### `src/components/agreement.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsAgreementVariant` | enum |  |
| `TdsAgreementNecessityVariant` | enum |  |
| `TdsAgreementCheckboxVariant` | enum |  |
| `TdsAgreementMotionVariant` | enum |  |
| `TdsAgreementV4` | class extends StatelessWidget |  |
| `TdsAgreementText` | class extends StatelessWidget |  |
| `TdsAgreementNecessity` | class extends StatelessWidget |  |
| `TdsAgreementPressable` | class extends StatelessWidget |  |
| `TdsAgreementCheckbox` | class extends StatefulWidget |  |
| `TdsAgreementBadge` | class extends StatelessWidget |  |
| `TdsAgreementHeader` | class extends StatelessWidget |  |
| `TdsAgreementDescription` | class extends StatelessWidget |  |
| `TdsAgreementGroup` | class extends StatelessWidget |  |
| `TdsAgreementCollapsible` | class extends StatefulWidget |  |
| `TdsAgreementCollapsibleContent` | class extends StatelessWidget |  |
| `TdsAgreementCollapsibleTrigger` | class extends StatelessWidget |  |
| `TdsAgreementRightArrow` | class extends StatelessWidget |  |
| `TdsAgreementIndentPushable` | class extends StatefulWidget |  |
| `TdsAgreementIndentPushableContent` | class extends StatelessWidget |  |
| `TdsAgreementIndentPushableTrigger` | class extends StatelessWidget |  |
| `TdsAgreementV3Size` | enum |  |
| `TdsAgreementV3Arrow` | enum |  |
| `TdsAgreementV3Necessity` | enum |  |
| `TdsAgreementV3SingleField` | class extends StatelessWidget |  |
| `TdsAgreementV3SingleCheckboxField` | class extends StatefulWidget |  |
| `TdsAgreementV3Group` | class extends StatelessWidget |  |
| `TdsAgreementV3GroupItem` | class extends TdsAgreementV3SingleCheckboxField |  |
| `TdsAgreementV3Button` | class extends StatelessWidget |  |
| `TdsAgreementV3Tag` | class extends TdsText |  |
| `TdsAgreementV3Description` | class extends StatelessWidget |  |
| `TdsAgreementV3Collapsible` | class extends StatelessWidget |  |
| `TdsAgreementV3CollapsibleGroupController` | class extends ValueNotifier<bool> |  |
| `TdsAgreementV3CollapsibleGroup` | class extends StatelessWidget |  |
| `TdsAgreementV3` | class | Namespace counterpart for source AgreementV3; native compounds are named widgets. |

### `src/components/agreement_module.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsAgreementStep` | enum |  |
| `TdsAgreementCTAVariant` | enum |  |
| `TdsAgreementModuleOptions` | class |  |
| `TdsAgreementModuleProvider` | class extends StatefulWidget |  |
| `TdsAgreementModuleContent` | class extends StatelessWidget |  |
| `TdsAgreementModuleStagger` | class extends StatelessWidget |  |
| `TdsAgreementModuleTopTitle` | class extends StatelessWidget |  |
| `TdsAgreementModuleTop` | class extends StatelessWidget |  |
| `TdsAgreementApproveEvent` | class |  |
| `TdsAgreementModuleCTA` | class extends StatelessWidget |  |
| `TdsFullPageAgreementModule` | class extends StatelessWidget |  |
| `TdsBottomSheetAgreementModule` | class extends StatelessWidget |  |
| `TdsFloatButtonAgreementModule` | class extends StatefulWidget |  |
| `TdsGradientBottomSheetAgreementModule` | class extends StatelessWidget |  |

### `src/components/keypad.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsNumberKey` | enum |  |
| `TdsAlphabetKey` | class |  |
| `TdsNumberKeypad` | class extends StatelessWidget | Native keypads delegate capture protection to the injected secure-screen |
| `TdsAlphabetKeypad` | class extends StatelessWidget |  |
| `TdsSecureKeypadMode` | enum |  |
| `TdsSecureKeypadController` | class extends ChangeNotifier |  |
| `TdsFullSecureKeypad` | class extends StatefulWidget |  |

### `src/components/code_auth.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsCodeAuthStep` | enum |  |
| `TdsCodeValidator` | typedef |  |
| `TdsCodeAuthController` | class extends ChangeNotifier |  |
| `TdsCodeAuthModule` | class extends StatefulWidget |  |
| `TdsCodeAuthFieldController` | class extends StatefulWidget |  |
| `TdsCodeAuthField` | class extends StatefulWidget |  |
| `TdsCodeAuthModuleField` | class extends StatelessWidget |  |
| `TdsCodeAuthError` | class extends StatelessWidget |  |
| `TdsCodeAuthTop` | class extends StatelessWidget |  |
| `TdsCodeAuthTopTitle` | class extends TdsPostH2 |  |
| `TdsCodeAuthTopSubtitle` | class extends StatelessWidget |  |
| `TdsCodeAuthFixedBottomTextButton` | class extends StatelessWidget |  |

### `src/components/split_text_field.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsSplitInput` | class |  |
| `TdsSplitTextField` | class extends StatefulWidget |  |

### `src/foundation/anchored_overlay.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsOverlayPlacement` | enum |  |
| `TdsAnchoredOverlay` | class extends StatefulWidget | Native anchor geometry and overlay lifecycle. No DOM/global selector state. |

### `src/components/tooltip.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsBubbleBackground` | enum |  |
| `TdsBubble` | class extends StatelessWidget |  |
| `TdsTooltipSize` | enum |  |
| `TdsTooltipMotion` | enum |  |
| `TdsTooltipClip` | enum |  |
| `TdsTooltip` | class extends StatefulWidget |  |
| `TdsTooltipMotionSurface` | class extends StatefulWidget | Original 0→1 weak spring and 0→1.25→1 strong sequence. Kept mounted during |
| `TdsTooltipContent` | class extends StatelessWidget |  |

### `src/components/menu.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsMenu` | class |  |
| `TdsMenuTrigger` | class extends StatefulWidget |  |
| `TdsMenuDropdown` | class extends StatefulWidget |  |
| `TdsMenuDropdownItem` | class extends StatelessWidget |  |
| `TdsMenuDropdownCheckItem` | class extends StatelessWidget |  |
| `TdsMenuDropdownIcon` | class extends StatelessWidget |  |
| `TdsMenuHeader` | class extends StatelessWidget |  |

### `src/components/highlight.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsHighlightXAlignment` | enum |  |
| `TdsHighlightYAlignment` | enum |  |
| `TdsHighlight` | class extends StatefulWidget |  |
| `TdsHighlightUI` | class extends StatefulWidget | Wx/sne/tne: independent dimmer, cutout and message animation timelines. |
| `TdsHighlightMessage` | class extends TdsText |  |

### `src/components/point.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsPointPosition` | enum |  |
| `TdsPointOverlay` | class extends StatefulWidget |  |
| `TdsPointCTAOverlay` | class extends StatelessWidget |  |
| `TdsPointToast` | class extends StatefulWidget |  |

### `src/components/wiki_text.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsWikiText` | class extends StatefulWidget |  |

### `src/foundation/api_adapters.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `legacyTdsWebButtonClassName` | const | Legacy selector metadata for migration tooling; native widgets do not emit DOM. |
| `borderBottomWidthVar` | const |  |
| `colorVar` | const |  |
| `fontWeightVar` | const |  |
| `paragraphVariables` | const |  |
| `assignTextVariables` | function |  |
| `assignIconVariables` | function |  |
| `assignBadgeVariables` | function |  |
| `assignLinkVariables` | function |  |
| `TdsTypographyVariables` | class | Resolved values accompany CSS metadata so adapters can use them natively. |
| `useLimitedTdsMobileCSSVariables` | function |  |
| `useLimitedTdsWebCSSVariables` | function |  |
| `TdsTouchInsets` | class |  |
| `mapByTypeAndTypography` | const |  |
| `TdsThemeProvider` | class extends StatelessWidget |  |
| `TdsComponentBuilder` | typedef | React HOCs become typed builder decorators. Flutter's Key replaces a ref; |
| `TdsAs` | typedef | A strongly typed native alternative to React's polymorphic `as` component. |
| `TdsElementRef` | typedef |  |
| `TdsComponentWithAs` | class |  |
| `TdsProps` | class | Migration helpers for JS structural props. Immutable runtime maps replace |
| `TdsPropsOf` | class | Explicit typed props association in place of TS ComponentProps inference. |
| `forwardRefWithAs` | function |  |
| `TdsStyledWidget` | typedef |  |
| `styledText` | function |  |
| `styledButton` | function |  |
| `withLoadingSkeleton` | function |  |
| `TdsAccessoryButtonView` | class extends StatelessWidget | Source AccessoryButton is a side-effect-only component. Keep the existing |

### `src/foundation/overlay_controller.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsOverlayBuilder` | typedef |  |
| `TdsOverlayController` | class extends ChangeNotifier |  |
| `TdsOverlayProvider` | class extends StatefulWidget |  |
| `useOverlay_will_be_deleted` | function |  |

### `src/foundation/list_row_controller.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TdsListRowController` | class extends ChangeNotifier | Native counterpart of ListRowRef. A controller attaches to one row at a time; |
| `TdsListRowEffects` | class extends StatefulWidget | The child is the padded inner container, not the outer row. Blink is behind |
| `TdsListRowBlinkPainter` | class extends CustomPainter |  |
| `TdsListRowShinePainter` | class extends CustomPainter |  |

## 앱 공용 조합 위젯

TDS를 조합해 이미 만든 앱 위젯이다. 같은 역할의 위젯을 새로 만들지 말고 재사용한다.

### `lib/local/presentation/layout.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `FigmaSurfaceStyle` | enum |  |
| `HomeBackdrop` | class extends StatelessWidget | One continuous page canvas, including the header and system safe area. |
| `FigmaSurface` | class extends StatelessWidget | Layout-only surface from Figma 03 / 04 (radius 24). TDS has no card |
| `FigmaIcon` | class extends StatelessWidget | Original Figma assets and unmodified TDS action icons, bundled for offline |
| `PageHeading` | class extends StatelessWidget |  |
| `QuantityRow` | class extends StatelessWidget |  |

### `lib/local/presentation/common.dart`

| 심볼 | 종류 | 설명 |
| --- | --- | --- |
| `TabSaveGuard` | class |  |
| `TabSaveScope` | class extends InheritedWidget |  |
| `openPage` | function |  |
| `scrollToSection` | function |  |
| `PageFrame` | class extends StatelessWidget |  |
| `Section` | class extends StatelessWidget |  |
| `Inset` | class extends StatelessWidget |  |
| `AppSearchField` | class extends StatelessWidget | TDS 기본 형태와 여백에 앱 공통 색상·글꼴을 적용한다. |
| `Info` | class extends StatelessWidget |  |
| `Item` | class extends StatelessWidget |  |
| `StatusBadge` | class extends StatelessWidget |  |
| `ActionButton` | class extends StatefulWidget |  |
| `EmptyState` | class extends StatelessWidget |  |
| `Field` | class extends StatelessWidget |  |
| `Choices` | class extends StatelessWidget |  |
| `Toggle` | class extends StatelessWidget |  |
| `confirm` | function |  |
| `AttachmentPreview` | class extends StatefulWidget |  |
| `AttachmentField` | class extends StatelessWidget |  |
| `RequestCard` | class extends StatelessWidget |  |
| `FormSaver` | class extends ChangeNotifier | Serializes autosaves and retains failed input. Call flush before leaving. |
