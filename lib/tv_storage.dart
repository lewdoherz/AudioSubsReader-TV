import 'package:flutter/services.dart';

/// A source is either the untouched Download file or an app-owned provider copy.
class TvImportSource {
  final String path;
  final bool cached;
  const TvImportSource(this.path, {this.cached = false});
}

class DownloadEntry {
  final String name;
  final String relativePath;
  final bool directory;
  const DownloadEntry(this.name, this.relativePath, {required this.directory});
}

abstract interface class TvStorage {
  Future<TvImportSource?> pickDocument();
  Future<bool> requestDownloadPermission();
  Future<List<DownloadEntry>> listDownloads(String relativePath);
  Future<TvImportSource> downloadSource(String relativePath);
  Future<int> freeBytes(String path);
  Future<void> releaseSource(TvImportSource source);
  Future<void> recoverCache();
}

class NativeTvStorage implements TvStorage {
  static const channel = MethodChannel(
    'com.audiosubs.audiosubs_reader.tv/storage',
  );
  const NativeTvStorage();

  @override
  Future<TvImportSource?> pickDocument() async {
    final path = await channel.invokeMethod<String>('pickDocument');
    return path == null ? null : TvImportSource(path, cached: true);
  }

  @override
  Future<bool> requestDownloadPermission() async =>
      await channel.invokeMethod<bool>('requestDownloadPermission') ?? false;

  @override
  Future<List<DownloadEntry>> listDownloads(String relativePath) async {
    final entries = await channel.invokeListMethod<dynamic>('listDownloads', {
      'relativePath': relativePath,
    });
    return (entries ?? []).map((entry) {
      final value = Map<String, dynamic>.from(entry as Map);
      return DownloadEntry(
        value['name'] as String,
        value['relativePath'] as String,
        directory: value['directory'] as bool,
      );
    }).toList();
  }

  @override
  Future<TvImportSource> downloadSource(String relativePath) async =>
      TvImportSource(
        (await channel.invokeMethod<String>('downloadSource', {
          'relativePath': relativePath,
        }))!,
      );

  @override
  Future<int> freeBytes(String path) async =>
      (await channel.invokeMethod<int>('freeBytes', {'path': path}))!;

  @override
  Future<void> releaseSource(TvImportSource source) async {
    if (source.cached) {
      await channel.invokeMethod<void>('releaseSource', {'path': source.path});
    }
  }

  @override
  Future<void> recoverCache() => channel.invokeMethod<void>('recoverCache');
}
