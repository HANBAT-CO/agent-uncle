import 'package:agent_uncle/local/domain/service_regions.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/region_selection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../support/service_region_picker.dart';
import 'brand_surfaces_test.dart' show branded;

void main() {
  test('전체 지역을 선택하면 하위 지역만 정리하고 다른 지역과 이전 입력은 보존한다', () {
    final previous = parseServiceAreas('서울 종로구 · 서울 중구 · 대전 유성구 · 동대문 1층');
    final allSeoul = toggleServiceArea(previous, '서울');
    expect(allSeoul, {'서울', '대전 유성구', '동대문 1층'});
    final district = toggleServiceArea(allSeoul, '서울 강남구');
    expect(district, {'서울 강남구', '대전 유성구', '동대문 1층'});
    expect(previous, {'서울 종로구', '서울 중구', '대전 유성구', '동대문 1층'});
    expect(toggleServiceArea(district, '동대문 1층'), {'서울 강남구', '대전 유성구'});
  });

  test('시·군·구의 상하위 중복을 제거하고 같은 지역을 다시 누르면 해제한다', () {
    var selected = <String>{'경기 수원시 영통구', '경기 수원시 권선구', '경기 용인시 수지구'};
    selected = toggleServiceArea(selected, '경기 수원시');
    expect(selected, {'경기 수원시', '경기 용인시 수지구'});
    selected = toggleServiceArea(selected, '경기 수원시 영통구');
    expect(selected, {'경기 수원시 영통구', '경기 용인시 수지구'});
    selected = toggleServiceArea(selected, '경기');
    expect(selected, {'경기'});
    expect(toggleServiceArea(selected, '경기'), isEmpty);
    expect(toggleServiceArea(selected, '새로운 자유 입력'), selected);
  });

  test('지역 문자열의 공백·중복·빈 값을 정리한다', () {
    expect(parseServiceAreas('  서울 · 서울 ·  · 대전 유성구  '), {'서울', '대전 유성구'});
    expect(parseServiceAreas(''), isEmpty);
    expect(serviceCityPath('서울', '서울'), '서울');
    expect(serviceCityPath('경기', '수원시'), '경기 수원시');
  });

  testWidgets('지역 재진입은 기존 시·구를 복원하고 선택 완료 때만 부모 값을 바꾼다', (tester) async {
    var saved = '경기 수원시 영통구 · 동대문 1층';
    await tester.pumpWidget(
      branded(
        StatefulBuilder(
          builder: (context, setState) => PageFrame(
            title: '가입 정보',
            back: false,
            children: [
              Info(saved),
              ActionButton(
                '지역 선택',
                onPressed: () async {
                  final value = await openPage<String>(
                    context,
                    RegionSelectionPage(title: '도매 픽업 지역', value: saved),
                  );
                  if (value != null) setState(() => saved = value);
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('지역 선택'));
    await tester.pumpAndSettle();
    for (final label in ['경기', '수원시', '영통구']) {
      expect(
        tester
            .widget<TdsChipItem>(find.widgetWithText(TdsChipItem, label))
            .selected,
        isTrue,
      );
    }
    await tapRegionChoice(tester, '서울');
    await tapRegionChoice(tester, '종로구');
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await tester.pumpAndSettle();
    expect(saved, '경기 수원시 영통구 · 동대문 1층');

    await tester.tap(find.text('지역 선택'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-region-서울 종로구')), findsNothing);
    await tapRegionChoice(tester, '대전');
    await tapRegionChoice(tester, '유성구');
    expect(find.text('선택 완료 · 3곳'), findsOneWidget);
    await completeRegionSelection(tester);
    expect(saved, '경기 수원시 영통구 · 동대문 1층 · 대전 유성구');
    expect(find.byType(RegionSelectionPage), findsNothing);
    expect(find.text(saved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
