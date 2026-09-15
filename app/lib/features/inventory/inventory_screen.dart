import 'package:flutter/material.dart';

import '../../core/game/game_controller.dart';
import '../../core/models/affix_colors.dart';
import '../../core/models/equipment_category.dart';
import '../../core/models/item.dart';
import '../../core/models/rarity_colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
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

  Future<void> _collectLoot() async {
    await widget.controller.loot();
    if (!mounted) {
      return;
    }
    if (widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventário')),
        body: const Center(child: Text('Nenhuma sessão ativa.')),
      );
    }

    final currentRoom = session.dungeonMap.rooms[session.currentRoomId]!;
    final hasLootHere = currentRoom.items.isNotEmpty;
    final inventory = session.character.inventory;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventário')),
      body: Column(
        children: [
          if (hasLootHere)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                onPressed: widget.controller.loading ? null : _collectLoot,
                icon: const Icon(Icons.move_to_inbox),
                label: Text('Coletar ${currentRoom.items.length} item(ns) da sala'),
              ),
            ),
          Expanded(
            child: inventory.isEmpty
                ? const Center(child: Text('Inventário vazio.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: inventory.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) => _itemTile(inventory[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(Item item) {
    final color = rarityColors[item.rarity]!;
    final label = rarityLabels[item.rarity]!;
    final affixColor = primaryAffixColor(item);
    return ListTile(
      // RF-58: ícone da categoria em cor neutra — raridades claras (ex.: Normal,
      // quase branca) ficariam praticamente invisíveis se tingidas com a cor de
      // raridade num fundo claro, então essa cor fica só no selo abaixo.
      leading: Icon(iconForBaseType(item.baseType)),
      title: Text(_capitalize(item.baseType)),
      subtitle: Text(
        '$label  ·  nível ${item.itemLevel}'
        '${item.prefixes.isNotEmpty ? '  ·  ${item.prefixes.map((a) => a.name).join(', ')}' : ''}',
      ),
      // RNF-09: selo de raridade; RF-59/RN-27: selo de afixo, ambos com contorno
      // pra ficarem legíveis mesmo quando a cor de raridade é bem clara.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(backgroundColor: color, radius: 6, child: _dotBorder(color)),
          if (affixColor != null) ...[
            const SizedBox(width: 4),
            CircleAvatar(backgroundColor: affixColor, radius: 6, child: _dotBorder(affixColor)),
          ],
        ],
      ),
    );
  }

  /// Contorno sutil pro selo de cor não sumir contra o fundo quando a cor em
  /// si for muito clara (ex.: raridade Normal).
  Widget _dotBorder(Color fill) => Container(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black26)),
      );

  String _capitalize(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}
