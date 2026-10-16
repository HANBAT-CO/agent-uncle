import 'models.dart';

const convenienceCollections = [
  'favoriteWholesalers',
  'appReleases',
  'updateDismissals',
];

const convenienceCommands = [
  'convenience.upsertFavoriteWholesaler',
  'convenience.deleteFavoriteWholesaler',
];

const conveniencePaymentModeAdvance = 'advance';
const conveniencePaymentModeDirect = 'direct';
const conveniencePaymentModeReview = 'review';

const conveniencePaymentModes = [
  conveniencePaymentModeAdvance,
  conveniencePaymentModeDirect,
  conveniencePaymentModeReview,
];

const convenienceDefaultPaymentMode = conveniencePaymentModeReview;
const convenienceFavoriteCacheKey = 'convenience:favorites';
const convenienceUpdateDismissalsKey = 'convenience:update-dismissals';

const _convenienceSensitiveWholesalerKeys = [
  'fieldPaymentId',
  'invoiceId',
  'invoiceStatus',
  'invoiceReceiptId',
  'reimbursementId',
  'reimbursementStatus',
  'pickupJobId',
  'pickupJobStatus',
  'handoffId',
  'handoffStatus',
  'deliveryId',
  'receiptId',
  'actualPaidAmount',
  'customerChargeAmount',
  'directPaidAmount',
  'supplierFeeAmount',
  'paidAt',
  'settledAt',
  'reportedAt',
  'confirmedAt',
];

String normalizeConveniencePaymentMode(String value) {
  final mode = value.trim();
  return switch (mode) {
    conveniencePaymentModeAdvance ||
    'advance_request' => conveniencePaymentModeAdvance,
    conveniencePaymentModeDirect ||
    'direct_paid' => conveniencePaymentModeDirect,
    conveniencePaymentModeReview ||
    'needs_check' => conveniencePaymentModeReview,
    _ => convenienceDefaultPaymentMode,
  };
}

String conveniencePaymentModeLabel(String value) =>
    switch (normalizeConveniencePaymentMode(value)) {
      conveniencePaymentModeAdvance => '대납 요청',
      conveniencePaymentModeDirect => '직접 결제',
      _ => '확인 필요',
    };

String conveniencePaymentModeValueFromLabel(String label) => switch (label) {
  '대납 요청' => conveniencePaymentModeAdvance,
  '직접 결제' || '직접 결제 완료' => conveniencePaymentModeDirect,
  _ => conveniencePaymentModeReview,
};

String convenienceWholesalerLabel(Data row, {String fallback = '도매처'}) {
  final wholesaler = textOf(row, 'wholesaler').trim();
  final location = textOf(row, 'location').trim();
  if (wholesaler.isNotEmpty && location.isNotEmpty) {
    return '$wholesaler · $location';
  }
  if (wholesaler.isNotEmpty) return wholesaler;
  if (location.isNotEmpty) return location;
  return fallback;
}

bool hasConvenienceWholesalerValue(Data row) =>
    textOf(row, 'wholesaler').trim().isNotEmpty ||
    textOf(row, 'location').trim().isNotEmpty;

bool sameConvenienceWholesaler(Data left, Data right) =>
    textOf(left, 'wholesaler').trim() == textOf(right, 'wholesaler').trim() &&
    textOf(left, 'location').trim() == textOf(right, 'location').trim();

Data convenienceWholesalerRowOf(Data source) {
  final favoriteId = textOf(source, 'favoriteId').trim();
  return {
    'wholesaler': textOf(source, 'wholesaler').trim(),
    'location': textOf(source, 'location').trim(),
    'paymentMode': normalizeConveniencePaymentMode(
      textOf(source, 'paymentMode'),
    ),
    if (favoriteId.isNotEmpty) 'favoriteId': favoriteId,
  };
}

List<Data> convenienceWholesalerRows(
  Data source, {
  bool preserveEmpty = false,
}) {
  final rows = <Data>[];
  final raw = source['wholesalers'];
  if (raw is List) {
    for (final entry in raw) {
      if (entry is Map) {
        rows.add(
          convenienceWholesalerRowOf(
            Map<String, Object?>.from(
              entry.map((key, value) => MapEntry('$key', value)),
            ),
          ),
        );
      }
    }
  }
  if (rows.isEmpty) {
    rows.add(
      convenienceWholesalerRowOf({
        'wholesaler': textOf(source, 'wholesaler'),
        'location': textOf(source, 'location'),
        'paymentMode': textOf(source, 'paymentMode'),
        'favoriteId': textOf(source, 'favoriteId'),
      }),
    );
  }
  if (preserveEmpty) {
    return rows.isEmpty ? [convenienceWholesalerRowOf({})] : rows;
  }
  return rows.where(hasConvenienceWholesalerValue).toList(growable: false);
}

List<Data> dedupeConvenienceWholesalers(Iterable<Data> rows) {
  final result = <Data>[];
  for (final row in rows) {
    final normalized = convenienceWholesalerRowOf(row);
    if (!result.any((entry) => sameConvenienceWholesaler(entry, normalized))) {
      result.add(normalized);
    }
  }
  return result;
}

Data sanitizeReusableWholesaler(Data row) {
  final sanitized = Map<String, Object?>.from(convenienceWholesalerRowOf(row))
    ..['paymentMode'] = conveniencePaymentModeReview;
  for (final key in _convenienceSensitiveWholesalerKeys) {
    sanitized.remove(key);
  }
  return sanitized;
}

List<Data> sanitizeReusableWholesalers(Iterable<Data> rows) => [
  for (final row in rows) sanitizeReusableWholesaler(row),
];

Data convenienceFavoriteCachePayload(Iterable<Data> rows) => {
  'wholesalers': [for (final row in rows) convenienceWholesalerRowOf(row)],
};

List<Data> resolvedDraftWholesalers(
  WorkspaceRepository workspace,
  String draftId,
  Data draftData,
) {
  return convenienceWholesalerRows(draftData, preserveEmpty: true);
}

List<Data> resolvedRequestWholesalers(
  WorkspaceRepository workspace,
  String requestId,
  Data requestData,
) {
  return convenienceWholesalerRows(requestData, preserveEmpty: true);
}

class FavoriteWholesalerRecord extends Record {
  const FavoriteWholesalerRecord(super.id, super.data);

  String get ownerId => s('ownerId');
  String get wholesaler => s('wholesaler');
  String get location => s('location');
  String get paymentMode => normalizeConveniencePaymentMode(s('paymentMode'));
  String get label => convenienceWholesalerLabel(data);

  Data toWholesalerData() => {
    'favoriteId': id,
    'wholesaler': wholesaler,
    'location': location,
    'paymentMode': paymentMode,
  };
}

extension ConvenienceWorkspaceView on WorkspaceRepository {
  List<FavoriteWholesalerRecord> get favoriteWholesalers =>
      records('favoriteWholesalers')
          .map((row) => FavoriteWholesalerRecord(row.id, row.data))
          .toList(growable: false)
        ..sort(
          (left, right) => right.s('updatedAt').compareTo(left.s('updatedAt')),
        );

  FavoriteWholesalerRecord? favoriteWholesalerFor(Data row) {
    final normalized = convenienceWholesalerRowOf(row);
    for (final favorite in favoriteWholesalers) {
      if (sameConvenienceWholesaler(favorite.data, normalized)) return favorite;
    }
    return null;
  }

  Future<String> upsertFavoriteWholesaler(Data args, {String? operationId}) =>
      workflow(
        'wf.convenience.upsertFavoriteWholesaler',
        args,
        operationId ?? newId(),
      );

  Future<String> deleteFavoriteWholesaler(
    String favoriteId, {
    String? operationId,
  }) => workflow('wf.convenience.deleteFavoriteWholesaler', {
    'favoriteId': favoriteId,
  }, operationId ?? newId());

  Data favoriteWholesalerCache() => workflowInput(convenienceFavoriteCacheKey);

  Future<void> saveFavoriteWholesalerCache(Data values) =>
      saveWorkflowInput(convenienceFavoriteCacheKey, values);

  List<Data> mergedFavoriteWholesalerRows() {
    final rows = <Data>[
      for (final favorite in favoriteWholesalers) favorite.toWholesalerData(),
      ...convenienceWholesalerRows(
        favoriteWholesalerCache(),
        preserveEmpty: false,
      ),
    ];
    return dedupeConvenienceWholesalers(rows);
  }

  Data updateNoticeDismissalsInput() =>
      workflowInput(convenienceUpdateDismissalsKey);

  Future<void> saveUpdateNoticeDismissalsInput(Data values) =>
      saveWorkflowInput(convenienceUpdateDismissalsKey, values);
}
