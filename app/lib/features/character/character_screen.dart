import 'package:flutter/material.dart';

import '../../core/game/game_controller.dart';
import '../../core/models/affix_colors.dart';
import '../../core/models/attributes.dart';
import '../../core/models/character.dart';
import '../../core/models/equipment_category.dart';
import '../../core/models/item.dart';
import '../../core/models/rarity_colors.dart';
import 'equipment_slots.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
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

  Future<void> _handleEquip(String itemId, String slot) async {
    await widget.controller.equip(itemId: itemId, slot: slot);
    _showErrorIfAny();
  }

  Future<void> _handleUnequip(String slot) async {
    await widget.controller.unequip(slot);
    _showErrorIfAny();
  }

  void _showErrorIfAny() {
    if (!mounted) {
      return;
    }
    if (widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage!)),
      );
    }
  }

  void _showCompare(Item item, Map<String, Item> equipped) {
    final slots = compatibleSlots(item.baseType);
    Item? equippedInSlot;
    for (final slot in slots) {
      if (equipped[slot] != null) {
        equippedInSlot = equipped[slot];
        break;
      }
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Comparar ${_capitalize(item.baseType)}'),
        content: equippedInSlot == null
            ? const Text('Sem item equipado para comparar.')
            : _compareTable(item, equippedInSlot),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _compareTable(Item candidate, Item equipped) {
    final candidateMods = _attributeModifiers(candidate);
    final equippedMods = _attributeModifiers(equipped);
    final keys = {...candidateMods.keys, ...equippedMods.keys};
    if (keys.isEmpty) {
      return const Text('Nenhum dos dois itens concede atributos.');
    }
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: [
        for (final key in keys)
          TableRow(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(key)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Builder(builder: (context) {
                final delta = (candidateMods[key] ?? 0) - (equippedMods[key] ?? 0);
                final sign = delta > 0 ? '+' : '';
                return Text(
                  '$sign${delta.toStringAsFixed(0)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: delta > 0 ? Colors.green : delta < 0 ? Colors.red : null),
                );
              }),
            ),
          ]),
      ],
    );
  }

  Map<String, double> _attributeModifiers(Item item) {
    const attributeNames = {'strength', 'agility', 'vitality', 'speed', 'defense', 'intelligence'};
    final totals = <String, double>{};
    for (final affix in item.prefixes) {
      for (final entry in affix.modifiers.entries) {
        if (attributeNames.contains(entry.key)) {
          totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
        }
      }
    }
    return totals;
  }

  String _capitalize(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final character = widget.controller.session?.character;
    return Scaffold(
      appBar: AppBar(title: const Text('Personagem')),
      body: character == null
          ? const Center(child: Text('Nenhuma sessão ativa.'))
          : _buildSheet(character),
    );
  }

  Widget _buildSheet(Character character) {
    final ratio = character.maxHealth == 0
        ? 0.0
        : (character.currentHealth / character.maxHealth).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(character.name, style: Theme.of(context).textTheme.headlineSmall),
        Text(character.mode == GameMode.hardcore ? 'Hardcore' : 'Normal'),
        const SizedBox(height: 16),
        Text('Nível ${character.level}  ·  ${character.experience} XP'),
        const SizedBox(height: 8),
        Text('Vida: ${character.currentHealth}/${character.maxHealth}'
            '${character.alive ? '' : ' (morto)'}'),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            color: character.alive ? Colors.teal : Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        Text('Atributos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _attributesTable(character.attributes, character.effectiveAttributes),
        const SizedBox(height: 24),
        Text('Equipamento', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        EquipmentSlots(
          equipped: character.equipped,
          onEquip: _handleEquip,
          onUnequip: _handleUnequip,
        ),
        const SizedBox(height: 24),
        Text('Inventário (arraste até um slot)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _draggableInventory(character),
      ],
    );
  }

  Widget _draggableInventory(Character character) {
    if (character.inventory.isEmpty) {
      return const Text('Inventário vazio.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in character.inventory)
          Draggable<Item>(
            data: item,
            feedback: Material(elevation: 4, child: _itemChip(item)),
            childWhenDragging: Opacity(opacity: 0.3, child: _itemChip(item)),
            child: GestureDetector(
              onLongPress: () => _showCompare(item, character.equipped),
              child: _itemChip(item),
            ),
          ),
      ],
    );
  }

  Widget _itemChip(Item item) {
    final rarityColor = rarityColors[item.rarity]!;
    final affixColor = primaryAffixColor(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // Fundo neutro sutil: sem ele, raridades bem claras (ex.: Normal,
        // quase branca) deixariam a borda praticamente invisível.
        color: Colors.grey.withValues(alpha: 0.08),
        border: Border.all(color: rarityColor, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForBaseType(item.baseType), size: 18),
          const SizedBox(width: 6),
          Text(_capitalize(item.baseType)),
          if (affixColor != null) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              backgroundColor: affixColor,
              radius: 5,
              child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attributesTable(Attributes base, Attributes effective) {
    final rows = {
      'Força': (base.strength, effective.strength),
      'Agilidade': (base.agility, effective.agility),
      'Vitalidade': (base.vitality, effective.vitality),
      'Velocidade': (base.speed, effective.speed),
      'Defesa': (base.defense, effective.defense),
      'Inteligência': (base.intelligence, effective.intelligence),
    };
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: [
        for (final entry in rows.entries)
          TableRow(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(entry.key)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Builder(builder: (context) {
                final (baseValue, effectiveValue) = entry.value;
                final differs = effectiveValue != baseValue;
                return Text(
                  differs ? '$effectiveValue (base $baseValue)' : '$effectiveValue',
                  textAlign: TextAlign.right,
                  style: differs && effectiveValue > baseValue ? const TextStyle(color: Colors.green) : null,
                );
              }),
            ),
          ]),
      ],
    );
  }
}
