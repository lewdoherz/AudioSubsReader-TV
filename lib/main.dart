import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appearance.dart';
import 'appearance_panel.dart';
import 'book.dart';
import 'library.dart';
import 'reader.dart';
import 'tv_import.dart';
import 'tv_storage.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final library = await BookLibrary.open();
    final appearance = await AppearanceController.load(
      File('${library.root.parent.path}/appearance.json'),
    );
    registerReaderFontLicenses();
    runApp(
      ReaderApp(
        library: library,
        appearance: appearance,
        initialPackage: arguments.isEmpty ? null : arguments.first,
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Cannot start AudioSubs Reader TV: $error')),
        ),
      ),
    );
  }
}

class ReaderApp extends StatelessWidget {
  final BookLibrary library;
  final AppearanceController appearance;
  final String? initialPackage;
  const ReaderApp({
    super.key,
    required this.library,
    required this.appearance,
    this.initialPackage,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appearance,
    builder: (context, _) => MaterialApp(
      title: 'AudioSubs Reader TV',
      debugShowCheckedModeBanner: false,
      theme: appearance.value.theme(Brightness.light),
      darkTheme: appearance.value.theme(Brightness.dark),
      themeMode: appearance.value.themeMode,
      builder: (context, child) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        child: child!,
      ),
      home: LibraryScreen(
        library: library,
        appearance: appearance,
        initialPackage: initialPackage,
      ),
    ),
  );
}

class LibraryScreen extends StatefulWidget {
  final BookLibrary library;
  final AppearanceController appearance;
  final String? initialPackage;
  const LibraryScreen({
    super.key,
    required this.library,
    required this.appearance,
    this.initialPackage,
  });
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<ReaderBook> _books = [];
  bool _busy = true;
  String? _error;
  final _openFocus = FocusNode(debugLabel: 'Open reading book');

  @override
  void dispose() {
    _openFocus.dispose();
    super.dispose();
  }

  void _focusOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_busy) _openFocus.requestFocus();
    });
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.initialPackage != null) {
      await _import(() => widget.library.importPackage(widget.initialPackage!));
    } else {
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final books = await widget.library.books();
      if (mounted) {
        setState(() {
          _books = books;
          _error = widget.library.warnings.isEmpty
              ? null
              : widget.library.warnings.join('\n');
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _focusOpen();
      }
    }
  }

  Future<void> _choosePackage() async {
    final route = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open reading book'),
        content: SizedBox(
          width: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose a prepared .abook. Use the direction buttons and OK. Back cancels.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context, 'document'),
                child: const Text('System document picker'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, 'download'),
                child: const Text('Browse Download folder'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Download browsing asks for storage access only when selected. If no system picker is installed, use Download.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || route == null) {
      _focusOpen();
      return;
    }
    try {
      if (route == 'document') {
        await _import(() async {
          final source = await widget.library.storage.pickDocument();
          return source == null ? null : widget.library.importSource(source);
        });
      } else {
        final allowed = await widget.library.storage
            .requestDownloadPermission();
        if (!mounted) return;
        if (!allowed) {
          setState(
            () => _error =
                'Download access was not granted. Try again to allow storage access, or use the system document picker.',
          );
          return;
        }
        final source = await Navigator.push<TvImportSource>(
          context,
          MaterialPageRoute(
            builder: (_) => DownloadBrowser(storage: widget.library.storage),
          ),
        );
        if (source != null && mounted) {
          await _import(() => widget.library.importSource(source));
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _focusOpen();
    }
  }

  Future<void> _import(Future<ReaderBook?> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    ReaderBook? imported;
    try {
      imported = await operation();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
    final error = _error;
    await _refresh();
    if (error != null && mounted) setState(() => _error = error);
    if (imported != null && mounted) await _read(imported);
  }

  Future<void> _read(ReaderBook book) async {
    try {
      final progress = await widget.library.progress(book);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(
            book: book,
            progress: progress,
            appearance: widget.appearance,
            onProgress: (value) => widget.library.saveProgress(book, value),
          ),
        ),
      );
      _focusOpen();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('AudioSubs Reader TV'),
      actions: [
        IconButton(
          tooltip: 'Appearance',
          onPressed: () => showAppearancePanel(context, widget.appearance),
          icon: const Icon(Icons.text_fields),
        ),
        IconButton(
          tooltip: 'Open-source licences',
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'AudioSubs Reader TV',
            applicationVersion: 'TV1.0.0+1',
          ),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Listen to the story.\nStay on the page.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Open a prepared .abook from Download or a system document provider. Audio, ebook formatting and timing travel together — no speech model is needed on this TV.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  focusNode: _openFocus,
                  autofocus: true,
                  onPressed: _busy ? null : _choosePackage,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Open reading book'),
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 32),
            Text(
              'Your books',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (!_busy && _books.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Your library is empty. Open a portable .abook file to start reading and listening.',
                  ),
                ),
              ),
            for (final book in _books)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                  ),
                  onPressed: _busy ? null : () => _read(book),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_stories_outlined, size: 36),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (book.author.isNotEmpty) book.author,
                                '${book.tracks.length} audio ${book.tracks.length == 1 ? 'file' : 'files'}',
                                '${book.alignment['matchedWords'] ?? book.cues.length} timed words',
                              ].join(' · '),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Reading position stays on this device. Importing a book again keeps its existing copy and progress. Original audio and ebooks are never modified.',
            ),
          ],
        ),
      ),
    ),
  );
}
