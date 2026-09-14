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
    private final int width;
    private final int height;
    private final Map<String, Room> rooms = new LinkedHashMap<>();

    public DungeonMap(String seed, String entranceRoomId, int width, int height) {
        this.seed = seed;
        this.entranceRoomId = entranceRoomId;
        this.width = width;
        this.height = height;
    }

    public String seed() {
        return seed;
    }

    public String entranceRoomId() {
        return entranceRoomId;
    }

    /** Largura da grade do autômato celular, em número de células. */
    public int width() {
        return width;
    }

    /** Altura da grade do autômato celular, em número de células. */
    public int height() {
        return height;
    }

    /**
     * Todas as células da grade (width × height), indexadas por "{x},{y}", inclusive as do
     * tipo WALL. Um app cliente pode reconstruir a grade completa iterando x de 0..width-1 e
     * y de 0..height-1 e buscando "{x},{y}" neste mapa.
     */
    public Map<String, Room> rooms() {
        return rooms;
    }
}
