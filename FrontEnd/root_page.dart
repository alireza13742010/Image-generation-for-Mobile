import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:text_to_image/auth_service.dart';
import 'package:text_to_image/delete_account_dialog.dart';

import 'history_page.dart';
import 'history_store.dart';
import 'models.dart' show SeedMode;

// Matches server_debug.py: POST /generate blocks until the image is ready
// and returns {"status": "done"}. Then GET /image fetches the single
// output.jpg file directly. No job_id, no polling. Unchanged from
// simple_generate_page.dart.
const String kServerUrl = 'https://venue-lubricant-cruelly.ngrok-free.dev';

/// Hosts the bottom navigation between Generate and History, and owns the
/// single HistoryStore instance shared by both. This is the "main page" the
/// user lands on once they're signed in, paid, and have seen their license.
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  final HistoryStore _historyStore = HistoryStore();
  final GlobalKey<HistoryPageState> _historyKey = GlobalKey<HistoryPageState>();
  final AuthService _authService = AuthService();
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Image Generation' : 'History'),
        actions: [
          if (_tabIndex == 0)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Settings',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const _DemoSettingsDialog(),
              ),
            ),
          PopupMenuButton<_AccountAction>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (action) async {
              switch (action) {
                case _AccountAction.logOut:
                  // Just signs out — AuthGate notices and shows LoginPage.
                  await _authService.signOut();
                  break;
                case _AccountAction.deleteAccount:
                  await showDeleteAccountDialog(context);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AccountAction.logOut,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                ),
              ),
              PopupMenuItem(
                value: _AccountAction.deleteAccount,
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('Delete account', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _GenerateTab(
            historyStore: _historyStore,
            onSaved: () => _historyKey.currentState?.refresh(),
          ),
          HistoryPage(key: _historyKey, store: _historyStore),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() => _tabIndex = i);
          if (i == 1) _historyKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Generate'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'History'),
        ],
      ),
    );
  }
}

enum _AccountAction { logOut, deleteAccount }

/// The working generate flow — prompt in, POST /generate (blocks until
/// done), GET /image, display. This logic is exactly what
/// simple_generate_page.dart already had and is left untouched here; the
/// only thing added is saving each result to HistoryStore once it arrives,
/// so every image is still there after fully closing the app.
class _GenerateTab extends StatefulWidget {
  const _GenerateTab({required this.historyStore, required this.onSaved});

  final HistoryStore historyStore;
  final VoidCallback onSaved;

  @override
  State<_GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends State<_GenerateTab> {
  final _promptController = TextEditingController();
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;

  // Matches server_debug.py's hardcoded values — stored here only so
  // there's something to label each HistoryEntry with.
  static const int _steps = 50;
  static const double _guidanceScale = 7.0;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // This request stays open for the whole generation — that's expected
      // with server_debug.py, since /generate is synchronous there.
      final response = await http
          .post(
            Uri.parse('$kServerUrl/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(minutes: 5));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'done') {
        setState(() => _error = data['detail'] as String? ?? 'Unknown server error');
        return;
      }

      final imageResponse = await http.get(Uri.parse('$kServerUrl/image'));
      final bytes = imageResponse.bodyBytes;
      setState(() => _imageBytes = bytes);

      // Persist to disk so it survives closing the app, then refresh History.
      await widget.historyStore.add(
        prompt: prompt,
        steps: _steps,
        guidanceScale: _guidanceScale,
        imageBytes: bytes,
      );
      widget.onSaved();
    } catch (e) {
      setState(() => _error = 'Could not reach the server: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _promptController,
            decoration: const InputDecoration(
              hintText: 'Prompt',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _generate(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoading ? null : _generate,
            child: Text(_isLoading ? 'Generating…' : 'Generate'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: _imageBytes == null
                  ? const SizedBox.shrink()
                  : Image.memory(_imageBytes!, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pressing the tune icon in the AppBar opens this. It's a copy of the
/// "Settings" panel from the previous root page — display only. Its state
/// lives entirely inside this dialog and is thrown away when it closes; it
/// is never read by `_GenerateTab._generate()` or sent to the server.
class _DemoSettingsDialog extends StatefulWidget {
  const _DemoSettingsDialog();

  @override
  State<_DemoSettingsDialog> createState() => _DemoSettingsDialogState();
}

class _DemoSettingsDialogState extends State<_DemoSettingsDialog> {
  int _resolution = 1024;
  double _steps = 50;
  double _guidanceScale = 7.0;
  SeedMode _seedMode = SeedMode.random;
  int _fixedSeed = 42;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resolution', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 512, label: Text('512')),
                ButtonSegment(value: 768, label: Text('768')),
                ButtonSegment(value: 1024, label: Text('1024')),
              ],
              selected: {_resolution},
              onSelectionChanged: (s) => setState(() => _resolution = s.first),
            ),
            const SizedBox(height: 16),
            _SliderRow(
              label: 'Inference steps',
              value: _steps,
              min: 4,
              max: 80,
              divisions: 76,
              valueLabel: _steps.round().toString(),
              onChanged: (v) => setState(() => _steps = v),
            ),
            _SliderRow(
              label: 'Guidance scale',
              value: _guidanceScale,
              min: 1,
              max: 15,
              divisions: 28,
              valueLabel: _guidanceScale.toStringAsFixed(1),
              onChanged: (v) => setState(() => _guidanceScale = v),
            ),
            const SizedBox(height: 8),
            Text('Seed', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<SeedMode>(
              segments: const [
                ButtonSegment(value: SeedMode.random, label: Text('Random'), icon: Icon(Icons.shuffle)),
                ButtonSegment(value: SeedMode.fixed, label: Text('Fixed'), icon: Icon(Icons.tag)),
              ],
              selected: {_seedMode},
              onSelectionChanged: (s) => setState(() => _seedMode = s.first),
            ),
            if (_seedMode == SeedMode.fixed) ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _fixedSeed.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Seed value',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _fixedSeed = int.tryParse(v) ?? _fixedSeed),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ],
      ),
    );
  }
}