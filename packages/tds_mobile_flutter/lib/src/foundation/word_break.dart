import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/foundation.dart'
    show listEquals, precisionErrorTolerance;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show CharacterBoundary, DocumentBoundary, ParagraphBoundary, TextBoundary;
import 'package:flutter/widgets.dart';

/// CSS keep-all layout string. Widgets also map selection offsets back to the
/// original text; callers must not use this transformed string as source data.
String tdsKeepAllText(String text) => _joinTextRun([text]).single;

bool _ordinaryTextSpan(InlineSpan span) =>
    span.runtimeType == TextSpan &&
    ((span as TextSpan).children?.every(_ordinaryTextSpan) ?? true);

bool _cjk(int rune) =>
    rune >= 0x1100 && rune <= 0x11ff ||
    rune >= 0x2e80 && rune <= 0xa4cf ||
    rune >= 0xac00 && rune <= 0xd7af ||
    rune >= 0xf900 && rune <= 0xfaff ||
    rune >= 0x20000 && rune <= 0x3134f;
final _word = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _mark = RegExp(r'\p{M}', unicode: true);

Iterable<int> _keepAllOffsets(String text) sync* {
  int? previous;
  var offset = 0;
  // A formatting character inside an extended grapheme can change shaping.
  // In particular, decomposed Hangul, combining marks and variation selectors
  // must stay intact even when their code units are split across TextSpans.
  for (final cluster in text.characters) {
    final first = cluster.runes.first;
    if (previous != null &&
        (_cjk(previous) || _cjk(first)) &&
        _word.hasMatch(String.fromCharCode(previous)) &&
        _word.hasMatch(String.fromCharCode(first))) {
      yield offset;
    }
    final last = cluster.runes.last;
    // Blink's keep-all test looks behind one BMP mark, not an arbitrary
    // sequence of extenders. Use the preceding UTF-16 code unit here too:
    // multiple marks and supplementary selectors do not inherit the base's
    // letter/number category. The joiner still belongs outside the grapheme.
    previous =
        last <= 0xffff &&
            cluster.length > 1 &&
            _mark.hasMatch(String.fromCharCode(last))
        ? cluster.codeUnitAt(cluster.length - 2)
        : last;
    offset += cluster.length;
  }
}

List<String> _joinTextRun(List<String> chunks) {
  final boundaries = _keepAllOffsets(chunks.join()).iterator;
  int? next = boundaries.moveNext() ? boundaries.current : null;
  var start = 0;
  final result = <String>[];
  for (final chunk in chunks) {
    StringBuffer? joined;
    var from = 0;
    while (next != null && next < start + chunk.length) {
      final index = next - start;
      joined ??= StringBuffer();
      joined.write(chunk.substring(from, index));
      joined.write('\u2060');
      from = index;
      next = boundaries.moveNext() ? boundaries.current : null;
    }
    start += chunk.length;
    if (joined == null) {
      result.add(chunk);
    } else {
      joined.write(chunk.substring(from));
      result.add(joined.toString());
    }
  }
  return result;
}

List<InlineSpan> _keepAllSpans(
  List<InlineSpan> spans, {
  required bool annotateSemantics,
}) {
  final chunks = <String?>[];
  void collect(InlineSpan span) {
    // Custom span subclasses may override shaping/semantics. Keep them and
    // inline widgets opaque, and never carry a word boundary through them.
    if (span.runtimeType != TextSpan) {
      chunks.add(null);
      return;
    }
    final text = span as TextSpan;
    if (text.text != null) chunks.add(text.text!);
    text.children?.forEach(collect);
  }

  spans.forEach(collect);
  final replacements = <String>[];
  final run = <String>[];
  for (final chunk in [...chunks, null]) {
    if (chunk != null) {
      run.add(chunk);
    } else if (run.isNotEmpty) {
      replacements.addAll(_joinTextRun(run));
      run.clear();
    }
  }

  var index = 0;
  InlineSpan rewrite(InlineSpan span) {
    if (span.runtimeType != TextSpan) return span;
    final source = span as TextSpan;
    final text = source.text == null ? null : replacements[index++];
    var children = source.children?.map(rewrite).toList(growable: false);
    if (children != null &&
        children.indexed.every(
          (entry) => identical(entry.$2, source.children![entry.$1]),
        )) {
      children = source.children;
    }
    return _copySpan(
      source,
      text,
      children,
      annotateSemantics: annotateSemantics,
    );
  }

  return spans.map(rewrite).toList(growable: false);
}

TextSpan _copySpan(
  TextSpan source,
  String? text,
  List<InlineSpan>? children, {
  bool annotateSemantics = true,
}) {
  if (text == source.text && identical(children, source.children)) {
    return source;
  }
  return TextSpan(
    text: text,
    children: children,
    style: source.style,
    recognizer: source.recognizer,
    mouseCursor: source.mouseCursor,
    onEnter: source.onEnter,
    onExit: source.onExit,
    semanticsLabel:
        source.semanticsLabel ??
        (annotateSemantics && text != source.text ? source.text : null),
    semanticsIdentifier: source.semanticsIdentifier,
    locale: source.locale,
    spellOut: source.spellOut,
  );
}

class TdsKeepAllText extends Text {
  TdsKeepAllText.from(this.source, {this.after = const []})
    : super(
        source.data ?? '',
        key: source.key,
        style: source.style,
        strutStyle: source.strutStyle,
        textAlign: source.textAlign,
        textDirection: source.textDirection,
        locale: source.locale,
        softWrap: source.softWrap,
        overflow: source.overflow,
        textScaler: source.textScaler,
        maxLines: source.maxLines,
        semanticsLabel: source.semanticsLabel,
        semanticsIdentifier: source.semanticsIdentifier,
        textWidthBasis: source.textWidthBasis,
        textHeightBehavior: source.textHeightBehavior,
        selectionColor: source.selectionColor,
      );
  final Text source;
  final List<InlineSpan> after;
  @override
  Widget build(BuildContext context) {
    final content = <InlineSpan>[
      if (source.data != null) TextSpan(text: source.data!),
      if (source.textSpan != null) source.textSpan!,
      ...after,
    ];
    final selectable = SelectionContainer.maybeOf(context) != null;
    final canMapSelection = content.every(_ordinaryTextSpan);
    // Opaque spans may expose their own selection/content model. Leave that
    // subtree completely untouched instead of applying offsets from its label.
    final spans = selectable && !canMapSelection
        ? content
        : _keepAllSpans(content, annotateSemantics: source.data == null);
    // Let Text resolve inherited styles, accessibility spacing and scaling.
    // The selectable path retains Text's own gesture/handle subtree. Its outer
    // delegate maps both keep-all joiners and width-dependent layout separators.
    final text = Text.rich(
      TextSpan(children: spans),
      style: source.style,
      strutStyle: source.strutStyle,
      textAlign: source.textAlign,
      textDirection: source.textDirection,
      locale: source.locale,
      softWrap: source.softWrap,
      overflow: source.overflow,
      textScaler: source.textScaler,
      maxLines: source.maxLines,
      textWidthBasis: source.textWidthBasis,
      textHeightBehavior: source.textHeightBehavior,
      selectionColor: source.selectionColor,
    );
    Widget result = selectable && canMapSelection
        ? _KeepAllSelection(
            source: TextSpan(
              children: content,
            ).toPlainText(includeSemanticsLabels: false),
            child: text,
          )
        : text.build(context);
    if (result is RichText) result = _KeepAllLayout(result);
    final semanticsLabel = source.semanticsLabel ?? source.data;
    if (semanticsLabel != null || source.semanticsIdentifier != null) {
      result = Semantics(
        textDirection: source.textDirection,
        label: semanticsLabel,
        identifier: source.semanticsIdentifier,
        child: ExcludeSemantics(
          excluding: semanticsLabel != null,
          child: result,
        ),
      );
    }
    return result;
  }
}

/// Preserve Flutter's normal selectable Text subtree, including its paragraph
/// gestures and handle layers. Only outward content/offsets are mapped. An
/// original U+2060 is retained; only positions inserted by _keepAllOffsets are
/// omitted, including at partial or reversed selection boundaries.
class _KeepAllSelection extends StatefulWidget {
  const _KeepAllSelection({required this.source, required this.child});
  final String source;
  final Widget child;

  @override
  State<_KeepAllSelection> createState() => _KeepAllSelectionState();
}

class _KeepAllSelectionState extends State<_KeepAllSelection> {
  late final _KeepAllSelectionDelegate delegate = _KeepAllSelectionDelegate(
    widget.source,
  );

  @override
  void didUpdateWidget(_KeepAllSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    delegate.source = widget.source;
  }

  @override
  void dispose() {
    delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionContainer(
    delegate: delegate,
    child: _KeepAllLayout.selectable(widget.child, delegate),
  );
}

class _KeepAllSelectionDelegate extends StaticSelectionContainerDelegate {
  _KeepAllSelectionDelegate(String source) {
    this.source = source;
  }
  String _source = '';
  List<int> _joinedOffsets = [0];
  List<int> _sourceOffsets = [0];
  RenderParagraph? _paragraph;
  SelectedContentRange? _pendingSelection;
  SelectedContentRange? _lastSelection;
  final List<SelectionEvent> _deferredEvents = [];
  TextRange? _originBoundary;
  var _layoutRevision = 0;
  var _disposed = false;
  var _hasEmergencyBreaks = false;

  set source(String value) {
    if (_source == value) return;
    _source = value;
    _pendingSelection = null;
    _lastSelection = null;
    _deferredEvents.clear();
    _originBoundary = null;
    _paragraph = null;
    _layoutRevision++;
    final joins = _keepAllOffsets(value).toSet();
    _joinedOffsets = [0];
    for (var index = 0; index < value.length; index++) {
      if (joins.contains(index)) _joinedOffsets.add(index);
      _joinedOffsets.add(index + 1);
    }
    _sourceOffsets = _joinedOffsets;
  }

  int _sourceOffset(int offset) =>
      _sourceOffsets[offset.clamp(0, _sourceOffsets.length - 1)];

  // Called before the live paragraph changes, while its old selection offsets
  // are still meaningful. Replaced spaces keep their offsets; inserted breaks
  // map to the same original position on either side of the break.
  void prepareLayout(RenderParagraph paragraph, _KeepAllFit fit) {
    final offsets = <int>[0];
    for (var index = 0; index < _joinedOffsets.length - 1; index++) {
      if (fit.splits.contains(index)) offsets.add(_joinedOffsets[index]);
      offsets.add(_joinedOffsets[index + 1]);
    }
    final changing =
        paragraph.text != fit.text || !listEquals(offsets, _sourceOffsets);
    if (changing && identical(_paragraph, paragraph)) {
      // Rebuilding an equivalent Text can replace its fitted paragraph with
      // the unmodified spans before this layout runs. Flutter has already
      // disposed the old selection fragments at that point. Retain the source
      // range captured after the last event instead of reading stale indices.
      _pendingSelection ??= _lastSelection;
    }
    _paragraph = paragraph;
    _sourceOffsets = offsets;
    _hasEmergencyBreaks = fit.hasBreaks;
  }

  // Text changes recreate Flutter's selectable fragments. Their own registrar
  // must finish its post-frame update before original offsets can be restored.
  void didLayout() {
    if (_pendingSelection == null && _deferredEvents.isEmpty) return;
    final revision = ++_layoutRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed ||
          revision != _layoutRevision ||
          _paragraph?.attached != true) {
        return;
      }
      if (!_childrenReady) {
        didLayout();
        return;
      }
      final selection = _pendingSelection;
      _pendingSelection = null;
      if (selection != null) _setRange(selection, dispatch: true);
      _flushDeferredEvents();
    });
    // A selection event may arrive in a post-frame callback, after the next
    // frame would otherwise have gone idle. Do not depend on an unrelated
    // animation or manually scheduled test frame to finish the registration.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool get _childrenReady =>
      selectables.isNotEmpty &&
      selectables.every((selectable) => selectable.contentLength > 0);

  void _flushDeferredEvents() {
    final events = _deferredEvents.toList(growable: false);
    _deferredEvents.clear();
    for (final event in events) {
      dispatchSelectionEvent(event);
    }
  }

  Rect? get _selectionBounds {
    final paragraph = _paragraph;
    if (paragraph == null || !paragraph.hasSize) return null;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: _sourceOffsets.length - 1),
      boxHeightStyle: BoxHeightStyle.max,
    );
    if (boxes.isEmpty) return null;
    return boxes
        .map((box) => box.toRect())
        .reduce((a, b) => a.expandToInclude(b));
  }

  Offset _point(int offset, {required bool downstream}) {
    var layoutOffset = downstream
        ? _sourceOffsets.lastIndexOf(offset)
        : _sourceOffsets.indexOf(offset);
    if (layoutOffset < 0) layoutOffset = _sourceOffsets.length - 1;
    final position = TextPosition(
      offset: layoutOffset,
      affinity: downstream ? TextAffinity.downstream : TextAffinity.upstream,
    );
    final paragraph = _paragraph!;
    final caret = paragraph.getOffsetForCaret(position, Rect.zero);
    var local =
        caret + Offset(0, paragraph.getFullHeightForCaret(position) / 2);
    final bounds = _selectionBounds;
    if (bounds != null) {
      // Rect.contains excludes its right/bottom edges. A synthesized caret
      // at the longest line's exact right edge would otherwise be interpreted
      // as a drag outside the fragment and jump to the end of the paragraph.
      if (bounds.width > precisionErrorTolerance &&
          bounds.height > precisionErrorTolerance) {
        local = Offset(
          local.dx.clamp(bounds.left, bounds.right - precisionErrorTolerance),
          local.dy.clamp(bounds.top, bounds.bottom - precisionErrorTolerance),
        );
      }
    }
    return paragraph.localToGlobal(local);
  }

  void _setRange(SelectedContentRange range, {bool dispatch = false}) {
    if (!_childrenReady) {
      // Source-based commands can report their logical result immediately,
      // even before the native fragments can paint it. SelectionArea reads
      // that result synchronously for onSelectionChanged and Copy.
      _pendingSelection = range;
      _lastSelection = range;
      didLayout();
      return;
    }
    final forward = range.startOffset <= range.endOffset;
    final events = [
      SelectionEdgeUpdateEvent.forStart(
        globalPosition: _point(range.startOffset, downstream: forward),
      ),
      SelectionEdgeUpdateEvent.forEnd(
        globalPosition: _point(range.endOffset, downstream: !forward),
      ),
    ];
    for (final event in events) {
      if (dispatch) {
        super.dispatchSelectionEvent(event);
      } else {
        super.handleSelectionEdgeUpdate(event);
      }
    }
    _alignSourceEdge(range.startOffset, isEnd: false, dispatch: dispatch);
    _alignSourceEdge(range.endOffset, isEnd: true, dispatch: dispatch);
    didReceiveSelectionBoundaryEvents();
  }

  void _alignSourceEdge(
    int target, {
    required bool isEnd,
    required bool dispatch,
  }) {
    // Distinct logical positions around a genuine zero-width source control
    // can have identical caret coordinates. Keep the native selection model,
    // then resolve that ambiguous hit with logical character events rather
    // than pretending the coordinate round-trip retained the original offset.
    for (var step = 0; step < _sourceOffsets.length; step++) {
      final range = _layoutSelection();
      if (range == null) return;
      final raw = isEnd ? range.endOffset : range.startOffset;
      final current = _sourceOffset(raw);
      if (current == target) return;
      final event = GranularlyExtendSelectionEvent(
        forward: current < target,
        isEnd: isEnd,
        granularity: TextGranularity.character,
      );
      if (dispatch) {
        super.dispatchSelectionEvent(event);
      } else {
        super.handleGranularlyExtendSelection(event);
      }
      final next = _layoutSelection();
      if (next == null || (isEnd ? next.endOffset : next.startOffset) == raw) {
        return;
      }
    }
  }

  int? _offsetAt(Offset globalPosition) {
    final paragraph = _paragraph;
    final bounds = _selectionBounds;
    if (paragraph == null || bounds == null) return null;
    final local = paragraph.globalToLocal(globalPosition);
    if (!bounds.contains(local)) return null;
    return _sourceOffset(paragraph.getPositionForOffset(local).offset);
  }

  TextPainter _naturalPainter() => TextPainter(
    text: TextSpan(text: _source, style: _paragraph!.text.style),
    textDirection: _paragraph!.textDirection,
    locale: _paragraph!.locale,
  )..layout();

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    if (event is ClearSelectionEvent) {
      _originBoundary = null;
      _lastSelection = null;
      _deferredEvents.clear();
    } else if (_source.isNotEmpty && !_childrenReady) {
      if (event is SelectAllSelectionEvent) {
        _deferredEvents.clear();
        _originBoundary = null;
        _setRange(
          SelectedContentRange(startOffset: 0, endOffset: _source.length),
        );
        return SelectionResult.none;
      }
      if (_deferredEvents.isEmpty &&
          event is GranularlyExtendSelectionEvent &&
          event.granularity != TextGranularity.line &&
          _paragraph != null) {
        return handleGranularlyExtendSelection(event);
      }
      // The Text delegate may still be registered while its old paragraph
      // fragments have already been disposed. Dispatching into that gap can
      // unregister it mid-event or index a missing fragment. Preserve incoming
      // order until the rebuilt fragments are available. Source-based
      // select-all and boundary movement above do not need to wait for them.
      _deferredEvents.add(event);
      didLayout();
      return SelectionResult.pending;
    } else if (_deferredEvents.isNotEmpty) {
      _flushDeferredEvents();
    }
    final pending = _pendingSelection;
    _pendingSelection = null;
    _layoutRevision++;
    if (pending != null &&
        event is! ClearSelectionEvent &&
        event is! SelectAllSelectionEvent) {
      _setRange(pending, dispatch: true);
    }
    final result = super.dispatchSelectionEvent(event);
    _lastSelection = getSelection();
    return result;
  }

  @override
  SelectionResult handleClearSelection(ClearSelectionEvent event) {
    // Text temporarily has no registered fragments after a rebuild. Clearing
    // its delegate can synchronously unregister that child, so traversing the
    // live list (as the base delegate does) would mutate it during iteration.
    for (final selectable in selectables.toList(growable: false)) {
      dispatchSelectionEventToChild(selectable, event);
    }
    currentSelectionStartIndex = -1;
    currentSelectionEndIndex = -1;
    clearInternalSelectionState();
    return SelectionResult.none;
  }

  @override
  SelectionResult handleSelectWord(SelectWordSelectionEvent event) {
    final offset = _hasEmergencyBreaks ? _offsetAt(event.globalPosition) : null;
    if (offset == null) return super.handleSelectWord(event);
    final painter = _naturalPainter();
    try {
      final word = painter.getWordBoundary(TextPosition(offset: offset));
      _originBoundary = word;
      _setRange(
        SelectedContentRange(startOffset: word.start, endOffset: word.end),
      );
      return SelectionResult.end;
    } finally {
      painter.dispose();
    }
  }

  @override
  SelectionResult handleSelectParagraph(SelectParagraphSelectionEvent event) {
    final offset = _hasEmergencyBreaks && !event.absorb
        ? _offsetAt(event.globalPosition)
        : null;
    if (offset == null) return super.handleSelectParagraph(event);
    final paragraph = ParagraphBoundary(_source).getTextBoundaryAt(offset);
    _originBoundary = TextRange(
      start: paragraph.start.clamp(0, _source.length),
      end: paragraph.end < 0 ? _source.length : paragraph.end,
    );
    _setRange(
      SelectedContentRange(
        startOffset: _originBoundary!.start,
        endOffset: _originBoundary!.end,
      ),
    );
    return SelectionResult.end;
  }

  @override
  SelectionResult handleSelectionEdgeUpdate(SelectionEdgeUpdateEvent event) {
    final granularity = event.granularity;
    if ((!_hasEmergencyBreaks && _originBoundary == null) ||
        _source.isEmpty ||
        (granularity != TextGranularity.word &&
            granularity != TextGranularity.paragraph)) {
      return super.handleSelectionEdgeUpdate(event);
    }
    final bounds = _selectionBounds;
    if (bounds == null || bounds.isEmpty) {
      return super.handleSelectionEdgeUpdate(event);
    }
    final paragraph = _paragraph!;
    final local = paragraph.globalToLocal(event.globalPosition);
    final adjusted = SelectionUtils.adjustDragOffset(
      bounds,
      local,
      direction: paragraph.textDirection,
    );
    final offset = _sourceOffset(
      paragraph.getPositionForOffset(adjusted).offset,
    );
    final TextRange boundary;
    if (granularity == TextGranularity.word) {
      final painter = _naturalPainter();
      try {
        boundary = painter.getWordBoundary(TextPosition(offset: offset));
      } finally {
        painter.dispose();
      }
    } else {
      final range = ParagraphBoundary(_source).getTextBoundaryAt(offset);
      boundary = TextRange(
        start: range.start.clamp(0, _source.length),
        end: range.end < 0 ? _source.length : range.end,
      );
    }
    final range = getSelection();
    final isEnd = event.type == SelectionEventType.endEdgeUpdate;
    var opposite = isEnd ? range?.startOffset : range?.endOffset;
    final origin = _originBoundary;
    int target;
    if (origin != null && offset >= origin.start && offset < origin.end) {
      // Word/paragraph dragging must keep its original whole boundary selected,
      // even when it is painted on several emergency lines.
      final forward = range == null || range.startOffset <= range.endOffset;
      target = isEnd == forward ? origin.end : origin.start;
      opposite = isEnd == forward ? origin.start : origin.end;
    } else {
      if (origin != null) {
        opposite = offset < origin.start ? origin.end : origin.start;
      }
      target = opposite == null
          ? (offset - boundary.start < boundary.end - offset
                ? boundary.start
                : boundary.end)
          : (offset < opposite ? boundary.start : boundary.end);
      opposite ??= target;
    }
    _setRange(
      SelectedContentRange(
        startOffset: isEnd ? opposite : target,
        endOffset: isEnd ? target : opposite,
      ),
    );
    return SelectionUtils.getResultBasedOnRect(bounds, local);
  }

  @override
  SelectionResult handleGranularlyExtendSelection(
    GranularlyExtendSelectionEvent event,
  ) {
    if (_paragraph == null ||
        _source.isEmpty ||
        event.granularity == TextGranularity.line) {
      return super.handleGranularlyExtendSelection(event);
    }
    final initial = event.forward ? 0 : _source.length;
    final range =
        getSelection() ??
        SelectedContentRange(startOffset: initial, endOffset: initial);
    final edge = event.isEnd ? range.endOffset : range.startOffset;
    if (event.forward && edge == _source.length) return SelectionResult.next;
    if (!event.forward && edge == 0) return SelectionResult.previous;
    TextPainter? painter;
    final TextBoundary boundary;
    switch (event.granularity) {
      case TextGranularity.character:
        boundary = CharacterBoundary(_source);
      case TextGranularity.word:
        painter = _naturalPainter();
        boundary = painter.wordBoundaries.moveByWordBoundary;
      case TextGranularity.paragraph:
        boundary = ParagraphBoundary(_source);
      case TextGranularity.document:
        boundary = DocumentBoundary(_source);
      case TextGranularity.line:
        throw StateError('Line movement is handled by the native paragraph.');
    }
    try {
      final next = event.forward
          ? boundary.getTrailingTextBoundaryAt(edge) ?? _source.length
          : boundary.getLeadingTextBoundaryAt(edge - 1) ?? 0;
      _setRange(
        SelectedContentRange(
          startOffset: event.isEnd ? range.startOffset : next,
          endOffset: event.isEnd ? next : range.endOffset,
        ),
      );
      if (event.granularity == TextGranularity.document) {
        return event.forward ? SelectionResult.next : SelectionResult.previous;
      }
      return SelectionResult.end;
    } finally {
      painter?.dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingSelection = null;
    _lastSelection = null;
    _deferredEvents.clear();
    _paragraph = null;
    super.dispose();
  }

  @override
  int get contentLength => _source.length;

  @override
  SelectionGeometry getSelectionGeometry() {
    // Layout-only fragment replacement does not remove the logical content.
    // Keep this container registered with its parent throughout that gap,
    // including when the parent is itself traversing children to clear them.
    return super.getSelectionGeometry().copyWith(
      hasContent: _source.isNotEmpty,
    );
  }

  SelectedContentRange? _layoutSelection() {
    final start = currentSelectionStartIndex;
    final end = currentSelectionEndIndex;
    if (start < 0 ||
        end < 0 ||
        start >= selectables.length ||
        end >= selectables.length) {
      return null;
    }
    // The parent's indices can outlive a child's selected fragments between
    // Text.updateRenderObject and the registrar's post-frame reconciliation.
    if (selectables[start].getSelection() == null ||
        selectables[end].getSelection() == null) {
      return null;
    }
    return super.getSelection();
  }

  @override
  SelectedContentRange? getSelection() {
    if (_pendingSelection != null) return _pendingSelection;
    final range = _layoutSelection();
    if (range == null) return null;
    return SelectedContentRange(
      startOffset: _sourceOffset(range.startOffset),
      endOffset: _sourceOffset(range.endOffset),
    );
  }

  @override
  SelectedContent? getSelectedContent() {
    final range = getSelection();
    if (range == null) return null;
    final forward = range.startOffset <= range.endOffset;
    return SelectedContent(
      plainText: _source.substring(
        forward ? range.startOffset : range.endOffset,
        forward ? range.endOffset : range.startOffset,
      ),
    );
  }
}

class _KeepAllLayout extends SingleChildRenderObjectWidget {
  _KeepAllLayout(RichText child)
    : source = child.text,
      selection = null,
      super(child: child);
  const _KeepAllLayout.selectable(Widget child, this.selection)
    : source = null,
      super(child: child);
  final InlineSpan? source;
  final _KeepAllSelectionDelegate? selection;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _KeepAllLayoutBox(source, selection);
  @override
  void updateRenderObject(
    BuildContext context,
    _KeepAllLayoutBox renderObject,
  ) {
    renderObject
      ..source = source
      ..selection = selection;
  }
}

class _KeepAllFit {
  const _KeepAllFit(
    this.text, {
    this.splits = const {},
    this.hasBreaks = false,
  });
  final InlineSpan text;
  final Set<int> splits;
  final bool hasBreaks;
}

/// SkParagraph's emergency breaking can append part of an oversized word to
/// the previous line, ignoring an otherwise valid space break. CSS anywhere
/// uses that space first. Resolve the width-dependent separators before the
/// standard RenderParagraph lays out/paints/hit-tests the same rewritten tree.
/// Emergency line endings are reshaped with their original style ancestry.
/// Its selection delegate separately maps all layout-only positions to source.
class _KeepAllLayoutBox extends RenderProxyBox {
  _KeepAllLayoutBox(this._explicitSource, this._selection);
  InlineSpan? _explicitSource;
  InlineSpan? _resolvedSource;
  InlineSpan? _lastFitted;
  RenderParagraph? _resolvedParagraph;
  _KeepAllSelectionDelegate? _selection;
  set source(InlineSpan? value) {
    if (identical(_explicitSource, value)) return;
    _explicitSource = value;
    markNeedsLayout();
  }

  set selection(_KeepAllSelectionDelegate? value) {
    if (identical(_selection, value)) return;
    _selection = value;
    markNeedsLayout();
  }

  RenderParagraph get _paragraph {
    RenderParagraph? paragraph;
    void visit(RenderObject node) {
      if (paragraph != null) return;
      if (node is RenderParagraph) {
        paragraph = node;
      } else {
        node.visitChildren(visit);
      }
    }

    visit(child!);
    return paragraph!;
  }

  InlineSpan get _sourceText {
    if (_explicitSource != null) return _explicitSource!;
    final paragraph = _paragraph;
    if (!identical(paragraph, _resolvedParagraph) ||
        !identical(paragraph.text, _lastFitted)) {
      _resolvedSource = paragraph.text;
      _resolvedParagraph = paragraph;
    }
    return _resolvedSource!;
  }

  bool _supported(InlineSpan span) => _ordinaryTextSpan(span);

  TextPainter _painter(InlineSpan text) => TextPainter(
    text: text,
    textAlign: _paragraph.textAlign,
    textDirection: _paragraph.textDirection,
    textScaler: _paragraph.textScaler,
    maxLines: _paragraph.maxLines,
    ellipsis: _paragraph.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    locale: _paragraph.locale,
    strutStyle: _paragraph.strutStyle,
    textWidthBasis: _paragraph.textWidthBasis,
    textHeightBehavior: _paragraph.textHeightBehavior,
  );

  // Measure a logical fragment with its original style/locale ancestry. This
  // reshapes line-ending kerning (e.g. nT), rather than reusing full-word glyph
  // advances that still include a character on the next line.
  TextSpan _fragment(int start, int end) {
    var offset = 0;
    TextSpan visit(TextSpan source) {
      final text = source.text;
      String? slice;
      if (text != null) {
        final from = (start - offset).clamp(0, text.length);
        final to = (end - offset).clamp(0, text.length);
        slice = text.substring(from, to);
        offset += text.length;
      }
      return TextSpan(
        text: slice,
        style: source.style,
        locale: source.locale,
        children: source.children
            ?.map((child) => visit(child as TextSpan))
            .toList(),
      );
    }

    return visit(_sourceText as TextSpan);
  }

  _KeepAllFit _fitWords(double width) {
    // A forced separator is not a justified soft break. Custom spans may also
    // override shaping/offset behavior, so do not rewrite either of those.
    if (!_paragraph.softWrap ||
        !width.isFinite ||
        width <= 0 ||
        _paragraph.textAlign == TextAlign.justify) {
      return _KeepAllFit(_sourceText);
    }
    // Inline widgets and custom spans retain the native path. Their intrinsic
    // layout need not be dry-computable and their glyph offsets can be custom.
    if (!_supported(_sourceText)) return _KeepAllFit(_sourceText);
    final raw = _sourceText.toPlainText(includeSemanticsLabels: false);
    final graphemes = <int>{0};
    var graphemeOffset = 0;
    for (final cluster in raw.characters) {
      graphemeOffset += cluster.length;
      graphemes.add(graphemeOffset);
    }
    final words = RegExp(
      r'[\p{L}\p{N}\p{M}\u200c\u200d\u2060]+',
      unicode: true,
    );
    final candidates = <({int start, int end, bool internalBoundary})>[];
    for (final word in words.allMatches(raw)) {
      if (!graphemes.contains(word.start) ||
          !graphemes.contains(word.end) ||
          word.start != 0 &&
              !const [
                0x20,
                0x0a,
                0x0d,
              ].contains(raw.codeUnitAt(word.start - 1))) {
        continue;
      }
      var start = word.start;
      var offset = start;
      int? previous;
      var previousEndsInZwj = false;
      for (final cluster in raw.substring(word.start, word.end).characters) {
        final first = cluster.runes.first;
        // Keep-all boundaries already contain joiners. Do not recombine
        // unjoined East Asian clusters (e.g. a supplementary selector followed
        // by Latin) into one oversized word: the source can break there normally.
        if (previous != null &&
            !previousEndsInZwj &&
            previous != 0x2060 &&
            first != 0x2060 &&
            (_cjk(previous) || _cjk(first))) {
          candidates.add((
            start: start,
            end: offset,
            internalBoundary: start != word.start,
          ));
          start = offset;
        }
        previous = first;
        // Unlike ZWNJ, ZWJ prevents a normal line break after its cluster
        // (UAX #14 LB8a), even though it is not a letter/number for keep-all.
        previousEndsInZwj = cluster.runes.last == 0x200d;
        offset += cluster.length;
      }
      candidates.add((
        start: start,
        end: word.end,
        internalBoundary: start != word.start,
      ));
    }
    if (candidates.isEmpty) return _KeepAllFit(_sourceText);

    final measure = _painter(_sourceText)
      ..maxLines = null
      ..ellipsis = null
      ..textAlign = TextAlign.left
      ..layout();
    final separators = <int>{};
    final splits = <int>{};
    try {
      final oversized = candidates.where((word) {
        final boxes = measure.getBoxesForSelection(
          TextSelection(baseOffset: word.start, extentOffset: word.end),
        );
        final wordWidth = boxes.fold<double>(
          0,
          (sum, box) => sum + box.right - box.left,
        );
        return wordWidth > width + precisionErrorTolerance;
      }).toList();
      final widths = <(int, int), double>{};
      double fragmentWidth(int start, int end) =>
          widths.putIfAbsent((start, end), () {
            measure.text = _fragment(start, end);
            measure.layout();
            return measure.width;
          });
      for (final word in oversized) {
        if (word.internalBoundary) splits.add(word.start);
        var previous = word.start - 1;
        while (previous >= 0 && raw.codeUnitAt(previous) == 0x20) {
          previous--;
        }
        if (previous >= 0 &&
            previous < word.start - 1 &&
            raw.codeUnitAt(previous) != 0x0a &&
            raw.codeUnitAt(previous) != 0x0d) {
          separators.add(word.start - 1);
        }
        final boundaries = <int>[word.start];
        var offset = word.start;
        for (final cluster in raw.substring(word.start, word.end).characters) {
          offset += cluster.length;
          if (cluster == '\u2060') {
            if (boundaries.length > 1) {
              boundaries[boundaries.length - 1] = offset;
            }
          } else {
            boundaries.add(offset);
          }
        }
        var from = 0;
        while (from < boundaries.length - 1) {
          // Start with the full-context break, then reshape its ending and
          // backtrack if necessary. Blink does not grow a line beyond that
          // initial break just because removing end kerning frees some space.
          measure.text = _fragment(boundaries[from], word.end);
          measure.layout(maxWidth: width);
          final end =
              boundaries[from] +
              measure.getLineBoundary(const TextPosition(offset: 0)).end;
          var fit = from + 1; // An oversized grapheme stays indivisible.
          while (fit + 1 < boundaries.length && boundaries[fit + 1] <= end) {
            fit++;
          }
          while (fit > from + 1 &&
              fragmentWidth(boundaries[from], boundaries[fit]) >
                  width + precisionErrorTolerance) {
            fit--;
          }
          if (fit < boundaries.length - 1) splits.add(boundaries[fit]);
          from = fit;
        }
      }
    } finally {
      measure.dispose();
    }
    if (separators.isEmpty && splits.isEmpty) return _KeepAllFit(_sourceText);

    var offset = 0;
    InlineSpan rewrite(InlineSpan span) {
      final source = span as TextSpan;
      var text = source.text;
      if (text != null) {
        final units = text.codeUnits;
        final result = StringBuffer();
        for (var i = 0; i < units.length; i++) {
          if (splits.contains(offset + i)) result.write('\n');
          result.writeCharCode(
            separators.contains(offset + i) ? 0x0a : units[i],
          );
        }
        offset += units.length;
        text = result.toString();
      }
      var children = source.children?.map(rewrite).toList(growable: false);
      if (children != null &&
          children.indexed.every(
            (entry) => identical(entry.$2, source.children![entry.$1]),
          )) {
        children = source.children;
      }
      return _copySpan(source, text, children);
    }

    return _KeepAllFit(rewrite(_sourceText), splits: splits, hasBreaks: true);
  }

  double _maxWidth(double width) =>
      _paragraph.softWrap || _paragraph.overflow == TextOverflow.ellipsis
      ? width
      : double.infinity;

  TextPainter _dryPainter(BoxConstraints constraints) {
    return _painter(_fitWords(constraints.maxWidth).text)..layout(
      minWidth: constraints.minWidth,
      maxWidth: _maxWidth(constraints.maxWidth),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (!_supported(_sourceText)) return super.computeDryLayout(constraints);
    final painter = _dryPainter(constraints);
    try {
      return constraints.constrain(painter.size);
    } finally {
      painter.dispose();
    }
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    if (!_supported(_sourceText)) {
      return super.computeDryBaseline(constraints, baseline);
    }
    final painter = _dryPainter(constraints);
    try {
      return painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    } finally {
      painter.dispose();
    }
  }

  double _intrinsicWidth(bool minimum, double height) {
    if (!_supported(_sourceText)) {
      return minimum
          ? super.computeMinIntrinsicWidth(height)
          : super.computeMaxIntrinsicWidth(height);
    }
    final painter = _painter(_sourceText)..layout();
    try {
      return minimum ? painter.minIntrinsicWidth : painter.maxIntrinsicWidth;
    } finally {
      painter.dispose();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth(true, height);
  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth(false, height);
  @override
  double computeMinIntrinsicHeight(double width) =>
      computeDryLayout(BoxConstraints.tightFor(width: width)).height;
  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void performLayout() {
    final fit = _fitWords(constraints.maxWidth);
    _selection?.prepareLayout(_paragraph, fit);
    if (_paragraph.text != fit.text) {
      // Flutter's synchronous layout callback permits width-dependent subtree
      // updates. The child has not been laid out yet and is laid out once below.
      invokeLayoutCallback<BoxConstraints>((_) => _paragraph.text = fit.text);
    }
    _lastFitted = _paragraph.text;
    super.performLayout();
    _selection?.didLayout();
  }
}
