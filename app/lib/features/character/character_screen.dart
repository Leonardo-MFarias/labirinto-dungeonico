import 'package:flutter/material.dart';

import '../../core/game/game_controller.dart';
import '../../core/models/attributes.dart';
import '../../core/models/character.dart';

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
        _attributesTable(character.attributes),
      ],
    );
  }

  Widget _attributesTable(Attributes attributes) {
    final rows = {
      'Força': attributes.strength,
      'Agilidade': attributes.agility,
      'Vitalidade': attributes.vitality,
      'Velocidade': attributes.speed,
      'Defesa': attributes.defense,
      'Inteligência': attributes.intelligence,
    };
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: [
        for (final entry in rows.entries)
          TableRow(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(entry.key)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${entry.value}', textAlign: TextAlign.right),
            ),
          ]),
      ],
    );
  }
}
