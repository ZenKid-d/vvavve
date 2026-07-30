import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/aggregator.dart';
import '../domain/models/track.dart';

/// Веб-заглушка оффлайн-загрузок.
///
/// Скачивать некуда: файловой системы у страницы нет, а держать десятки
/// мегабайт аудио в IndexedDB — не то же самое, что офлайн-режим приложения
/// (браузер вычистит хранилище по своему усмотрению). Поэтому на вебе загрузок
/// нет совсем, а UI, который их показывает, скрывается.
///
/// Класс намеренно повторяет публичный API io-версии целиком: так проводка в
/// `bootstrap` (`aggregator.localMatchResolver`, `handler.localFileResolver`) и
/// все экраны остаются платформенно-нейтральными.
class DownloadsController extends ChangeNotifier {
  /// Аргументы принимаются ради совпадения сигнатуры с io-версией и не
  /// используются.
  DownloadsController(SharedPreferences prefs, Dio dio, Aggregator aggregator);

  List<Track> get downloads => const [];
  List<Track> get inProgress => const [];
  bool isDownloaded(String uid) => false;
  bool isDownloading(String uid) => false;
  double progressFor(String uid) => 0;
  double get playlistProgress => 0;
  String? get playlistName => null;
  bool get playlistBusy => false;

  /// Локального файла в браузере не бывает — плеер всегда пойдёт в сеть.
  String? localPathFor(String uid) => null;

  /// Офлайн-дублей нет, значит и кросс-источниковому фолбэку опереться не на что.
  ({Track track, String path})? localMatchByNormKey(String artist, String title) =>
      null;

  /// Всегда false: вызывающий трактует это как «скачать не удалось».
  Future<bool> download(Track track, {bool notify = true}) async => false;

  Future<void> downloadPlaylist(String name, List<Track> tracks) async {}

  Future<int> downloadsBytes() async => 0;

  Future<void> removeAll() async {}

  Future<void> remove(String uid) async {}
}
