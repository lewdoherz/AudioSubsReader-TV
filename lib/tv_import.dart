import 'package:flutter/material.dart';

import 'tv_storage.dart';

/// Only the selected folder is enumerated. Back ascends before closing the route.
class DownloadBrowser extends StatefulWidget {
  final TvStorage storage;
  const DownloadBrowser({super.key, required this.storage});

  @override
  State<DownloadBrowser> createState() => _DownloadBrowserState();
}

class _DownloadBrowserState extends State<DownloadBrowser> {
  final _first = FocusNode(debugLabel: 'Download first entry');
  final _cancel = FocusNode(debugLabel: 'Download cancel');
  String _relative = '';
  List<DownloadEntry> _entries = [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _first.dispose();
    _cancel.dispose();
    super.dispose();
  }

  Future<void> _load(String relative) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = await widget.storage.listDownloads(relative);
      if (!mounted) return;
      setState(() {
        _relative = relative;
        _entries = entries;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            (_error == null && _entries.isNotEmpty ? _first : _cancel)
                .requestFocus();
          }
        });
      }
    }
  }

  void _up() {
    final slash = _relative.lastIndexOf('/');
    _load(slash < 0 ? '' : _relative.substring(0, slash));
  }

  Future<void> _choose(DownloadEntry entry) async {
    if (entry.directory) {
      await _load(entry.relativePath);
      return;
    }
    setState(() => _busy = true);
    try {
      final source = await widget.storage.downloadSource(entry.relativePath);
      if (mounted) Navigator.pop(context, source);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _cancel.requestFocus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<TvImportSource>(
    canPop: _relative.isEmpty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy) _up();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(_relative.isEmpty ? 'Download' : 'Download / $_relative'),
        leading: BackButton(
          onPressed: _busy
              ? null
              : () {
                  if (_relative.isNotEmpty) {
                    _up();
                  } else {
                    Navigator.pop(context);
                  }
                },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose a folder or .abook with the direction buttons and OK. Back returns to the parent folder.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_relative.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _up,
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Parent folder'),
                  ),
                  const SizedBox(width: 12),
                ],
                OutlinedButton(
                  onPressed: _busy ? null : () => _load(_relative),
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  focusNode: _cancel,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (!_busy && _entries.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No .abook files or folders here. Copy a prepared book to Download, then select Refresh.',
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      focusNode: index == 0 ? _first : null,
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(20),
                      ),
                      onPressed: _busy ? null : () => _choose(entry),
                      icon: Icon(
                        entry.directory
                            ? Icons.folder_outlined
                            : Icons.menu_book,
                      ),
                      label: Text(entry.name),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
