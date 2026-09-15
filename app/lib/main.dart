import 'package:flutter/material.dart';

import 'core/game/game_controller.dart';
import 'core/models/character.dart';
import 'core/network/api_client.dart';
import 'features/shell/game_shell.dart';

/// Endereço padrão do backend para desenvolvimento local. RF-46 (configurar
/// host/porta pela UI) ainda não está implementado.
const _defaultBackendBaseUrl = 'http://localhost:8080';

void main() {
  runApp(const LabirintoDungeonicoApp());
}

class LabirintoDungeonicoApp extends StatelessWidget {
  const LabirintoDungeonicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Labirinto Dungeonico',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.controller});

  /// Permite injetar um controller (com um `ApiClient` falso) em testes.
  final GameController? controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final GameController _controller =
      widget.controller ?? GameController(ApiClient(baseUrl: _defaultBackendBaseUrl));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openShell(int tabIndex) async {
    if (_controller.session == null || _controller.isHardcoreDeath) {
      final ready = await _showCreateSessionDialog();
      if (!ready || !mounted) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameShell(controller: _controller, initialIndex: tabIndex)),
    );
  }

  Future<bool> _showCreateSessionDialog() async {
    final nameController = TextEditingController();
    final seedController = TextEditingController();
    var mode = GameMode.normal;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nova run'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SegmentedButton<GameMode>(
                segments: const [
                  ButtonSegment(value: GameMode.normal, label: Text('Normal')),
                  ButtonSegment(value: GameMode.hardcore, label: Text('Hardcore')),
                ],
                selected: {mode},
                onSelectionChanged: (selection) => setDialogState(() => mode = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seed (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                final seedText = seedController.text.trim();
                final success = await _controller.createSession(
                  name: name,
                  mode: mode,
                  seed: seedText.isEmpty ? null : int.tryParse(seedText),
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(success);
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      return true;
    }
    if (_controller.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.errorMessage!)),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final session = _controller.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Labirinto Dungeonico')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (session != null) ...[
              Text(
                '${session.character.name}'
                ' (${session.character.mode == GameMode.hardcore ? 'Hardcore' : 'Normal'})',
              ),
              Text(
                'Profundidade ${session.depth}'
                ' · Vida ${session.character.currentHealth}/${session.character.maxHealth}',
              ),
              if (_controller.isHardcoreDeath)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Run encerrada (morte em Hardcore).', style: TextStyle(color: Colors.red)),
                ),
              TextButton(onPressed: _controller.reset, child: const Text('Nova run')),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: () => _openShell(0),
              child: const Text('Mapa'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _openShell(1),
              child: const Text('Combate'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _openShell(2),
              child: const Text('Inventário'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _openShell(3),
              child: const Text('Personagem'),
            ),
          ],
        ),
      ),
    );
  }
}
