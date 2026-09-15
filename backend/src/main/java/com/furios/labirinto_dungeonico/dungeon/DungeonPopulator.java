package com.furios.labirinto_dungeonico.dungeon;

import com.furios.labirinto_dungeonico.combat.Enemy;
import com.furios.labirinto_dungeonico.combat.EnemyFactory;
import com.furios.labirinto_dungeonico.item.Item;
import com.furios.labirinto_dungeonico.item.LootGenerator;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Random;

/**
 * Povoa um {@link DungeonMap} já gerado: cria um {@link Enemy} escalado por profundidade em
 * cada sala {@code ENEMY} (RF-14) e um item em cada sala {@code LOOT} (RF-15). Percorre a grade
 * em ordem fixa (linha a linha) usando um único {@link Random} derivado da seed do mapa e da
 * profundidade, para que o povoamento seja determinístico (RNF-07/RNF-20) — não é
 * responsabilidade do {@link MapGenerator}, que só decide a forma da masmorra.
 */
@Component
public class DungeonPopulator {

    /** Catálogo provisório de tipos base de item (RF-30) — não há data file dedicado ainda. */
    public static final List<String> ITEM_BASE_TYPES =
            List.of("espada", "machado", "elmo", "peitoral", "anel", "bota", "calca", "escudo");

    private final EnemyFactory enemyFactory;
    private final LootGenerator lootGenerator;

    public DungeonPopulator(EnemyFactory enemyFactory, LootGenerator lootGenerator) {
        this.enemyFactory = enemyFactory;
        this.lootGenerator = lootGenerator;
    }

    public void populate(DungeonMap map, int depth) {
        Random random = new Random(map.seed().hashCode() * 31L + depth);

        for (int y = 0; y < map.height(); y++) {
            for (int x = 0; x < map.width(); x++) {
                Room room = map.rooms().get(x + "," + y);
                if (room == null) {
                    continue;
                }
                if (room.type() == RoomType.ENEMY) {
                    room.setEnemy(enemyFactory.create(random, depth));
                } else if (room.type() == RoomType.LOOT) {
                    String baseType = ITEM_BASE_TYPES.get(random.nextInt(ITEM_BASE_TYPES.size()));
                    Item item = lootGenerator.generate(random.nextLong(), baseType, depth);
                    room.items().add(item);
                }
            }
        }
    }
}
