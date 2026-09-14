package com.furios.labirinto_dungeonico.dungeon;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RandomMapGeneratorTest {

    private final RandomMapGenerator generator = new RandomMapGenerator();

    @ParameterizedTest
    @ValueSource(longs = {1L, 2L, 42L, 12345L, 999999L})
    void mesmaSeedProduzAMesmaMasmorra(long seed) {
        DungeonMap first = generator.generate(seed, 40, 25);
        DungeonMap second = generator.generate(seed, 40, 25);

        assertEquals(toRoomTypeString(first), toRoomTypeString(second));
    }

    @ParameterizedTest
    @ValueSource(longs = {1L, 2L, 42L, 12345L, 999999L})
    void gradeEDensaComTodasAsCelulas(long seed) {
        int width = 40;
        int height = 25;
        DungeonMap map = generator.generate(seed, width, height);

        assertEquals(width * height, map.rooms().size());
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                assertNotNull(map.rooms().get(x + "," + y));
            }
        }
    }

    @ParameterizedTest
    @ValueSource(longs = {1L, 2L, 42L, 12345L, 999999L})
    void existeCaminhoEntreEntradaESaida(long seed) {
        DungeonMap map = generator.generate(seed, 40, 25);

        Room entrance = map.rooms().get(map.entranceRoomId());
        assertNotNull(entrance);
        assertEquals(RoomType.ENTRANCE, entrance.type());

        Room exit = findExit(map);
        assertNotNull(exit, "Deve existir uma sala EXIT na masmorra");

        assertTrue(isReachable(map, entrance.id(), exit.id()));
    }

    @Test
    void nenhumaSalaAndavelConectaComParede() {
        DungeonMap map = generator.generate(7L, 40, 25);

        for (Room room : map.rooms().values()) {
            if (room.type() == RoomType.WALL) {
                assertTrue(room.connectedRoomIds().isEmpty());
                continue;
            }
            for (String neighborId : room.connectedRoomIds()) {
                Room neighbor = map.rooms().get(neighborId);
                assertNotNull(neighbor);
                assertTrue(neighbor.type() != RoomType.WALL);
            }
        }
    }

    private Room findExit(DungeonMap map) {
        return map.rooms().values().stream()
                .filter(room -> room.type() == RoomType.EXIT)
                .findFirst()
                .orElse(null);
    }

    private boolean isReachable(DungeonMap map, String fromId, String toId) {
        Set<String> visited = new HashSet<>();
        Deque<String> queue = new ArrayDeque<>();
        queue.add(fromId);
        visited.add(fromId);

        while (!queue.isEmpty()) {
            String currentId = queue.poll();
            if (currentId.equals(toId)) {
                return true;
            }
            Room current = map.rooms().get(currentId);
            for (String neighborId : current.connectedRoomIds()) {
                if (visited.add(neighborId)) {
                    queue.add(neighborId);
                }
            }
        }
        return false;
    }

    private String toRoomTypeString(DungeonMap map) {
        StringBuilder builder = new StringBuilder();
        for (int y = 0; y < map.height(); y++) {
            for (int x = 0; x < map.width(); x++) {
                Room room = map.rooms().get(x + "," + y);
                builder.append(room.type().name()).append(',');
            }
        }
        return builder.toString();
    }
}
