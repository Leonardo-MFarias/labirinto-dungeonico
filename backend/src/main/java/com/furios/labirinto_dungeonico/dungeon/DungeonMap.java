package com.furios.labirinto_dungeonico.dungeon;

import com.fasterxml.jackson.annotation.JsonAutoDetect;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * fieldVisibility ANY: expõe os campos diretamente ao Jackson, já que a classe usa acessores
 * fluentes (seed(), rooms()) em vez do padrão getX() que o Jackson reconhece por padrão.
 */
@JsonAutoDetect(fieldVisibility = JsonAutoDetect.Visibility.ANY)
public class DungeonMap {

    private final String seed;
    private final String entranceRoomId;
    private final Map<String, Room> rooms = new LinkedHashMap<>();

    public DungeonMap(String seed, String entranceRoomId) {
        this.seed = seed;
        this.entranceRoomId = entranceRoomId;
    }

    public String seed() {
        return seed;
    }

    public String entranceRoomId() {
        return entranceRoomId;
    }

    public Map<String, Room> rooms() {
        return rooms;
    }
}
