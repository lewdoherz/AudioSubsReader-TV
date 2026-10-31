import 'dart:io';

import 'package:audiosubs_reader/tv_storage.dart';

class TestTvStorage implements TvStorage {
  int availableBytes;
  int freeChecks = 0;
  bool allowed = true;
  bool recovered = false;
  Object? freeError;
  Object? pickerError;
  TvImportSource? picked;
  final released = <TvImportSource>[];
  final listed = <String>[];
  final folders = <String, List<DownloadEntry>>{};
  final sources = <String, TvImportSource>{};
  TestTvStorage({this.availableBytes = 128 * 1024 * 1024 * 1024});

  @override
  Future<int> freeBytes(String path) async {
    freeChecks++;
    if (freeError != null) throw freeError!;
    return availableBytes;
  }

  @override
  Future<TvImportSource?> pickDocument() async {
    if (pickerError != null) throw pickerError!;
    return picked;
  }

  @override
  Future<bool> requestDownloadPermission() async => allowed;

  @override
  Future<List<DownloadEntry>> listDownloads(String relativePath) async {
    listed.add(relativePath);
    return folders[relativePath] ?? [];
  }

  @override
  Future<TvImportSource> downloadSource(String relativePath) async =>
      sources[relativePath]!;

  @override
  Future<void> releaseSource(TvImportSource source) async {
    released.add(source);
    if (source.cached) await File(source.path).delete();
  }

  @override
  Future<void> recoverCache() async {
    recovered = true;
  }
}
