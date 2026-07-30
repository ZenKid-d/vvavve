import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/diagnostics.dart';
import '../core/library_controller.dart';
import 'dislike_store.dart';
import 'session_host.dart';
import 'session_snapshot.dart';
import 'sync_clock.dart';
import 'sync_transport.dart';
import 'synced_record.dart';

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
    SessionHost? session,
    String deviceId = '',
    String? deviceLabel,
    Duration sessionThrottle = const Duration(seconds: 30),
    DislikeStore? dislikes,
  })  : _dislikes = dislikes,
        _prefs = prefs,
        _library = library,
        _transportFactory = transportFactory,
        _pushDelay = pushDelay,
        _session = session,
        _deviceId = deviceId,
        _deviceLabel = deviceLabel,
        _sessionThrottle = sessionThrottle;

  final SharedPreferences _prefs;
  final LibraryController _library;
  final SyncTransport Function(String uid) _transportFactory;
  final SessionHost? _session;
  final String _deviceId;
  final String? _deviceLabel;

  /// Дизлайки живут не в prefs, а в SQLite рекомендаций — отдельным набором.
  final DislikeStore? _dislikes;

  /// Имя коллекции дизлайков. Ключ записи — нормализованное «артист|название»,
  /// а не uid: один и тот же трек из разных источников дизлайкается целиком.
  static const _dislikesCollection = 'trackDislikes';

  /// Как часто отправлять позицию во время игры. Смена трека и пауза уезжают
  /// сразу — их пользователь и ждёт на другом устройстве.
  final Duration _sessionThrottle;

  /// Коллекция и документ сессии: она одна на аккаунт.
  static const _sessionCollection = 'session';
  static const _sessionDoc = 'current';

  DateTime? _lastSessionPush;
  Timer? _sessionTimer;

  SessionSnapshot? _pendingSession;

  /// Сессия с другого устройства, которую можно продолжить. Показывается как
  /// предложение: молча подменять очередь, собранную здесь, нельзя.
  SessionSnapshot? get pendingSession => _pendingSession;

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
    _session?.onChanged = _onSessionChanged;
    _listen();
    _listenSession();
    _schedulePush();
  }

  Future<void> stop() async {
    _pushDebounce?.cancel();
    _sessionTimer?.cancel();
    _session?.onChanged = null;
    _pendingSession = null;
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
    if (_dislikes != null) {
      final since = _prefs.getInt(_cursorKey(_dislikesCollection)) ?? 0;
      _subs.add(transport.watch(_dislikesCollection, since: since).listen(
            _applyRemoteDislikes,
            onError: _onError,
          ));
    }
  }

  Future<void> _applyRemoteDislikes(List<RemoteDoc> docs) async {
    final store = _dislikes;
    if (store == null || docs.isEmpty) return;
    var cursor = _prefs.getInt(_cursorKey(_dislikesCollection)) ?? 0;
    for (final doc in docs) {
      // Своё же не применяем повторно — база и так в нужном состоянии.
      if (doc.record.origin != _deviceId) {
        await store.mergeRemoteDislike(doc.record);
      }
      if (doc.serverAt > cursor) cursor = doc.serverAt;
    }
    await _prefs.setInt(_cursorKey(_dislikesCollection), cursor);
    _lastSyncAt = DateTime.now();
    _setState(SyncState.idle);
  }

  Future<void> _pushDislikes(SyncTransport transport) async {
    final store = _dislikes;
    if (store == null) return;
    final watermark = _prefs.getInt(_pushedKey(_dislikesCollection)) ?? 0;
    final dirty = await store.dirtyDislikes(watermark);
    if (dirty.isEmpty) return;
    await transport.push(_dislikesCollection, [
      for (final r in dirty)
        SyncedRecord<Map<String, dynamic>>(
          key: r.key,
          updatedAt: r.updatedAt,
          deleted: r.deleted,
          origin: _deviceId,
          value: r.value,
        ),
    ]);
    final maxAt = dirty.map((r) => r.updatedAt).reduce((a, b) => a > b ? a : b);
    await _prefs.setInt(_pushedKey(_dislikesCollection), maxAt);
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

  // --- Сессия: очередь и позиция ---

  void _listenSession() {
    final transport = _transport;
    if (transport == null || _session == null) return;
    // Курсор здесь не нужен: документ один, и интересует всегда последний.
    _subs.add(transport.watch(_sessionCollection, since: 0).listen(
          _onRemoteSession,
          onError: _onError,
        ));
  }

  void _onRemoteSession(List<RemoteDoc> docs) {
    if (docs.isEmpty) return;
    final doc = docs.last;
    if (doc.record.deleted || doc.record.value == null) return;
    // Своя же сессия, вернувшаяся из облака: предлагать «продолжить здесь» то,
    // что здесь и играет, — бессмысленно.
    if (doc.record.origin == _deviceId) return;

    final snapshot = SessionSnapshot.fromJson(
      doc.record.value!,
      updatedAt: doc.record.updatedAt,
    );
    if (snapshot.current == null) return;
    _pendingSession = snapshot;
    notifyListeners();
  }

  /// Переносит сессию. Вызывается только по явному согласию пользователя.
  ///
  /// Снимок передаётся аргументом, а не берётся из поля: предложение может быть
  /// снято ещё до того, как пользователь нажмёт «продолжить».
  Future<void> adoptSession(SessionSnapshot snapshot) async {
    final host = _session;
    if (host == null) return;
    await host.adopt(snapshot);
  }

  Future<void> adoptPendingSession() async {
    final snapshot = _pendingSession;
    if (snapshot == null) return;
    _pendingSession = null;
    notifyListeners();
    await adoptSession(snapshot);
  }

  void dismissPendingSession() {
    if (_pendingSession == null) return;
    _pendingSession = null;
    notifyListeners();
  }

  void _onSessionChanged({required bool important}) {
    if (!_signedIn || _session == null) return;
    if (important) {
      _sessionTimer?.cancel();
      unawaited(_pushSession());
      return;
    }
    // Тик позиции: отправляем не чаще, чем раз в _sessionThrottle.
    final last = _lastSessionPush;
    if (last != null && DateTime.now().difference(last) < _sessionThrottle) {
      return;
    }
    unawaited(_pushSession());
  }

  Future<void> _pushSession() async {
    final transport = _transport;
    final state = _session?.state;
    if (transport == null || state == null) return;
    _lastSessionPush = DateTime.now();
    try {
      final snapshot = SessionSnapshot(
        queue: state.queue,
        index: state.index,
        positionMs: state.positionMs,
        deviceId: _deviceId,
        deviceLabel: _deviceLabel,
      ).windowed();
      await transport.push(_sessionCollection, [
        SyncedRecord<Map<String, dynamic>>(
          key: _sessionDoc,
          updatedAt: SyncClock.now(),
          origin: _deviceId,
          value: snapshot.toJson(),
        ),
      ]);
    } catch (e) {
      _onError(e);
    }
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
      await _pushDislikes(transport);
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
