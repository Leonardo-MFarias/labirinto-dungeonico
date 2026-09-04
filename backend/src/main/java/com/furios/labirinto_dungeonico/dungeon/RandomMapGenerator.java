package com.furios.labirinto_dungeonico.dungeon;

import org.springframework.stereotype.Service;

@Service
public class RandomMapGenerator implements MapGenerator {

    @Override
    public DungeonMap generate(long seed, int roomCount) {
        // TODO: implementar algoritmo procedural real (ex: random walk / BSP) conectando as salas
        DungeonMap map = new DungeonMap(String.valueOf(seed), "room-0");
        Room entrance = new Room("room-0", RoomType.ENTRANCE);
        map.rooms().put(entrance.id(), entrance);
        return map;
    }
}
