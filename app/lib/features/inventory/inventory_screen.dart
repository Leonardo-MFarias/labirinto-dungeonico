import 'package:flutter/material.dart';

import '../../core/game/game_controller.dart';
import '../../core/models/item.dart';
import '../../core/models/rarity.dart';

/// RNF-09: raridade distinguível por cor **e** rótulo textual, não só cor.
const _rarityLabels = {
  Rarity.obsoleto: 'Obsoleto',
  Rarity.arcaico: 'Arcaico',
  Rarity.trivial: 'Trivial',
  Rarity.normal: 'Normal',
  Rarity.comum: 'Comum',
  Rarity.incomum: 'Incomum',
  Rarity.lendario: 'Lendário',
  Rarity.mitico: 'Mítico',
  Rarity.divino: 'Divino',
  Rarity.astral: 'Astral',
};

const _rarityColors = {
  Rarity.obsoleto: Color(0xFF6D6D6D),
  Rarity.arcaico: Color(0xFF8D6E63),
  Rarity.trivial: Color(0xFF9E9E9E),
  Rarity.normal: Color(0xFFEEEEEE),
  Rarity.comum: Color(0xFF4CAF50),
  Rarity.incomum: Color(0xFF2196F3),
  Rarity.lendario: Color(0xFFFF9800),
  Rarity.mitico: Color(0xFFE91E63),
  Rarity.divino: Color(0xFFFFD700),
  Rarity.astral: Color(0xFF00E5FF),
};

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
    final color = _rarityColors[item.rarity]!;
    final label = _rarityLabels[item.rarity]!;
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 8),
      title: Text(_capitalize(item.baseType)),
      subtitle: Text(
        '$label  ·  nível ${item.itemLevel}'
        '${item.prefixes.isNotEmpty ? '  ·  ${item.prefixes.map((a) => a.name).join(', ')}' : ''}',
      ),
    );
  }

  String _capitalize(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}
