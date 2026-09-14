import 'package:flutter/material.dart';

import '../../core/models/dungeon_map.dart';
import '../../core/models/room.dart';
import '../../core/network/api_client.dart';

/// Endereço padrão do backend para desenvolvimento local. RF-46 (configurar
/// host/porta pela UI) ainda não está implementado — ver `apiClient` abaixo
/// para injetar outro endereço/cliente (ex.: em testes).
const _defaultBackendBaseUrl = 'http://localhost:8080';

const _cellSize = 26.0;

class DungeonMapScreen extends StatefulWidget {
  const DungeonMapScreen({super.key, this.apiClient, this.baseUrl = _defaultBackendBaseUrl});

  final ApiClient? apiClient;
  final String baseUrl;

  @override
  State<DungeonMapScreen> createState() => _DungeonMapScreenState();
}

class _DungeonMapScreenState extends State<DungeonMapScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient(baseUrl: widget.baseUrl);
  final _seedController = TextEditingController();

  Future<DungeonMap>? _mapFuture;
  String? _currentRoomId;
  final Set<String> _visited = {};

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  void _generate() {
    final seedText = _seedController.text.trim();
    final seed = seedText.isEmpty ? null : int.tryParse(seedText);
    setState(() {
      _currentRoomId = null;
      _visited.clear();
      _mapFuture = _apiClient
          .generateDungeon(width: 30, height: 18, seed: seed)
          .then((json) => DungeonMap.fromJson(json));
    });
  }

  void _tryMove(DungeonMap map, Room target) {
    if (target.id == _currentRoomId) {
      return;
    }
    final current = map.rooms[_currentRoomId]!;
    if (!current.connectedRoomIds.contains(target.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Essa sala não está conectada à sala atual.')),
      );
      return;
    }
    setState(() {
      _currentRoomId = target.id;
      _visited.add(target.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa da Masmorra')),
      body: Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<DungeonMap>(
              future: _mapFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildError(snapshot.error!);
                }
                final map = snapshot.data!;
                _currentRoomId ??= map.entranceRoomId;
                if (_visited.isEmpty) {
                  _visited.add(_currentRoomId!);
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Seed: ${map.seed}  •  ${map.width}×${map.height}'),
                      ),
                    ),
                    Expanded(child: _buildMap(map)),
                    _buildLegend(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _seedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Seed (opcional)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _generate, child: const Text('Gerar')),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível gerar a masmorra. Verifique se o backend está rodando.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text('$error', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _generate, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(DungeonMap map) {
    final current = map.rooms[_currentRoomId]!;
    final reachable = current.connectedRoomIds.toSet();

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(120),
      minScale: 0.4,
      maxScale: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var y = 0; y < map.height; y++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var x = 0; x < map.width; x++) _buildCell(map, map.roomAt(x, y)!, reachable),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell(DungeonMap map, Room room, Set<String> reachableFromCurrent) {
    final isCurrent = room.id == _currentRoomId;
    final isVisited = _visited.contains(room.id);
    final isReachable = !isCurrent && reachableFromCurrent.contains(room.id);
    final isWall = room.type == RoomType.wall;

    Border? border;
    if (isCurrent) {
      border = Border.all(color: Colors.cyanAccent, width: 3);
    } else if (isReachable) {
      border = Border.all(color: Colors.amberAccent, width: 2);
    }

    return GestureDetector(
      key: ValueKey('room-${room.id}'),
      onTap: isWall ? null : () => _tryMove(map, room),
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: _colorFor(room, isVisited),
          border: border,
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: isCurrent
            ? const Icon(Icons.person_pin_circle, size: 16, color: Colors.black87)
            : null,
      ),
    );
  }

  /// Cor da célula. Salas WALL/ENTRANCE/EXIT são estruturais e sempre
  /// visíveis; o conteúdo (LOOT/ENEMY) só é revelado depois de visitado —
  /// antes disso a sala aparece como piso genérico (fog of war, RF-18).
  Color _colorFor(Room room, bool isVisited) {
    switch (room.type) {
      case RoomType.wall:
        return const Color(0xFF2B2B31);
      case RoomType.entrance:
        return const Color(0xFF43A047);
      case RoomType.exit:
        return const Color(0xFF8E24AA);
      case RoomType.loot:
        return isVisited ? const Color(0xFFFFC107) : const Color(0xFFBDBDBD);
      case RoomType.enemy:
        return isVisited ? const Color(0xFFE53935) : const Color(0xFFBDBDBD);
      case RoomType.empty:
        return const Color(0xFFBDBDBD);
    }
  }

  Widget _buildLegend() {
    Widget entry(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          entry(const Color(0xFF43A047), 'Entrada'),
          entry(const Color(0xFF8E24AA), 'Saída'),
          entry(const Color(0xFFFFC107), 'Item (visitado)'),
          entry(const Color(0xFFE53935), 'Inimigo (visitado)'),
          entry(const Color(0xFFBDBDBD), 'Não explorada'),
          entry(const Color(0xFF2B2B31), 'Parede'),
        ],
      ),
    );
  }
}
