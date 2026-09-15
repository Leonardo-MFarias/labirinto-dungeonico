import 'package:flutter/material.dart';

import 'item.dart';

/// RN-27: cor temática fixa por tipo de modificador de afixo — exibida num
/// selo/contorno separado da cor de raridade (RNF-09), nunca a substituindo.
const _colorByModifier = {
  'damage': Colors.red,
  'durability': Color(0xFF795548), // marrom
  'fireDamage': Colors.deepOrange,
  'speed': Colors.cyan,
  'defense': Color(0xFF4682B4), // azul-aço
  'magicPower': Colors.purple,
  'holyDamage': Color(0xFFFFD700), // dourado
  'darkDamage': Color(0xFF4A0072), // roxo-escuro
};

/// Ordem de prioridade pra desempate (Q-09) quando o item tem afixos de mais
/// de um tipo: elementais/raros primeiro, atributos genéricos por último.
const _modifierPriority = [
  'holyDamage',
  'darkDamage',
  'fireDamage',
  'magicPower',
  'damage',
  'defense',
  'speed',
  'durability',
];

/// A cor de afixo mais relevante presente no item, ou `null` se nenhum dos
/// seus afixos tiver um modificador conhecido (RN-27).
Color? primaryAffixColor(Item item) {
  final modifiers = <String>{};
  for (final affix in item.prefixes) {
    modifiers.addAll(affix.modifiers.keys);
  }
  for (final key in _modifierPriority) {
    if (modifiers.contains(key)) {
      return _colorByModifier[key];
    }
  }
  return null;
}
