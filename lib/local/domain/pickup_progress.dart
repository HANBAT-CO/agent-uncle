import 'models.dart';

/// 포장 종류·수량을 합산하지 않고 도매처별 요청을 한 상태에만 집계한다.
String pickupProgressStatus(Data data) {
  final packages = dataRowsOf(data, 'packages');
  if (packages.isEmpty) return 'pending';
  if (!flagOf(data, 'scopeConfirmed') ||
      flagOf(data, 'hasBackorder') ||
      numberOf(data, 'expectedPackageCount') <= 0 ||
      packages.length != numberOf(data, 'expectedPackageCount')) {
    return 'partial';
  }
  if (packages.any(
    (p) => !{
      'picked',
      'held',
      'handoff_requested',
      'delivery_ready',
      'delivered',
      'received',
    }.contains(textOf(p, 'status')),
  )) {
    return 'partial';
  }
  if (packages.every((p) => textOf(p, 'status') == 'received')) {
    return 'received';
  }
  if (packages.every(
    (p) => {'delivered', 'received'}.contains(textOf(p, 'status')),
  )) {
    return 'delivered';
  }
  return 'picked';
}

List<Data> dataRowsOf(Data data, String key) => [
  for (final value in (data[key] as List? ?? const []))
    if (value is Map) Map<String, Object?>.from(value),
];

String pickupProgressLabel(String status) => switch (status) {
  'picked' => '픽업 완료',
  'delivered' => '전달 완료',
  'received' => '수령 확인',
  'partial' => '부분 처리 · 확인 필요',
  _ => '픽업 전',
};

/// 로컬 모드에서도 팀 내부 기록 전체를 소매업자에게 노출하지 않는다.
List<Record> projectRetailerPickups(WorkspaceSnapshot snapshot, String actor) {
  final result = <Record>[];
  for (final request in snapshot.all('requests')) {
    if (request.s('retailerId') != actor ||
        !{'accepted', 'completed'}.contains(request.s('status'))) {
      continue;
    }
    final wholesalers = requestWholesalers(request.data);
    for (var index = 0; index < wholesalers.length; index++) {
      final jobs = snapshot
          .all('teamJobs')
          .where(
            (r) =>
                r.s('requestId') == request.id &&
                r.n('wholesalerIndex') == index &&
                r.s('status') != 'archived',
          )
          .toList();
      final job = jobs.length == 1 ? jobs.single : null;
      final packages = <Data>[
        if (job != null)
          for (final p in snapshot.all('teamPackages'))
            if (p.s('jobId') == job.id && p.s('retailerId') == actor)
              {
                'id': p.id,
                for (final key in [
                  'packageLabel',
                  'quantity',
                  'unit',
                  'status',
                  'version',
                  'receiptNote',
                ])
                  if (p.data.containsKey(key)) key: p.data[key],
              },
      ];
      final data = <String, Object?>{
        'requestId': request.id,
        'jobId': job?.id ?? '',
        'wholesalerIndex': index,
        'wholesalerName': textOf(wholesalers[index], 'wholesaler'),
        'createdAt': request.s('createdAt'),
        'scopeConfirmed': job?.b('scopeConfirmed') ?? false,
        'expectedPackageCount': job?.n('expectedPackageCount') ?? 0,
        'hasBackorder': job?.b('hasBackorder') ?? false,
        'openIssues': request.n('openIssues'),
        'packages': packages,
      };
      data['status'] = pickupProgressStatus(data);
      result.add(Record('${request.id}:$index', data));
    }
  }
  return result;
}
