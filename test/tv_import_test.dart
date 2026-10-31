import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:audiosubs_reader/library.dart';
import 'package:audiosubs_reader/tv_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'book_package_test.dart' show manifest, package;
import 'tv_storage_fake.dart';

void main() {
  late Directory temporary;
  late Directory root;
  late TestTvStorage storage;
  late BookLibrary library;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('tv-import-test-');
    root = await Directory('${temporary.path}/books').create();
    storage = TestTvStorage();
    library = BookLibrary(root, storage: storage);
  });
  tearDown(() => temporary.delete(recursive: true));

  test(
    'expanded size plus reserve is checked before extracting any entry',
    () async {
      final source = await package(temporary, manifest());
      final original = await source.readAsBytes();
      storage.availableBytes = importReserveBytes;
      await expectLater(
        library.importPackage(source.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(storage.freeChecks, 1);
      expect(await root.list().toList(), isEmpty);
      expect(await source.readAsBytes(), original);
      storage.availableBytes = importReserveBytes + 1024 * 1024;
      expect((await library.importPackage(source.path)).id, 'test-book');
      expect(storage.freeChecks, 2);
    },
  );

  test(
    'a failed current-space query aborts and removes partial staging',
    () async {
      final source = await package(temporary, manifest());
      storage.freeError = const FileSystemException(
        'Storage volume disappeared',
      );
      await expectLater(
        library.importPackage(source.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(await root.list().toList(), isEmpty);
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'cached provider copies are removed after both success and failure',
    () async {
      var source = await package(temporary, manifest());
      await library.importSource(TvImportSource(source.path, cached: true));
      expect(await source.exists(), isFalse);
      source = await package(temporary, manifest(), withAudio: false);
      await expectLater(
        library.importSource(TvImportSource(source.path, cached: true)),
        throwsFormatException,
      );
      expect(await source.exists(), isFalse);
      expect(storage.released, hasLength(2));
      expect((await library.books()).single.id, 'test-book');
      expect(
        await root
            .list()
            .where((entry) => entry.path.contains('.import-'))
            .toList(),
        isEmpty,
      );
    },
  );

  test(
    'Download sources are never removed, including failed imports',
    () async {
      final source = await package(temporary, manifest(), withAudio: false);
      await expectLater(
        library.importSource(TvImportSource(source.path)),
        throwsFormatException,
      );
      expect(await source.exists(), isTrue);
      expect(await root.list().toList(), isEmpty);
    },
  );

  test('content URIs cannot be mistaken for filesystem source paths', () async {
    await expectLater(
      library.importPackage('content://provider/book.abook'),
      throwsFormatException,
    );
    expect(storage.freeChecks, 0);
    expect(await root.list().toList(), isEmpty);
  });

  test(
    'startup recovery removes only abandoned staging and retains warnings',
    () async {
      final source = await package(temporary, manifest());
      final book = await library.importPackage(source.path);
      await File(
        '${book.directory}/progress.json',
      ).writeAsString('{"track":0,"positionMs":44,"speed":1}');
      await Directory(
        '${root.path}/.import-abandoned/audio',
      ).create(recursive: true);
      await File(
        '${root.path}/.import-abandoned/audio/partial',
      ).writeAsString('partial');
      await Directory('${root.path}/broken-book').create();
      await library.recoverImports();
      expect(
        await Directory('${root.path}/.import-abandoned').exists(),
        isFalse,
      );
      expect(storage.recovered, isTrue);
      expect((await library.books()).single.id, 'test-book');
      expect((await library.progress(book)).positionMs, 44);
      expect(library.warnings.single, contains('broken-book'));
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'untrusted playback state is rejected before the free-space boundary',
    () async {
      final source = await package(
        temporary,
        manifest(),
        extraPath: 'progress.json',
      );
      await expectLater(
        library.importPackage(source.path),
        throwsFormatException,
      );
      expect(storage.freeChecks, 0);
      expect(await root.list().toList(), isEmpty);
    },
  );

  test('case-folding collisions and links cannot extract files', () async {
    final source = await package(
      temporary,
      manifest(),
      extraPath: 'AUDIO/000.wav',
    );
    await expectLater(
      library.importPackage(source.path),
      throwsFormatException,
    );
    expect(storage.freeChecks, 0);
    final archive = Archive()
      ..add(ArchiveFile.string('book.json', '{}'))
      ..add(
        ArchiveFile.string('audio/link', '')..symbolicLink = '../../outside',
      );
    await source.writeAsBytes(ZipEncoder().encode(archive));
    await expectLater(
      library.importPackage(source.path),
      throwsFormatException,
    );
    expect(await root.list().toList(), isEmpty);
  });
}
