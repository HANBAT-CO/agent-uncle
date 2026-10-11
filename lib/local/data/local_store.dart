import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../domain/models.dart';

class MutableWorkspace {
  MutableWorkspace(this.tables);
  final Map<String, Map<String, Data>> tables;
  Data require(String table, String id) =>
      tables[table]?[id] ??
      (throw const AppFailure('기록을 찾을 수 없어요. 목록을 다시 확인해 주세요.'));
  Iterable<MapEntry<String, Data>> all(String table) => tables[table]!.entries;
  void put(String table, String id, Data value) => tables[table]![id] = value;
  void remove(String table, String id) => tables[table]!.remove(id);
}

class LocalStore extends ChangeNotifier {
  LocalStore(this.database);
  final Database database;
  WorkspaceSnapshot snapshot = const WorkspaceSnapshot({});
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _closed = false;
  Future<void> _reloadQueue = Future.value();
  // Injectable failure before committing any records; used by transaction tests.
  bool failNextWrite = false;
  StoreRef<String, Data> table(String name) =>
      stringMapStoreFactory.store(name);

  Future<Map<String, Map<String, Data>>> _read(DatabaseClient client) async {
    final result = <String, Map<String, Data>>{};
    for (final name in collections) {
      result[name] = {
        for (final r in await table(name).find(client))
          r.key: Map<String, Object?>.from(r.value),
      };
    }
    return result;
  }

  Future<void> initialize() async {
    await reload();
    for (final name in collections) {
      _subscriptions.add(
        table(name).query().onSnapshots(database).listen((_) {
          unawaited(reload().catchError((Object _) {}));
        }),
      );
    }
  }

  Future<void> reload() {
    _reloadQueue = _reloadQueue.catchError((Object _) {}).then((_) async {
      if (_closed) return;
      final next = await database.transaction((txn) => _read(txn));
      if (_closed) return;
      snapshot = WorkspaceSnapshot(next);
      notifyListeners();
    });
    return _reloadQueue;
  }

  Future<String> write(
    String actor,
    String operationId,
    String Function(MutableWorkspace state) mutate,
  ) async {
    final result = await database.transaction((txn) async {
      final operations = table('operations');
      final previous = operationId.isEmpty
          ? null
          : await operations.record(operationId).get(txn);
      if (previous != null) {
        if (previous['actor'] != actor) {
          throw const AppFailure('다른 계정의 작업을 재사용할 수 없어요.');
        }
        return textOf(previous, 'result');
      }
      final before = await _read(txn);
      final state = MutableWorkspace({
        for (final entry in before.entries)
          entry.key: {
            for (final r in entry.value.entries)
              r.key: Map<String, Object?>.from(r.value),
          },
      });
      final result = mutate(state);
      if (failNextWrite) {
        failNextWrite = false;
        throw const AppFailure('저장하지 못했어요. 입력을 유지했으니 다시 시도해 주세요.');
      }
      for (final name in collections) {
        for (final id in before[name]!.keys) {
          if (!state.tables[name]!.containsKey(id)) {
            await table(name).record(id).delete(txn);
          }
        }
        for (final entry in state.tables[name]!.entries) {
          if (jsonEncode(before[name]![entry.key]) != jsonEncode(entry.value)) {
            await table(name).record(entry.key).put(txn, entry.value);
          }
        }
      }
      if (operationId.isNotEmpty) {
        await operations.record(operationId).put(txn, {
          'actor': actor,
          'result': result,
        });
      }
      return result;
    });
    await reload();
    return result;
  }

  Future<void> close() async {
    _closed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _reloadQueue;
    await database.close();
    dispose();
  }
}
