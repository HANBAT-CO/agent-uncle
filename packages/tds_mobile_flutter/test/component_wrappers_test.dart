import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'interaction_test.dart' show app;

void main() {
  final source =
      jsonDecode(File('reference/component-wrappers.json').readAsStringSync())
          as Map;
  final records = (source['metadata'] as List).cast<Map>();

  test('all declared component IDs are absent in the pinned ESM runtime', () {
    expect(source['sourceVersion'], '2.5.1');
    final ids = records.where((entry) => entry['property'] == 'id').toList();
    expect(ids.length, 56);
    for (final entry in ids) {
      expect(entry['ownProperty'], false, reason: entry['source'] as String);
      expect(entry['valueType'], 'undefined');
      expect(entry['wrapper'], 'react.forward_ref');
    }
  });

  testWidgets('native component IDs are optional metadata, not widget keys', (
    tester,
  ) async {
    Widget builder(BuildContext context, String props, Key? key) =>
        Text(props, key: key);
    final missing = TdsComponentWithAs<String>(builder: builder);
    final identified = TdsComponentWithAs<String>(
      builder: builder,
      id: 'metadata',
    );
    expect(missing.id, isNull);
    expect(identified.id, 'metadata');
    expect(identical(identified.builder, builder), isTrue);
    const key = ValueKey('native-key');
    await tester.pumpWidget(
      app(Builder(builder: (context) => identified(context, '원문', key: key))),
    );
    expect(find.byKey(key), findsOneWidget);
    expect(find.byKey(const ValueKey('metadata')), findsNothing);
    expect(find.text('원문'), findsOneWidget);
  });

  test('memo type adapters expose all seven unwrapped native constructors', () {
    final memos = records
        .where((entry) => entry['property'] == 'type')
        .toList();
    final constructors = <String, Function>{
      'FullSecureKeypad.type': TdsFullSecureKeypad.new,
      'SearchField.type': TdsSearchField.new,
      'Post.H1.type': TdsPostH1.new,
      'Post.H2.type': TdsPostH2.new,
      'Post.H3.type': TdsPostH3.new,
      'Post.H4.type': TdsPostH4.new,
      'Post.Paragraph.type': TdsPostParagraph.new,
    };
    expect(
      memos.map((entry) => entry['source']),
      unorderedEquals(constructors.keys),
    );
    for (final entry in memos) {
      expect(entry['wrapper'], 'react.memo');
      expect(entry['innerWrapper'], 'react.forward_ref');
      expect(entry['renderType'], 'function');
      expect(entry['ownProperty'], true);
    }
    const key = ValueKey('unwrapped');
    final search = TdsSearchField.new;
    expect(search(value: '검색', key: key).value, '검색');
    expect(search(key: key).key, key);
    final keypad = TdsFullSecureKeypad.new;
    var submits = 0;
    final nativeKeypad = keypad(
      onKeyClick: (_) {},
      onBackspaceClick: () {},
      onSpaceClick: () {},
      onSubmit: () => submits++,
      key: key,
    );
    nativeKeypad.onSubmit();
    expect(submits, 1);
    expect(nativeKeypad.key, key);
    for (final constructor in [
      TdsPostH1.new,
      TdsPostH2.new,
      TdsPostH3.new,
      TdsPostH4.new,
    ]) {
      final heading = constructor('제목', key: key);
      expect(heading.text, '제목');
      expect(heading.key, key);
    }
    final paragraph = TdsPostParagraph.new;
    expect(paragraph('본문', key: key).text, '본문');
    expect(paragraph('본문', key: key).key, key);
  });
}
