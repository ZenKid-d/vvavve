import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/diagnostics.dart';
import 'sync_transport.dart';
import 'synced_record.dart';

/// Транспорт поверх Firestore. Всё лежит под `users/{uid}` — данные строго
/// персональные, и правила это подтверждают.
class FirestoreTransport implements SyncTransport {
  FirestoreTransport(this.uid, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;
  final _subs = <StreamSubscription<dynamic>>[];

  /// Больше этого размера документ Firestore не принимает (1 МиБ). Держим
  /// запас на служебные поля и накладные расходы кодирования.
  static const _maxDocBytes = 900 * 1024;

  CollectionReference<Map<String, dynamic>> _col(String collection) =>
      _db.collection('users').doc(uid).collection(collection);

  @override
  Stream<List<RemoteDoc>> watch(String collection, {required int since}) {
    final query = _col(collection)
        .where('serverAt',
            isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(since))
        .orderBy('serverAt');

    return query.snapshots().map((snap) {
      final out = <RemoteDoc>[];
      for (final doc in snap.docs) {
        try {
          out.add(_toRemote(doc));
        } catch (e) {
          // Одна битая запись не должна ронять весь поток изменений.
          Diagnostics.instance
              .warn('sync', '$collection/${doc.id}: запись пропущена: $e');
        }
      }
      return out;
    });
  }

  RemoteDoc _toRemote(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final raw = data['p'];
    return RemoteDoc(
      record: SyncedRecord<Map<String, dynamic>>(
        key: doc.id,
        updatedAt: (data['updatedAt'] as num).toInt(),
        deleted: data['deleted'] == true,
        origin: data['origin'] as String?,
        // Полезная нагрузка едет строкой: вложенные массивы объектов Firestore
        // индексирует поэлементно, и большой плейлист упёрся бы в предел
        // индексных записей на документ задолго до предела по размеру.
        value: raw is String
            ? (jsonDecode(raw) as Map).cast<String, dynamic>()
            : null,
      ),
      serverAt: (data['serverAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
    );
  }

  @override
  Future<void> push(
      String collection, List<SyncedRecord<Map<String, dynamic>>> records) async {
    if (records.isEmpty) return;
    final col = _col(collection);

    // В одну пачку Firestore принимает 500 операций.
    for (var i = 0; i < records.length; i += 400) {
      final batch = _db.batch();
      var written = 0;
      for (final r in records.skip(i).take(400)) {
        final payload = r.value == null ? null : jsonEncode(r.value);
        if (payload != null && payload.length > _maxDocBytes) {
          // Молча пропустить нельзя: пользователь должен понимать, почему
          // конкретный плейлист не появился на втором устройстве.
          Diagnostics.instance.warn('sync',
              '$collection/${r.key}: не отправлено — ${payload.length ~/ 1024} КБ '
              'больше предела документа');
          continue;
        }
        batch.set(col.doc(r.key), {
          'updatedAt': r.updatedAt,
          'deleted': r.deleted,
          if (r.origin != null) 'origin': r.origin,
          if (payload != null) 'p': payload,
          'serverAt': FieldValue.serverTimestamp(),
        });
        written++;
      }
      if (written > 0) await batch.commit();
    }
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}
