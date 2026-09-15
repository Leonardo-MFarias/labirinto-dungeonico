package com.furios.labirinto_dungeonico.api.dto;

/**
 * Corpo de {@code POST /api/session/{id}/character/attributes} (RF-07). {@code attribute} é
 * {@code String}, não {@link com.furios.labirinto_dungeonico.character.AttributeType}
 * diretamente, para que um nome inválido vire um
 * {@code InvalidAttributeAllocationException}/400 tratado, no mesmo padrão de {@link EquipRequest}.
 */
public record AllocateAttributeRequest(String attribute) {
}
