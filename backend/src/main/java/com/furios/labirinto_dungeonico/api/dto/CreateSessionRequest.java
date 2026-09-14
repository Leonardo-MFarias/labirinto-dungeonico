package com.furios.labirinto_dungeonico.api.dto;

import com.furios.labirinto_dungeonico.character.GameMode;

/** Corpo de {@code POST /api/session} (RF-01, RF-02, RF-42). */
public record CreateSessionRequest(String name, GameMode mode, Long seed) {
}
