package com.furios.labirinto_dungeonico.api.dto;

/**
 * Corpo de {@code POST /api/session/{id}/equip} (RF-37). {@code slot} é {@code String}, não
 * {@link com.furios.labirinto_dungeonico.character.Slot} diretamente, para que um nome inválido
 * vire um {@code InvalidEquipException}/400 tratado, em vez de um erro de desserialização do
 * Jackson não mapeado explicitamente.
 */
public record EquipRequest(String itemId, String slot) {
}
