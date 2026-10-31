import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'book.dart';
import 'tv_storage.dart';

const importReserveBytes = 64 * 1024 * 1024;

class BookLibrary {
  final Directory root;
  final List<String> warnings = [];
  Future<void> _saving = Future.value();
  final TvStorage storage;
  Future<void> _importing = Future.value();
  BookLibrary(this.root, {this.storage = const NativeTvStorage()});

  static Future<BookLibrary> open() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'books'));
    await root.create(recursive: true);
    final library = BookLibrary(root);
    await library.recoverImports();
    return library;
  }

  Future<List<ReaderBook>> books() async {
    final result = <ReaderBook>[];
    warnings.clear();
    await for (final entry in root.list()) {
      if (entry is! Directory || p.basename(entry.path).startsWith('.')) {
        continue;
      }
      try {
        result.add(await Isolate.run(() => ReaderBook.load(entry.path)));
      } catch (error) {
        warnings.add('${p.basename(entry.path)}: $error');
      }
    }
    result.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return result;
  }

  /// Only called at startup, before allowing any new import.
  Future<void> recoverImports() async {
    final rootPath = root.path;
    await Isolate.run(() async {
      await for (final entry in Directory(rootPath).list(followLinks: false)) {
        if (entry is Directory &&
            p.basename(entry.path).startsWith('.import-')) {
          await entry.delete(recursive: true);
        }
      }
    });
    await storage.recoverCache();
  }

  Future<ReaderBook> importPackage(String path) {
    final operation = _importing.then((_) => _importWithSpaceCheck(path));
    _importing = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<ReaderBook> _importWithSpaceCheck(String path) async {
    if (Uri.tryParse(path)?.scheme == 'content') {
      throw const FormatException(
        'Choose this document through the system picker.',
      );
    }
    final requests = ReceivePort();
    final rootPath = root.path;
    final send = requests.sendPort;
    // The worker waits at the storage boundary: validate ZIP metadata first,
    // query current free space natively, then extract on the same isolate.
    final worker = Isolate.run(_PackageImportJob(path, rootPath, send).run);
    final checking = () async {
      await for (final message in requests) {
        final values = message as List;
        final response = values[1] as SendPort;
        try {
          final available = await storage.freeBytes(rootPath);
          response.send(
            available >= (values[0] as int) + importReserveBytes
                ? null
                : 'Not enough storage to extract this book. Free space for the expanded book plus 64 MiB is required.',
          );
        } catch (error) {
          response.send('Cannot check available storage: $error');
        }
      }
    }();
    try {
      return await worker;
    } finally {
      requests.close();
      await checking;
    }
  }

  Future<ReaderBook> importSource(TvImportSource source) async {
    try {
      return await importPackage(source.path);
    } finally {
      await storage.releaseSource(source);
    }
  }

  Future<ReadingProgress> progress(ReaderBook book) async {
    final file = File(p.join(book.directory, 'progress.json'));
    if (!await file.exists()) return const ReadingProgress();
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final value = ReadingProgress.fromJson(json);
    if (value.track >= book.tracks.length) {
      throw const FormatException('Saved audio track is missing.');
    }
    return value;
  }

  Future<void> saveProgress(ReaderBook book, ReadingProgress progress) {
    final operation = _saving.then((_) async {
      final file = File(p.join(book.directory, 'progress.json'));
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(progress.toJson()), flush: true);
      await temporary.rename(file.path);
    });
    _saving = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

// A method tear-off keeps the ReceivePort and native storage bridge out of the
// worker's captured state. Only these three transferable values cross isolates.
class _PackageImportJob {
  final String source;
  final String root;
  final SendPort requests;
  const _PackageImportJob(this.source, this.root, this.requests);
  Future<ReaderBook> run() => _importPackage(source, root, requests);
}

Future<ReaderBook> _importPackage(
  String source,
  String root,
  SendPort requests,
) async {
  final staging = await Directory(root).createTemp('.import-');
  InputFileStream? input;
  try {
    input = InputFileStream(source);
    final decoder = ZipDecoder();
    final archive = decoder.decodeStream(input);
    if (archive.length != decoder.directory.fileHeaders.length) {
      throw const FormatException('Package contains duplicate paths.');
    }
    if (archive.length > 100000) {
      throw const FormatException('Too many package entries.');
    }
    final names = <String>{};
    var total = 0;
    for (final entry in archive) {
      final name = entry.isDirectory && entry.name.endsWith('/')
          ? entry.name.substring(0, entry.name.length - 1)
          : entry.name;
      safeBookPath(name);
      if (entry.isSymbolicLink || !names.add(name.toLowerCase())) {
        throw const FormatException(
          'Package contains links or duplicate paths.',
        );
      }
      total += entry.size;
      if (entry.size < 0 || total > 64 * 1024 * 1024 * 1024) {
        throw const FormatException('Expanded package exceeds 64 GiB.');
      }
      if (entry.name == 'book.json' && entry.size > 64 * 1024 * 1024) {
        throw const FormatException('Book manifest exceeds 64 MiB.');
      }
      // Never accept a package's playback state: it belongs to this device.
      if (name.toLowerCase() == 'progress.json' ||
          name.toLowerCase() == 'progress.json.tmp') {
        throw const FormatException(
          'Package must not contain device playback state.',
        );
      }
    }
    final response = ReceivePort();
    try {
      requests.send([total, response.sendPort]);
      final error = await response.first;
      if (error != null) throw FileSystemException(error as String);
    } finally {
      response.close();
    }
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final target = File(p.joinAll([staging.path, ...entry.name.split('/')]));
      await target.parent.create(recursive: true);
      final output = OutputFileStream(target.path);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
      if (await target.length() != entry.size) {
        throw const FormatException('Truncated package entry.');
      }
    }
    final book = await ReaderBook.load(staging.path);
    for (final relative in [
      ...book.tracks.map((track) => track.path),
      ...book.blocks
          .where((block) => block.image != null)
          .map((block) => block.image!),
    ]) {
      if (!await File(book.resolve(relative)).exists()) {
        throw FormatException('Package is missing $relative.');
      }
    }
    final destination = Directory(p.join(root, book.id));
    if (await destination.exists()) {
      return await ReaderBook.load(destination.path);
    }
    await staging.rename(destination.path);
    return await ReaderBook.load(destination.path);
  } finally {
    input?.closeSync();
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}
