import 'package:flutter/material.dart';

import '../../core/game/game_controller.dart';
import '../character/character_screen.dart';
import '../combat/combat_screen.dart';
import '../dungeon_map/dungeon_map_screen.dart';
import '../inventory/inventory_screen.dart';

/// RF-57: navegação global entre as quatro telas do jogo (Mapa, Combate,
/// Inventário, Personagem), sem precisar voltar à Home a cada troca. As
/// quatro telas ficam vivas simultaneamente num [IndexedStack] — trocar de
/// aba não recria o estado delas (ex.: posição de rolagem do inventário é
/// preservada).
class GameShell extends StatefulWidget {
  const GameShell({super.key, required this.controller, this.initialIndex = 0});

  final GameController controller;
  final int initialIndex;

  @override
  State<GameShell> createState() => GameShellState();
}

class GameShellState extends State<GameShell> {
  late int _index = widget.initialIndex;

  void showTab(int index) => setState(() => _index = index);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DungeonMapScreen(controller: widget.controller, onCombatTriggered: () => showTab(1)),
          // A `key` muda a cada combate (nova instância de `lastCombatEvents` a cada luta) para
          // que o Flutter recrie o estado da tela e a animação de revelação dispare de novo —
          // sem isso, como o IndexedStack mantém o elemento vivo entre lutas, uma segunda luta
          // na mesma visita ao shell não reiniciaria `_scheduleReveal` (só roda em initState).
          CombatScreen(
            key: ValueKey(widget.controller.lastCombatEvents),
            controller: widget.controller,
            onFinished: () => showTab(0),
          ),
          InventoryScreen(controller: widget.controller),
          CharacterScreen(controller: widget.controller),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: showTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.sports_kabaddi), label: 'Combate'),
          NavigationDestination(icon: Icon(Icons.backpack), label: 'Inventário'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Personagem'),
        ],
      ),
    );
  }
}
