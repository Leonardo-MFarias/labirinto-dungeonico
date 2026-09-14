package com.furios.labirinto_dungeonico.item;

public interface LootGenerator {

    /** Gera um item determinado por {@code seed} (RNF-07/RNF-20). */
    Item generate(long seed, String baseType, int dungeonDepth);
}
