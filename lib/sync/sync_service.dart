import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/diagnostics.dart';
import '../core/library_controller.dart';
import 'sync_transport.dart';

enum SyncState { off, syncing, idle, error }

/// Обмен библиотекой между устройствами.
///
/// Работает по одной схеме для всех наборов: тянет чужие изменения по курсору
/// серверного времени, сливает их локально, затем отправляет свои — те, что
/// новее водяного знака. Оба указателя лежат в prefs отдельно для каждого
/// аккаунта, поэтому смена аккаунта не путает состояния.
///
/// Приложение обязано работать и без входа: пока пользователя нет, служба
/// полностью бездействует и ничего не сообщает об ошибках.
class SyncService extends ChangeNotifier {
  SyncService({
    required SharedPreferences prefs,
    required LibraryController library,
    required SyncTransport Function(String uid) transportFactory,
    Duration pushDelay = const Duration(seconds: 2),
  })  : _prefs = prefs,
        _library = library,
        _transportFactory = transportFactory,
        _pushDelay = pushDelay;

  final SharedPreferences _prefs;
  final LibraryController _library;
  final SyncTransport Function(String uid) _transportFactory;

  SyncTransport? _transport;
  String? _uid;
  final _subs = <StreamSubscription<List<RemoteDoc>>>[];
  Timer? _pushDebounce;
  bool _pushing = false;

  SyncState _state = SyncState.off;
  SyncState get state => _state;

  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;

  String? _error;
  String? get error => _error;

  /// Отправку копим: за один лайк прилетает несколько уведомлений, а платить
  /// за каждое отдельной записью в облако незачем.
  final Duration _pushDelay;

  bool get _signedIn => _uid != null;

  /// Подключает аккаунт. Повторный вызов с тем же uid ничего не делает.
  Future<void> start(String uid) async {
    if (_uid == uid) return;
    await stop();
    _uid = uid;
    _transport = _transportFactory(uid);
    _setState(SyncState.syncing);

    final firstTime = _prefs.getString('sync_last_uid') == null;
    final switchedAccount =
        !firstTime && _prefs.getString('sync_last_uid') != uid;
    if (switchedAccount) {
      // На устройстве уже синхронизировался другой аккаунт. Забирать чужую
      // библиотеку в новый аккаунт нельзя — это утечка чужих данных, поэтому
      // отдаём только приём, а отправку глушим водяным знаком «сейчас».
      Diagnostics.instance.warn('sync',
          'Вход в другой аккаунт: локальные данные останутся на устройстве и '
          'в облако не поедут');
      for (final name in _library.syncBuckets.keys) {
        await _prefs.setInt(
            _pushedKey(name), DateTime.now().millisecondsSinceEpoch);
      }
    }
    await _prefs.setString('sync_last_uid', uid);

    _library.addListener(_schedulePush);
    _listen();
    _schedulePush();
  }

  Future<void> stop() async {
    _pushDebounce?.cancel();
    _library.removeListener(_schedulePush);
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _transport?.dispose();
    _transport = null;
    _uid = null;
    _setState(SyncState.off);
  }

  String _cursorKey(String c) => 'sync_cursor_${_uid}_$c';
  String _pushedKey(String c) => 'sync_pushed_${_uid}_$c';

  void _listen() {
    final transport = _transport;
    if (transport == null) return;
    for (final name in _library.syncBuckets.keys) {
      final since = _prefs.getInt(_cursorKey(name)) ?? 0;
      _subs.add(transport.watch(name, since: since).listen(
            (docs) => _applyRemote(name, docs),
            onError: _onError,
          ));
    }
  }

  Future<void> _applyRemote(String collection, List<RemoteDoc> docs) async {
    if (docs.isEmpty) return;
    final bucket = _library.syncBuckets[collection];
    if (bucket == null) return;

    var changed = false;
    var cursor = _prefs.getInt(_cursorKey(collection)) ?? 0;
    for (final doc in docs) {
      if (bucket.mergeRaw(doc.record)) changed = true;
      if (doc.serverAt > cursor) cursor = doc.serverAt;
    }
    await _prefs.setInt(_cursorKey(collection), cursor);
    if (changed) await _library.persistBucket(collection);

    // Свои же записи, вернувшиеся из облака, отправлять обратно не нужно:
    // сдвигаем водяной знак до того, что уже точно там есть.
    final applied = docs.map((d) => d.record.updatedAt).reduce((a, b) => a > b ? a : b);
    final pushed = _prefs.getInt(_pushedKey(collection)) ?? 0;
    if (applied > pushed && !changed) {
      await _prefs.setInt(_pushedKey(collection), applied);
    }

    _lastSyncAt = DateTime.now();
    _setState(SyncState.idle);
  }

  void _schedulePush() {
    if (!_signedIn) return;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(_pushDelay, () => unawaited(_push()));
  }

  Future<void> _push() async {
    final transport = _transport;
    if (transport == null || _pushing) return;
    _pushing = true;
    try {
      for (final entry in _library.syncBuckets.entries) {
        final watermark = _prefs.getInt(_pushedKey(entry.key)) ?? 0;
        final dirty = entry.value.dirtyRaw(watermark);
        if (dirty.isEmpty) continue;
        await transport.push(entry.key, dirty);
        final maxAt = dirty.map((r) => r.updatedAt).reduce((a, b) => a > b ? a : b);
        await _prefs.setInt(_pushedKey(entry.key), maxAt);
      }
      _lastSyncAt = DateTime.now();
      _error = null;
      _setState(SyncState.idle);
    } catch (e) {
      _onError(e);
    } finally {
      _pushing = false;
    }
  }

  void _onError(Object e) {
    // Недоступное облако — не повод мешать пользователю: приложение целиком
    // работает локально, поэтому ошибку показываем только в статусе.
    _error = e.toString();
    Diagnostics.instance.warn('sync', 'Обмен не удался: $e');
    _setState(SyncState.error);
  }

  void _setState(SyncState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _pushDebounce?.cancel();
    _library.removeListener(_schedulePush);
    unawaited(_transport?.dispose() ?? Future.value());
    super.dispose();
  }
}
