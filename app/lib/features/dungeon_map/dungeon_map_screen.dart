import 'package:flutter/material.dart';

import '../../core/game/game_controller.dart';
import '../../core/models/game_session.dart';
import '../../core/models/room.dart';

const _cellSize = 26.0;

class DungeonMapScreen extends StatefulWidget {
  const DungeonMapScreen({super.key, required this.controller, this.onCombatTriggered});

  final GameController controller;

  /// RF-57: chamado quando um movimento desencadeia combate, para que quem
  /// hospeda a tela decida como navegar (ex.: o shell troca de aba). Se
  /// `null`, a tela não navega sozinha — o combate já foi resolvido no
  /// servidor de qualquer forma, só a UI não reage automaticamente.
  final VoidCallback? onCombatTriggered;

  @override
  State<DungeonMapScreen> createState() => _DungeonMapScreenState();
}

class _DungeonMapScreenState extends State<DungeonMapScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _tryMove(Room room) async {
    final controller = widget.controller;
    final combatHappened = await controller.move(room.id);
    if (!mounted) {
      return;
    }
    if (controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage!)),
      );
      return;
    }
    if (combatHappened) {
      widget.onCombatTriggered?.call();
    }
  }

  /// RF-19: avança para o próximo andar a partir da sala de saída.
  Future<void> _descend() async {
    final controller = widget.controller;
    await controller.descend();
    if (!mounted) {
      return;
    }
    if (controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa da Masmorra')),
      body: session == null
          ? const Center(child: Text('Nenhuma sessão ativa.'))
          : widget.controller.isHardcoreDeath
              ? _buildRunEnded(context)
              : _buildMap(session),
    );
  }

  Widget _buildRunEnded(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dangerous, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Seu personagem morreu em modo Hardcore. A run acabou.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                widget.controller.reset();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(GameSession session) {
    final current = session.dungeonMap.rooms[session.currentRoomId]!;
    final reachable = current.connectedRoomIds.toSet();
    final onExit = current.type == RoomType.exit;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Profundidade ${session.depth}  •  Vida ${session.character.currentHealth}/${session.character.maxHealth}',
                ),
              ),
              if (onExit)
                ElevatedButton.icon(
                  onPressed: widget.controller.loading ? null : _descend,
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('Descer'),
                ),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(120),
            minScale: 0.4,
            maxScale: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var y = 0; y < session.dungeonMap.height; y++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var x = 0; x < session.dungeonMap.width; x++)
                        _buildCell(session, session.dungeonMap.roomAt(x, y)!, reachable),
                    ],
                  ),
              ],
            ),
          ),
        ),
        _buildLegend(),
      ],
    );
  }

  Widget _buildCell(GameSession session, Room room, Set<String> reachableFromCurrent) {
    final isCurrent = room.id == session.currentRoomId;
    final isVisited = session.visitedRoomIds.contains(room.id);
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
      onTap: (isReachable && !isWall) ? () => _tryMove(room) : null,
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
  /// visíveis; o conteúdo (inimigo vivo/item ainda na sala) só é revelado
  /// depois de visitado — antes disso a sala aparece como piso genérico
  /// (fog of war, RF-18). O `type` continua ENEMY/LOOT mesmo depois de
  /// derrotado/coletado — por isso o estado real (`enemy`/`items`) é que
  /// decide a cor, não só o tipo.
  Color _colorFor(Room room, bool isVisited) {
    switch (room.type) {
      case RoomType.wall:
        return const Color(0xFF2B2B31);
      case RoomType.entrance:
        return const Color(0xFF43A047);
      case RoomType.exit:
        return const Color(0xFF8E24AA);
      case RoomType.loot:
        return (isVisited && room.items.isNotEmpty) ? const Color(0xFFFFC107) : const Color(0xFFBDBDBD);
      case RoomType.enemy:
        return (isVisited && room.enemy != null) ? const Color(0xFFE53935) : const Color(0xFFBDBDBD);
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
          entry(const Color(0xFFFFC107), 'Item disponível'),
          entry(const Color(0xFFE53935), 'Inimigo vivo'),
          entry(const Color(0xFFBDBDBD), 'Explorada / não explorada'),
          entry(const Color(0xFF2B2B31), 'Parede'),
        ],
      ),
    );
  }
}
