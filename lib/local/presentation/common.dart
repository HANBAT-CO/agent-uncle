import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'layout.dart';
export 'layout.dart';

class TabSaveGuard {
  Future<void> Function()? save;
}

class TabSaveScope extends InheritedWidget {
  const TabSaveScope({required this.guard, required super.child, super.key});
  final TabSaveGuard guard;
  static TabSaveGuard? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabSaveScope>()?.guard;
  @override
  bool updateShouldNotify(TabSaveScope oldWidget) => guard != oldWidget.guard;
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(
      PageRouteBuilder<T>(pageBuilder: (context, animation, secondary) => page),
    );

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.back = true,
    this.scrollKey,
    super.key,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing, bottom;
  final bool back;
  final String? scrollKey;
  @override
  Widget build(BuildContext context) => TdsToastProvider(
    child: TdsDialogProvider(
      child: ColoredBox(
        color: TdsTheme.of(context).color('background'),
        child: Column(
          children: [
            TdsTopNavigation(
              leading: back ? const TdsTopNavigationBackButton() : null,
              content: Text(title),
              trailing: trailing,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: PageStorageKey(scrollKey ?? title),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: SafeArea(
                  top: false,
                  bottom: bottom == null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (subtitle != null) PageHeading(subtitle!),
                      ...children,
                      const TdsSpacing(24),
                    ],
                  ),
                ),
              ),
            ),
            if (bottom != null) SafeArea(top: false, child: bottom!),
          ],
        ),
      ),
    ),
  );
}

class Section extends StatelessWidget {
  const Section(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    child: TdsText(
      title,
      typography: TdsTypography.t5,
      fontWeight: TdsFontWeight.semibold,
    ),
  );
}

class Inset extends StatelessWidget {
  const Inset({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    child: child,
  );
}

class Info extends StatelessWidget {
  const Info(this.text, {this.error = false, super.key});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Inset(
    child: Semantics(
      liveRegion: error,
      child: TdsText(
        text,
        typography: TdsTypography.t6,
        color: error
            ? TdsPalette.red600
            : TdsTheme.of(context).color('grey600'),
      ),
    ),
  );
}

class Item extends StatelessWidget {
  const Item(this.title, {this.subtitle, this.trailing, this.onTap, super.key});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TdsListRow(
    contents: TdsListRowTexts(
      type: subtitle == null
          ? TdsListRowTextType.row1TypeA
          : TdsListRowTextType.row2TypeA,
      top: Text(title),
      bottom: subtitle == null ? null : Text(subtitle!),
    ),
    right: trailing,
    onPressed: onTap,
    withArrow: onTap != null && trailing == null,
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {this.attention = false, super.key});
  final String label;
  final bool attention;
  @override
  Widget build(BuildContext context) => TdsBadge(
    size: TdsBadgeSize.xsmall,
    color: attention ? TdsBadgeColor.red : TdsBadgeColor.blue,
    variant: TdsBadgeVariant.weak,
    child: Text(label),
  );
}

class ActionButton extends StatefulWidget {
  const ActionButton(
    this.label, {
    required this.onPressed,
    this.weak = false,
    this.danger = false,
    this.enabled = true,
    this.onError,
    this.bottom = false,
    super.key,
  });
  final String label;
  final FutureOr<void> Function() onPressed;
  final bool weak, danger, enabled, bottom;
  final ValueChanged<Object>? onError;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;
  String? error;
  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onPressed();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
      widget.onError?.call(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bottom) {
      return TdsBottomCTA(
        background: false,
        hasSafeAreaPadding: false,
        topAccessory: error == null ? null : Info(error!, error: true),
        color: widget.danger ? TdsButtonColor.danger : TdsButtonColor.primary,
        variant: widget.weak ? TdsButtonVariant.weak : TdsButtonVariant.fill,
        loading: busy,
        disabled: busy || !widget.enabled,
        onPressed: submit,
        child: Text(widget.label),
      );
    }
    return Inset(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) Info(error!, error: true),
          TdsButton(
            display: TdsButtonDisplay.block,
            variant: widget.weak
                ? TdsButtonVariant.weak
                : TdsButtonVariant.fill,
            color: widget.danger
                ? TdsButtonColor.danger
                : TdsButtonColor.primary,
            loading: busy,
            disabled: busy || !widget.enabled,
            onPressed: submit,
            child: Text(widget.label),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.description, {
    this.action,
    this.onAction,
    super.key,
  });
  final String title, description;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => TdsResult(
    title: Text(title),
    description: Text(description),
    button: action == null
        ? null
        : TdsResultButton(onPressed: onAction, child: Text(action!)),
  );
}

class Field extends StatelessWidget {
  const Field(
    this.label, {
    required this.controller,
    this.onChanged,
    this.numeric = false,
    this.multiline = false,
    this.error,
    super.key,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool numeric, multiline;
  final String? error;
  @override
  Widget build(BuildContext context) => Inset(
    child: TdsTextField(
      variant: TdsTextFieldVariant.box,
      label: label,
      labelOption: TdsTextFieldLabelOption.sustain,
      controller: controller,
      onChanged: onChanged,
      keyboardType: numeric
          ? TextInputType.number
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      multiline: multiline,
      hasError: error != null,
      help: error == null ? null : Text(error!),
      semanticLabel: label,
    ),
  );
}

class Choices extends StatelessWidget {
  const Choices({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Inset(
    child: TdsChip(
      wrap: true,
      margin: TdsChipMargin.none,
      children: [
        for (final option in options)
          TdsChipItem(
            text: option,
            selected: option == value,
            onPressed: () => onChanged(option),
          ),
      ],
    ),
  );
}

class Toggle extends StatelessWidget {
  const Toggle(
    this.label, {
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Item(
    label,
    trailing: TdsSwitch(
      checked: value,
      onChanged: onChanged,
      semanticLabel: label,
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String description,
) async {
  // Each route owns its provider; the dialog is always inside its Navigator.
  final controller = TdsDialogController();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => TdsDialogProvider(
      controller: controller,
      child: const SizedBox.shrink(),
    ),
  );
  overlay.insert(entry);
  final result = await controller.openConfirm(
    title: Text(title),
    description: Text(description),
  );
  entry.remove();
  entry.dispose();
  controller.dispose();
  return result;
}

class AttachmentPreview extends StatefulWidget {
  const AttachmentPreview(this.id, {this.compact = false, super.key});
  final String id;
  final bool compact;
  @override
  State<AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<AttachmentPreview> {
  Future<Uint8List>? future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.read(context).attachments.bytes(widget.id);
  }

  @override
  void didUpdateWidget(AttachmentPreview old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      future = AppScope.read(context).attachments.bytes(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = AppScope.of(
      context,
    ).workspace.snapshot.get('attachments', widget.id);
    if (meta == null) return const Info('첨부파일을 찾을 수 없어요.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Item(
          meta.s('name'),
          subtitle:
              '${(meta.n('size') / 1024).ceil()}KB${meta.s('mime') == 'application/pdf' ? ' · PDF 서류' : ''}',
        ),
        if (meta.s('mime').startsWith('image/'))
          Inset(
            child: FutureBuilder<Uint8List>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TdsText('사진을 열지 못했어요: ${snapshot.error}');
                }
                if (!snapshot.hasData) return const TdsLoader();
                return TdsAssetFrame(
                  shape: TdsAssetFrameShape(
                    width: widget.compact ? 120 : 280,
                    height: widget.compact ? 100 : 200,
                  ),
                  content: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) =>
                        const Text('사진 형식을 확인해 주세요.'),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class AttachmentField extends StatelessWidget {
  const AttachmentField({
    required this.label,
    required this.ids,
    required this.onChanged,
    this.document = false,
    this.multiple = false,
    super.key,
  });
  final String label;
  final List<String> ids;
  final ValueChanged<List<String>> onChanged;
  final bool document, multiple;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Section(label),
      for (final id in ids) ...[
        AttachmentPreview(id, compact: true),
        Inset(
          child: TdsTextButton(
            size: TdsTextButtonSize.small,
            onPressed: () => onChanged(ids.where((e) => e != id).toList()),
            child: const Text('첨부 삭제'),
          ),
        ),
      ],
      ActionButton(
        ids.isEmpty
            ? '$label 첨부'
            : multiple
            ? '사진 추가'
            : '$label 교체',
        weak: true,
        onPressed: () async {
          final id = await AppScope.read(
            context,
          ).attachments.pick(document: document);
          if (id != null && context.mounted) {
            onChanged(multiple ? [...ids, id] : [id]);
          }
        },
      ),
    ],
  );
}

class RequestCard extends StatelessWidget {
  const RequestCard(this.request, {required this.onTap, super.key});
  final RequestRecord request;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        peer = app.workspace.profile(
          request.s(
            app.session.current?.role == AppRole.retailer
                ? 'uncleId'
                : 'retailerId',
          ),
        );
    return FigmaSurface(
      children: [
        TdsListRow(
          left: const FigmaIcon('shirt'),
          contents: TdsListRowTexts(
            type: TdsListRowTextType.row2TypeA,
            top: Text('${request.s('product')} · ${request.s('option')}'),
            bottom: Text('${peer?.name ?? '거래처'} · 요청 ${request.quantity}장'),
          ),
          onPressed: onTap,
          withArrow: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                request.statusLabel,
                attention: request.needsReply || request.n('openIssues') > 0,
              ),
              TdsText(
                '확보 ${request.acquired} · ${request.b('resultShared') ? '미송 ${request.backorder}' : '미확인 ${request.remaining}'} · 전달 ${request.delivered}',
                typography: TdsTypography.t7,
              ),
            ],
          ),
        ),
        if (request.s('recheck').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: TdsText(
              '${request.s('recheck')} 재확인',
              typography: TdsTypography.t7,
              color: TdsTheme.of(context).color('grey600'),
            ),
          ),
      ],
    );
  }
}

/// Serializes autosaves and retains failed input. Call flush before leaving.
class FormSaver extends ChangeNotifier {
  FormSaver(this.save);
  final Future<void> Function(Data) save;
  Data? pending;
  String? error;
  bool saving = false;
  Future<void>? _running;
  void change(Data values) {
    pending = {...values};
    unawaited(flush().catchError((Object _) {}));
  }

  Future<void> flush() async {
    if (_running != null) {
      await _running;
      if (pending != null) return flush();
      return;
    }
    final next = pending;
    if (next == null) return;
    pending = null;
    saving = true;
    error = null;
    notifyListeners();
    final completer = Completer<void>();
    _running = completer.future;
    try {
      await save(next);
      completer.complete();
    } catch (e) {
      pending ??= next;
      error = e.toString();
      completer.complete();
      rethrow;
    } finally {
      _running = null;
      saving = false;
      notifyListeners();
    }
    if (pending != null) await flush();
  }
}
