import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../domain/service_regions.dart';
import 'common.dart';

class RegionSelectionPage extends StatefulWidget {
  const RegionSelectionPage({required this.title, this.value = '', super.key});

  final String title, value;

  @override
  State<RegionSelectionPage> createState() => _RegionSelectionPageState();
}

class _RegionSelectionPageState extends State<RegionSelectionPage> {
  late Set<String> selected = parseServiceAreas(widget.value);
  late String region = serviceRegions.keys.firstWhere(
    (name) => selected.any((area) => area == name || area.startsWith('$name ')),
    orElse: () => '서울',
  );
  late String? city = serviceRegions[region]!.keys.where((name) {
    final path = serviceCityPath(region, name);
    return selected.any((area) => area == path || area.startsWith('$path '));
  }).firstOrNull;

  void select(String area) => setState(() {
    selected = toggleServiceArea(selected, area);
  });

  Widget choices(List<Widget> children) => Inset(
    child: TdsChip(
      wrap: true,
      variant: TdsChipVariant.weak,
      margin: TdsChipMargin.none,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cities = serviceRegions[region]!;
    final metropolitan = cities.containsKey(region);
    final currentCity = metropolitan ? region : city;
    final districts = cities[currentCity] ?? const <String>[];
    final path = currentCity == null
        ? region
        : serviceCityPath(region, currentCity);
    return PageFrame(
      title: widget.title,
      bottom: ActionButton(
        '선택 완료${selected.isEmpty ? '' : ' · ${selected.length}곳'}',
        bottom: true,
        onPressed: () => Navigator.pop(context, selected.join(' · ')),
      ),
      children: [
        const PageHeading(
          '어느 지역에서 활동하시나요?',
          description: '시·도와 세부 지역을 눌러 주세요.\n여러 지역을 함께 선택할 수 있어요.',
        ),
        if (selected.isNotEmpty)
          FigmaSurface(
            children: [
              Section('선택한 지역 ${selected.length}곳'),
              for (final area in selected)
                TdsListRow(
                  key: ValueKey('selected-region-$area'),
                  contents: TdsListRowTexts(
                    type: TdsListRowTextType.row1TypeA,
                    top: Text(area),
                  ),
                  right: TdsTextButton(
                    size: TdsTextButtonSize.small,
                    semanticLabel: '$area 선택 해제',
                    onPressed: () => setState(() => selected.remove(area)),
                    child: const Text('해제'),
                  ),
                ),
            ],
          ),
        FigmaSurface(
          children: [
            const Section('시·도'),
            choices([
              for (final name in serviceRegions.keys)
                TdsChipItem(
                  text: name,
                  selected: region == name,
                  onPressed: () => setState(() {
                    region = name;
                    city = null;
                  }),
                ),
            ]),
            const TdsSpacing(12),
            choices([
              TdsChipItem(
                text: '$region 전체',
                selected: selected.contains(region),
                onPressed: () => select(region),
              ),
            ]),
            if (!metropolitan) ...[
              const Section('시·군'),
              choices([
                for (final name in cities.keys)
                  TdsChipItem(
                    text: name,
                    selected: cities[name]!.isEmpty
                        ? selected.contains(serviceCityPath(region, name))
                        : currentCity == name,
                    onPressed: () {
                      setState(() => city = name);
                      if (cities[name]!.isEmpty) {
                        select(serviceCityPath(region, name));
                      }
                    },
                  ),
              ]),
            ],
            if (districts.isNotEmpty) ...[
              Section(metropolitan ? '구·군' : '$currentCity · 구'),
              choices([
                if (!metropolitan)
                  TdsChipItem(
                    text: '$currentCity 전체',
                    selected: selected.contains(path),
                    onPressed: () => select(path),
                  ),
                for (final district in districts)
                  TdsChipItem(
                    text: district,
                    selected: selected.contains('$path $district'),
                    onPressed: () => select('$path $district'),
                  ),
              ]),
            ],
            if (region == '세종') const Info('세종시는 구 구분 없이 전체 지역을 선택해요.'),
          ],
        ),
        if (selected.any((area) => !serviceAreaPaths.contains(area)))
          const Info('이전에 입력한 지역도 함께 표시돼요. 바꾸려면 선택한 지역에서 해제해 주세요.'),
      ],
    );
  }
}
