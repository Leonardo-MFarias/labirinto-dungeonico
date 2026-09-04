package com.furios.labirinto_dungeonico.item;

public interface LootGenerator {

    Item generate(String baseType, int dungeonDepth);
}
