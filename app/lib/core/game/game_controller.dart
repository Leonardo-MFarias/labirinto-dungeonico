import 'package:flutter/foundation.dart';

import '../models/character.dart';
import '../models/combat_event.dart';
import '../models/enemy.dart';
import '../models/game_session.dart';
import '../network/api_client.dart';

/// Estado da run atual, compartilhado entre as telas (Mapa, Combate,
/// Inventário, Personagem). Não há biblioteca de gerenciamento de estado no
/// projeto — este é um `ChangeNotifier` simples, criado uma vez em
/// `HomeScreen` e passado por construtor para as telas navegadas a partir
/// dela.
class GameController extends ChangeNotifier {
  GameController(this._apiClient);

  final ApiClient _apiClient;

  GameSession? session;

  /// Eventos do último combate resolvido, para a tela de Combate — tanto
  /// quando ela é aberta automaticamente após um movimento que desencadeou
  /// luta quanto quando é reaberta pela Home para rever o último resultado.
  List<CombatEvent>? lastCombatEvents;

  /// Inimigo do último combate, capturado *antes* do movimento — depois de
  /// derrotado a sala não guarda mais o inimigo, então sem isto a tela de
  /// Combate não teria nome/vida máxima para mostrar.
  Enemy? lastEnemy;

  bool loading = false;
  String? errorMessage;

  /// A sessão existe no backend, mas o personagem morreu em modo HARDCORE
  /// (RN-01) — o backend já encerrou a sessão do lado dele; a UI trata como
  /// fim de run.
  bool get isHardcoreDeath =>
      session != null && session!.character.mode == GameMode.hardcore && !session!.character.alive;

  /// Devolve `true` em caso de sucesso; `false` em caso de erro (fica em
  /// [errorMessage]).
  Future<bool> createSession({required String name, required GameMode mode, int? seed}) async {
    var success = false;
    await _run(() async {
      session = await _apiClient.createSession(name: name, mode: mode, seed: seed);
      lastCombatEvents = null;
      lastEnemy = null;
      success = true;
    });
    return success;
  }

  /// Move para `roomId`. Devolve `true` se o movimento desencadeou combate
  /// (chamador decide se navega para a tela de Combate) — `false` também em
  /// caso de erro (ex.: sala não conectada), que fica em [errorMessage].
  Future<bool> move(String roomId) async {
    final current = session;
    if (current == null) {
      return false;
    }
    final enemyBeforeMove = current.dungeonMap.rooms[roomId]?.enemy;
    var combatHappened = false;
    await _run(() async {
      final result = await _apiClient.move(current.id, roomId);
      session = result.session;
      if (result.combatEvents != null) {
        lastCombatEvents = result.combatEvents;
        lastEnemy = enemyBeforeMove;
        combatHappened = true;
      }
    });
    return combatHappened;
  }

  Future<void> loot() async {
    final current = session;
    if (current == null) {
      return;
    }
    await _run(() async {
      session = await _apiClient.loot(current.id);
    });
  }

  /// RF-19: avança para o próximo andar (só válido na sala de saída — erro
  /// fica em [errorMessage] caso contrário).
  Future<void> descend() async {
    final current = session;
    if (current == null) {
      return;
    }
    await _run(() async {
      session = await _apiClient.descend(current.id);
    });
  }

  /// RF-07: distribui um ponto de atributo não gasto (erro fica em
  /// [errorMessage] se não houver pontos disponíveis).
  Future<void> allocateAttribute(String attribute) async {
    final current = session;
    if (current == null) {
      return;
    }
    await _run(() async {
      session = await _apiClient.allocateAttribute(current.id, attribute);
    });
  }

  Future<void> equip({required String itemId, required String slot}) async {
    final current = session;
    if (current == null) {
      return;
    }
    await _run(() async {
      session = await _apiClient.equip(current.id, itemId: itemId, slot: slot);
    });
  }

  Future<void> unequip(String slot) async {
    final current = session;
    if (current == null) {
      return;
    }
    await _run(() async {
      session = await _apiClient.unequip(current.id, slot);
    });
  }

  void reset() {
    session = null;
    lastCombatEvents = null;
    lastEnemy = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      errorMessage = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
