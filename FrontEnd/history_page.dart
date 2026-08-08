import 'dart:io';

import 'package:flutter/material.dart';

import 'history_entry.dart';
import 'history_store.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.store});

  final HistoryStore store;

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => _isLoading = true);
    final entries = await widget.store.load();
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No images yet — generate one from the Generate tab\nand it will show up here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: _entries.length,
        itemBuilder: (context, i) => _HistoryTile(entry: _entries[i], store: widget.store),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.store});

  final HistoryEntry entry;
  final HistoryStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<File>(
                future: store.imageFile(entry),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(color: theme.colorScheme.surfaceContainerHigh);
                  }
                  return Image.file(snapshot.data!, fit: BoxFit.cover, width: double.infinity);
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.prompt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenView(entry: entry, store: store),
      ),
    );
  }
}

class _FullScreenView extends StatelessWidget {
  const _FullScreenView({required this.entry, required this.store});

  final HistoryEntry entry;
  final HistoryStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Seed · ${entry.createdAt.toLocal()}'.split('.').first)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<File>(
              future: store.imageFile(entry),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return InteractiveViewer(
                  child: Center(child: Image.file(snapshot.data!)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${entry.prompt}"', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 6),
                Text(
                  'Steps: ${entry.steps}   ·   Guidance: ${entry.guidanceScale.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}