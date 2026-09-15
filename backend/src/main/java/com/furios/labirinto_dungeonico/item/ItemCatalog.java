package com.furios.labirinto_dungeonico.item;

import com.furios.labirinto_dungeonico.character.InvalidEquipException;

import java.util.Map;

/**
 * RN-24: mapeia o {@code baseType} de um item para sua categoria de equipamento. É uma
 * taxonomia fixa (todo "elmo" é sempre HEAD_ARMOR), não um dado de balanceamento — por isso
 * fica como constante no código, diferente de {@link AffixTable} (RNF-16 não se aplica aqui).
 */
public final class ItemCatalog {

    private static final Map<String, EquipmentCategory> CATEGORY_BY_BASE_TYPE = Map.of(
            "espada", EquipmentCategory.WEAPON,
            "machado", EquipmentCategory.WEAPON,
            "escudo", EquipmentCategory.SHIELD,
            "elmo", EquipmentCategory.HEAD_ARMOR,
            "peitoral", EquipmentCategory.CHEST_ARMOR,
            "calca", EquipmentCategory.LEG_ARMOR,
            "bota", EquipmentCategory.FOOT_ARMOR,
            "anel", EquipmentCategory.ACCESSORY
    );

    private ItemCatalog() {
    }

    public static EquipmentCategory categoryOf(String baseType) {
        EquipmentCategory category = CATEGORY_BY_BASE_TYPE.get(baseType);
        if (category == null) {
            throw new InvalidEquipException("Tipo de item sem categoria de equipamento conhecida: " + baseType);
        }
        return category;
    }
}
