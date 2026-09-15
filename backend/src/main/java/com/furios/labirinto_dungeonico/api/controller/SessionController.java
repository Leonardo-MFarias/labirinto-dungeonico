package com.furios.labirinto_dungeonico.api.controller;

import com.furios.labirinto_dungeonico.api.dto.CreateSessionRequest;
import com.furios.labirinto_dungeonico.api.dto.EquipRequest;
import com.furios.labirinto_dungeonico.api.dto.MoveRequest;
import com.furios.labirinto_dungeonico.api.dto.MoveResponse;
import com.furios.labirinto_dungeonico.api.dto.UnequipRequest;
import com.furios.labirinto_dungeonico.character.Attributes;
import com.furios.labirinto_dungeonico.character.Character;
import com.furios.labirinto_dungeonico.character.GameMode;
import com.furios.labirinto_dungeonico.character.InvalidEquipException;
import com.furios.labirinto_dungeonico.character.Slot;
import com.furios.labirinto_dungeonico.combat.CombatEvent;
import com.furios.labirinto_dungeonico.combat.CombatResolver;
import com.furios.labirinto_dungeonico.combat.Enemy;
import com.furios.labirinto_dungeonico.dungeon.DungeonMap;
import com.furios.labirinto_dungeonico.dungeon.DungeonPopulator;
import com.furios.labirinto_dungeonico.dungeon.MapGenerator;
import com.furios.labirinto_dungeonico.dungeon.Room;
import com.furios.labirinto_dungeonico.item.Item;
import com.furios.labirinto_dungeonico.item.LootGenerator;
import com.furios.labirinto_dungeonico.dungeon.RoomType;
import com.furios.labirinto_dungeonico.session.GameSession;
import com.furios.labirinto_dungeonico.session.InvalidDescendException;
import com.furios.labirinto_dungeonico.session.InvalidMoveException;
import com.furios.labirinto_dungeonico.session.SessionNotFoundException;
import com.furios.labirinto_dungeonico.session.SessionService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Random;
import java.util.UUID;

/**
 * Orquestra sessão, movimento, combate e coleta de loot (RF-01 a RF-04, RF-16, RF-17, RF-20 a
 * RF-29, RF-35, RF-36, RF-42 a RF-44). O combate é resolvido de forma síncrona dentro de
 * {@link #move}, não via {@code /ws/combat} (ver docs/requisitos.md — RF-24 continua pendente).
 */
@RestController
public class SessionController {

    private static final int STARTING_ATTRIBUTE = 5;
    private static final int DUNGEON_WIDTH = 40;
    private static final int DUNGEON_HEIGHT = 25;
    private static final int STARTING_DEPTH = 1;
    private static final double LOOT_DROP_CHANCE = 0.7;
    private static final double NORMAL_MODE_XP_PENALTY = 0.1;

    private final SessionService sessionService;
    private final MapGenerator mapGenerator;
    private final DungeonPopulator dungeonPopulator;
    private final CombatResolver combatResolver;
    private final LootGenerator lootGenerator;

    public SessionController(
            SessionService sessionService,
            MapGenerator mapGenerator,
            DungeonPopulator dungeonPopulator,
            CombatResolver combatResolver,
            LootGenerator lootGenerator) {
        this.sessionService = sessionService;
        this.mapGenerator = mapGenerator;
        this.dungeonPopulator = dungeonPopulator;
        this.combatResolver = combatResolver;
        this.lootGenerator = lootGenerator;
    }

    @ResponseStatus(HttpStatus.CREATED)
    @PostMapping("/api/session")
    public GameSession create(@RequestBody CreateSessionRequest request) {
        if (request.name() == null || request.name().isBlank()) {
            throw new IllegalArgumentException("name é obrigatório");
        }
        if (request.mode() == null) {
            throw new IllegalArgumentException("mode é obrigatório");
        }

        long seed = request.seed() != null ? request.seed() : System.currentTimeMillis();
        DungeonMap dungeonMap = mapGenerator.generate(seed, DUNGEON_WIDTH, DUNGEON_HEIGHT);
        dungeonPopulator.populate(dungeonMap, STARTING_DEPTH);

        Attributes attributes = new Attributes(
                STARTING_ATTRIBUTE, STARTING_ATTRIBUTE, STARTING_ATTRIBUTE,
                STARTING_ATTRIBUTE, STARTING_ATTRIBUTE, STARTING_ATTRIBUTE);
        Character character = new Character(UUID.randomUUID().toString(), request.name(), attributes, request.mode());
        GameSession session = new GameSession(UUID.randomUUID().toString(), character, dungeonMap, STARTING_DEPTH);
        return sessionService.save(session);
    }

    @GetMapping("/api/session/{id}")
    public GameSession get(@PathVariable String id) {
        return findOrThrow(id);
    }

    @GetMapping("/api/session/{id}/character")
    public Character getCharacter(@PathVariable String id) {
        return findOrThrow(id).character();
    }

    @PostMapping("/api/session/{id}/move")
    public MoveResponse move(@PathVariable String id, @RequestBody MoveRequest request) {
        GameSession session = findOrThrow(id);
        Room currentRoom = session.dungeonMap().rooms().get(session.currentRoomId());
        if (!currentRoom.connectedRoomIds().contains(request.roomId())) {
            throw new InvalidMoveException("Sala " + request.roomId() + " não está conectada à sala atual.");
        }

        session.moveTo(request.roomId());
        Room targetRoom = session.dungeonMap().rooms().get(request.roomId());

        List<CombatEvent> combatEvents = null;
        if (targetRoom.enemy() != null) {
            combatEvents = fight(session, targetRoom);
        }

        // RF-44: fight() pode ter encerrado a sessão (morte em HARDCORE) — não a ressuscitar
        // salvando de volta incondicionalmente.
        if (sessionService.find(session.id()).isPresent()) {
            sessionService.save(session);
        }
        return new MoveResponse(session, combatEvents);
    }

    @PostMapping("/api/session/{id}/loot")
    public GameSession loot(@PathVariable String id) {
        GameSession session = findOrThrow(id);
        Room room = session.dungeonMap().rooms().get(session.currentRoomId());
        for (Item item : room.items()) {
            session.character().addItem(item);
        }
        room.items().clear();
        return sessionService.save(session);
    }

    /** RF-19: avança para um novo andar a partir da sala EXIT do andar atual, gerando e
     * povoando uma nova masmorra com profundidade incrementada. Ação explícita do jogador
     * (não automática ao entrar na sala EXIT), no mesmo padrão de RF-35 (loot). A seed do
     * novo andar deriva da seed do andar atual e da nova profundidade, preservando RN-12
     * (determinismo) sem depender de entrada do cliente. */
    @PostMapping("/api/session/{id}/descend")
    public GameSession descend(@PathVariable String id) {
        GameSession session = findOrThrow(id);
        Room currentRoom = session.dungeonMap().rooms().get(session.currentRoomId());
        if (currentRoom.type() != RoomType.EXIT) {
            throw new InvalidDescendException("O personagem precisa estar na sala de saída para descer de andar.");
        }

        int newDepth = session.depth() + 1;
        long newSeed = session.dungeonMap().seed().hashCode() * 31L + newDepth;
        DungeonMap newDungeonMap = mapGenerator.generate(newSeed, DUNGEON_WIDTH, DUNGEON_HEIGHT);
        dungeonPopulator.populate(newDungeonMap, newDepth);
        session.descendTo(newDungeonMap);

        return sessionService.save(session);
    }

    /** RF-37/RN-23 a RN-25: equipa um item do inventário num slot compatível. */
    @PostMapping("/api/session/{id}/equip")
    public GameSession equip(@PathVariable String id, @RequestBody EquipRequest request) {
        if (request.itemId() == null || request.slot() == null) {
            throw new IllegalArgumentException("itemId e slot são obrigatórios");
        }
        GameSession session = findOrThrow(id);
        session.character().equip(request.itemId(), parseSlot(request.slot()));
        return sessionService.save(session);
    }

    /** RF-38: desequipa o slot informado, devolvendo o item ao inventário. */
    @PostMapping("/api/session/{id}/unequip")
    public GameSession unequip(@PathVariable String id, @RequestBody UnequipRequest request) {
        if (request.slot() == null) {
            throw new IllegalArgumentException("slot é obrigatório");
        }
        GameSession session = findOrThrow(id);
        session.character().unequip(parseSlot(request.slot()));
        return sessionService.save(session);
    }

    private Slot parseSlot(String raw) {
        try {
            return Slot.valueOf(raw);
        } catch (IllegalArgumentException e) {
            throw new InvalidEquipException("Slot inválido: " + raw);
        }
    }

    /** RF-20 a RF-27: resolve o combate e aplica o resultado (XP/loot ou RN-01/RN-02). */
    private List<CombatEvent> fight(GameSession session, Room room) {
        Character character = session.character();
        Enemy enemy = room.enemy();
        long combatSeed = session.dungeonMap().seed().hashCode() * 31L + room.id().hashCode();

        List<CombatEvent> events = combatResolver.resolve(character, enemy, combatSeed);

        if (character.isAlive()) {
            room.setEnemy(null);
            int xp = enemy.maxHealth() / 2 + sumAttributes(enemy.attributes());
            character.gainExperience(xp);
            grantLoot(character, session.depth(), combatSeed);
        } else if (character.mode() == GameMode.HARDCORE) {
            sessionService.remove(session.id());
        } else {
            character.gainExperience(-(int) (character.experience() * NORMAL_MODE_XP_PENALTY));
            character.resetHealth();
            session.returnToEntrance();
        }
        return events;
    }

    private void grantLoot(Character character, int depth, long combatSeed) {
        Random dropRoll = new Random(combatSeed);
        if (dropRoll.nextDouble() >= LOOT_DROP_CHANCE) {
            return;
        }
        String baseType = DungeonPopulator.ITEM_BASE_TYPES.get(
                dropRoll.nextInt(DungeonPopulator.ITEM_BASE_TYPES.size()));
        Item item = lootGenerator.generate(dropRoll.nextLong(), baseType, depth);
        character.addItem(item);
    }

    private int sumAttributes(Attributes attributes) {
        return attributes.strength() + attributes.agility() + attributes.vitality()
                + attributes.speed() + attributes.defense() + attributes.intelligence();
    }

    private GameSession findOrThrow(String id) {
        return sessionService.find(id).orElseThrow(() -> new SessionNotFoundException(id));
    }
}
