package com.furios.labirinto_dungeonico.api.dto;

/** Corpo de {@code POST /api/session/{id}/move} (RF-16). */
public record MoveRequest(String roomId) {
}
