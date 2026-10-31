import 'dart:io';

import 'package:audiosubs_reader/appearance.dart';
import 'package:audiosubs_reader/book.dart';
import 'package:audiosubs_reader/library.dart';
import 'package:audiosubs_reader/main.dart';
import 'package:audiosubs_reader/tv_import.dart';
import 'package:audiosubs_reader/tv_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tv_storage_fake.dart';

class EmptyLibrary extends BookLibrary {
  EmptyLibrary(super.root, {required super.storage});
  @override
  Future<List<ReaderBook>> books() async => [];
}

Future<void> pumpLibrary(WidgetTester tester, TestTvStorage storage) async {
  final directory = await tester.runAsync(
    () => Directory.systemTemp.createTemp('tv-library-widget-'),
  );
  final appearance = await tester.runAsync(
    () => AppearanceController.load(File('${directory!.path}/appearance.json')),
  );
  addTearDown(() async {
    appearance!.dispose();
    await directory!.delete(recursive: true);
  });
  await tester.pumpWidget(
    ReaderApp(
      library: EmptyLibrary(directory!, storage: storage),
      appearance: appearance!,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'initial OK opens import chooser and Back restores the Open control',
    (tester) async {
      await pumpLibrary(tester, TestTvStorage());
      expect(find.text('Prepare on this PC'), findsNothing);
      expect(find.text('AudioSubs Reader TV'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Open reading book',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('System document picker'), findsOneWidget);
      expect(find.text('Browse Download folder'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('System document picker'), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Open reading book',
      );
    },
  );

  testWidgets(
    'absent system document provider reports the Download alternative',
    (tester) async {
      final storage = TestTvStorage()
        ..pickerError = PlatformException(
          code: 'no_document_provider',
          message:
              'No system document picker is installed. Use Browse Download folder instead.',
        );
      await pumpLibrary(tester, storage);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Use Browse Download folder instead'),
        findsOneWidget,
      );
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Open reading book',
      );
      expect(storage.listed, isEmpty);
    },
  );

  testWidgets('Download permission denial does not enumerate storage', (
    tester,
  ) async {
    final storage = TestTvStorage()..allowed = false;
    await pumpLibrary(tester, storage);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Download access was not granted'),
      findsOneWidget,
    );
    expect(storage.listed, isEmpty);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Open reading book');
  });

  testWidgets(
    'Download browsing is on demand and remote Back ascends one folder',
    (tester) async {
      final storage = TestTvStorage()
        ..folders[''] = [const DownloadEntry('Books', 'Books', directory: true)]
        ..folders['Books'] = [
          const DownloadEntry(
            'Example.abook',
            'Books/Example.abook',
            directory: false,
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          },
          home: DownloadBrowser(storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      expect(storage.listed, ['']);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(storage.listed, ['', 'Books']);
      expect(find.text('Example.abook'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(storage.listed, ['', 'Books', '']);
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Example.abook'), findsNothing);
    },
  );
}
