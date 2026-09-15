import 'package:flutter/material.dart';

/// RN-24: categorias de equipamento, derivadas do `baseType` do item. Tabela
/// **só para UX** — destaca o(s) slot(s) compatíveis durante o arraste
/// (RF-56). A validação real de compatibilidade é sempre do servidor
/// (RN-13); se este espelho ficar desatualizado em relação a
/// `ItemCatalog`/`EquipmentCategory` do backend, o pior caso é um destaque
/// incorreto na UI — o backend recusa o equip de qualquer forma.
enum EquipmentCategory { weapon, shield, headArmor, chestArmor, legArmor, footArmor, accessory }

const _categoryByBaseType = {
  'espada': EquipmentCategory.weapon,
  'machado': EquipmentCategory.weapon,
  'escudo': EquipmentCategory.shield,
  'elmo': EquipmentCategory.headArmor,
  'peitoral': EquipmentCategory.chestArmor,
  'calca': EquipmentCategory.legArmor,
  'bota': EquipmentCategory.footArmor,
  'anel': EquipmentCategory.accessory,
};

const _slotsByCategory = {
  EquipmentCategory.weapon: ['HAND_LEFT', 'HAND_RIGHT'],
  EquipmentCategory.shield: ['HAND_LEFT', 'HAND_RIGHT'],
  EquipmentCategory.headArmor: ['HEAD'],
  EquipmentCategory.chestArmor: ['CHEST'],
  EquipmentCategory.legArmor: ['LEGS'],
  EquipmentCategory.footArmor: ['FEET'],
  EquipmentCategory.accessory: ['ACCESSORY_1', 'ACCESSORY_2'],
};

/// RN-23: os oito slots de equipamento, na ordem em que aparecem na UI.
const kSlots = [
  'HEAD',
  'CHEST',
  'LEGS',
  'FEET',
  'HAND_LEFT',
  'HAND_RIGHT',
  'ACCESSORY_1',
  'ACCESSORY_2',
];

const kSlotLabels = {
  'HEAD': 'Cabeça',
  'CHEST': 'Peito',
  'LEGS': 'Pernas',
  'FEET': 'Pés',
  'HAND_LEFT': 'Mão esquerda',
  'HAND_RIGHT': 'Mão direita',
  'ACCESSORY_1': 'Acessório 1',
  'ACCESSORY_2': 'Acessório 2',
};

/// Slots em que um item com este `baseType` pode ser equipado, ou lista
/// vazia se o tipo não tiver categoria conhecida.
List<String> compatibleSlots(String baseType) => _slotsByCategory[_categoryByBaseType[baseType]] ?? const [];

/// RF-58: ícone por categoria de equipamento (todos confirmados existentes no
/// conjunto de ícones do Material Design incluído no SDK do Flutter em uso —
/// ver Q-09).
const _iconByCategory = {
  EquipmentCategory.weapon: Icons.gavel,
  EquipmentCategory.shield: Icons.shield,
  EquipmentCategory.headArmor: Icons.sports_motorsports,
  EquipmentCategory.chestArmor: Icons.checkroom,
  EquipmentCategory.legArmor: Icons.accessibility_new,
  EquipmentCategory.footArmor: Icons.directions_walk,
  EquipmentCategory.accessory: Icons.diamond,
};

/// Ícone para o `baseType` do item, ou um ícone genérico se a categoria for
/// desconhecida.
IconData iconForBaseType(String baseType) => _iconByCategory[_categoryByBaseType[baseType]] ?? Icons.category;
