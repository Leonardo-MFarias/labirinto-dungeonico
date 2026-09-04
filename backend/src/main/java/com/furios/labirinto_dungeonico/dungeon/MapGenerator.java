package com.furios.labirinto_dungeonico.dungeon;

public interface MapGenerator {

    DungeonMap generate(long seed, int roomCount);
}
