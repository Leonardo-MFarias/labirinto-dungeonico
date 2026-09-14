import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/game/game_controller.dart';
import '../../core/models/combat_event.dart';

/// O backend resolve o combate por inteiro numa única chamada HTTP (não há
/// streaming em tempo real via WebSocket ainda — ver docs/requisitos.md,
/// PEND-13). Esta tela recebe a lista completa de eventos já pronta e a
/// revela um de cada vez, com as barras de vida acompanhando, para dar a
/// sensação de log em tempo real pedida por RF-28/RF-29.
class CombatScreen extends StatefulWidget {
  const CombatScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  final List<CombatEvent> _revealed = [];
  final _scrollController = ScrollController();
  int _playerHealth = 0;
  int _enemyHealth = 0;
  bool _animating = false;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    final events = widget.controller.lastCombatEvents;
    if (events != null && events.isNotEmpty) {
      _playerHealth = widget.controller.session?.character.maxHealth ?? 0;
      _enemyHealth = widget.controller.lastEnemy?.maxHealth ?? 0;
      _animating = true;
      _scheduleReveal(events, 0);
    }
  }

  void _scheduleReveal(List<CombatEvent> events, int index) {
    if (index >= events.length) {
      setState(() => _animating = false);
      return;
    }
    _revealTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _revealed.add(events[index]);
        _applyDamage(events[index]);
      });
      _scrollToBottom();
      _scheduleReveal(events, index + 1);
    });
  }

  void _skip() {
    _revealTimer?.cancel();
    final events = widget.controller.lastCombatEvents ?? const [];
    setState(() {
      for (final event in events.skip(_revealed.length)) {
        _revealed.add(event);
        _applyDamage(event);
      }
      _animating = false;
    });
    _scrollToBottom();
  }

  void _applyDamage(CombatEvent event) {
    if (event.amount <= 0) {
      return;
    }
    final playerId = widget.controller.session?.character.id;
    final enemyId = widget.controller.lastEnemy?.id;
    final playerMax = widget.controller.session?.character.maxHealth ?? 0;
    final enemyMax = widget.controller.lastEnemy?.maxHealth ?? 0;
    if (event.targetId == playerId) {
      _playerHealth = (_playerHealth - event.amount).clamp(0, playerMax);
    } else if (event.targetId == enemyId) {
      _enemyHealth = (_enemyHealth - event.amount).clamp(0, enemyMax);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _nameFor(String id) {
    if (id == widget.controller.session?.character.id) {
      return widget.controller.session!.character.name;
    }
    if (id == widget.controller.lastEnemy?.id) {
      return widget.controller.lastEnemy!.name;
    }
    return '???';
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.controller.lastCombatEvents;
    final enemy = widget.controller.lastEnemy;
    final character = widget.controller.session?.character;

    return Scaffold(
      appBar: AppBar(title: const Text('Combate')),
      body: (events == null || events.isEmpty || enemy == null || character == null)
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Nenhum combate ainda. Explore o mapa e entre em uma sala com inimigo.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      _healthBar(character.name, _playerHealth, character.maxHealth, Colors.teal),
                      const SizedBox(height: 8),
                      _healthBar(enemy.name, _enemyHealth, enemy.maxHealth, Colors.redAccent),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _revealed.length,
                    itemBuilder: (context, index) => _eventTile(_revealed[index]),
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _healthBar(String name, int current, int max, Color color) {
    final ratio = max == 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$name  ·  $current/$max'),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  Widget _eventTile(CombatEvent event) {
    final (label, color) = switch (event.type) {
      CombatEventType.attack => ('Ataque', Colors.blueGrey),
      CombatEventType.criticalHit => ('Crítico!', Colors.orange),
      CombatEventType.miss => ('Errou', Colors.grey),
      CombatEventType.death => ('Morte', Colors.red),
      CombatEventType.combatEnd => ('Fim do combate', Colors.purple),
    };
    final text = switch (event.type) {
      CombatEventType.attack || CombatEventType.criticalHit =>
        '${_nameFor(event.actorId)} acertou ${_nameFor(event.targetId)} em ${event.amount}',
      CombatEventType.miss => '${_nameFor(event.actorId)} errou o ataque',
      CombatEventType.death => '${_nameFor(event.targetId)} morreu',
      CombatEventType.combatEnd => '${_nameFor(event.actorId)} venceu o combate',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$label  ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_animating) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: OutlinedButton(onPressed: _skip, child: const Text('Pular')),
      );
    }
    final wonMessage = _revealed.isNotEmpty && _revealed.last.actorId == widget.controller.session?.character.id
        ? 'Vitória!'
        : 'Derrota.';
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Text(wonMessage, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
