package com.furios.labirinto_dungeonico.api.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.furios.labirinto_dungeonico.character.Slot;
import com.furios.labirinto_dungeonico.item.ItemCatalog;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Teste-âncora da cadeia sessão → movimento → combate → loot, ponta a ponta via HTTP (RF-01 a
 * RF-04, RF-16, RF-17, RF-20 a RF-27, RF-35, RF-36, RF-42 a RF-44). As classes de domínio
 * (GameSession, Character, DungeonMap, Room...) só são serializadas como saída da API, nunca
 * desserializadas de volta — por isso este teste navega as respostas como {@link JsonNode} em
 * vez de tentar reconstruir os objetos de domínio a partir do JSON.
 */
@SpringBootTest
@AutoConfigureMockMvc
class SessionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void sessaoInexistenteDevolve404() throws Exception {
        mockMvc.perform(get("/api/session/nao-existe")).andExpect(status().isNotFound());
    }

    @Test
    void criaSessaoEConsultaPorId() throws Exception {
        JsonNode session = createSession(1L, "Aria", "NORMAL");
        String sessionId = session.get("id").asText();
        String entranceId = session.get("dungeonMap").get("entranceRoomId").asText();

        assertEquals("Aria", session.get("character").get("name").asText());
        assertEquals(entranceId, session.get("currentRoomId").asText());
        assertTrue(toStringList(session.get("visitedRoomIds")).contains(entranceId));
        // maxHealth() é um método calculado, não um campo — precisa de @JsonProperty explícito
        // pra aparecer no JSON (sem isso o app não consegue montar a barra de vida).
        assertTrue(session.get("character").get("maxHealth").asInt() > 0);

        MvcResult result = mockMvc.perform(get("/api/session/" + sessionId))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode fetched = objectMapper.readTree(result.getResponse().getContentAsString());
        assertEquals(sessionId, fetched.get("id").asText());

        mockMvc.perform(get("/api/session/" + sessionId + "/character")).andExpect(status().isOk());
    }

    @Test
    void moverParaSalaNaoConectadaDevolve400() throws Exception {
        JsonNode session = createSession(2L, "Bram", "NORMAL");
        String sessionId = session.get("id").asText();
        JsonNode rooms = session.get("dungeonMap").get("rooms");
        JsonNode current = rooms.get(session.get("currentRoomId").asText());
        List<String> connected = toStringList(current.get("connectedRoomIds"));

        String notConnected = null;
        for (Iterator<String> it = rooms.fieldNames(); it.hasNext(); ) {
            String roomId = it.next();
            if (!roomId.equals(current.get("id").asText()) && !connected.contains(roomId)) {
                notConnected = roomId;
                break;
            }
        }
        assertTrue(notConnected != null, "Esperava encontrar uma sala não conectada");

        mockMvc.perform(post("/api/session/" + sessionId + "/move")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("roomId", notConnected))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void moverParaSalaConectadaAtualizaSessao() throws Exception {
        JsonNode session = createSession(3L, "Cael", "NORMAL");
        String sessionId = session.get("id").asText();
        JsonNode rooms = session.get("dungeonMap").get("rooms");
        JsonNode current = rooms.get(session.get("currentRoomId").asText());
        String neighborId = current.get("connectedRoomIds").get(0).asText();

        MvcResult result = mockMvc.perform(post("/api/session/" + sessionId + "/move")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("roomId", neighborId))))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        JsonNode updated = body.get("session");
        assertEquals(neighborId, updated.get("currentRoomId").asText());
        assertTrue(toStringList(updated.get("visitedRoomIds")).contains(neighborId));
    }

    @Test
    void entrarEmSalaComInimigoResolveCombateNaHora() throws Exception {
        long seed = findSeedWithNeighbor("ENEMY");
        JsonNode session = createSession(seed, "Dara", "NORMAL");
        String sessionId = session.get("id").asText();
        String enemyRoomId = firstNeighborOfType(session, "ENEMY");

        MvcResult result = mockMvc.perform(post("/api/session/" + sessionId + "/move")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("roomId", enemyRoomId))))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        JsonNode events = body.get("combatEvents");
        assertTrue(events != null && !events.isNull(), "Esperava combatEvents ao entrar numa sala com inimigo vivo");
        assertTrue(events.size() >= 2);
        assertEquals("DEATH", events.get(events.size() - 2).get("type").asText());
        assertEquals("COMBAT_END", events.get(events.size() - 1).get("type").asText());
    }

    @Test
    void derrotaEmHardcoreEncerraASessao() throws Exception {
        String sessionId = fightUntilHardcoreLoss();

        // Regressão: move() salvava a sessão de volta incondicionalmente depois do combate,
        // ressuscitando uma sessão que fight() já tinha removido (RF-44).
        mockMvc.perform(get("/api/session/" + sessionId)).andExpect(status().isNotFound());
    }

    @Test
    void coletarLootDaSalaAtualMoveItensParaOInventario() throws Exception {
        long seed = findSeedWithNeighbor("LOOT");
        JsonNode session = createSession(seed, "Elin", "NORMAL");
        String sessionId = session.get("id").asText();
        String lootRoomId = firstNeighborOfType(session, "LOOT");

        mockMvc.perform(post("/api/session/" + sessionId + "/move")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("roomId", lootRoomId))))
                .andExpect(status().isOk());

        MvcResult lootResult = mockMvc.perform(post("/api/session/" + sessionId + "/loot"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode afterLoot = objectMapper.readTree(lootResult.getResponse().getContentAsString());

        assertFalse(afterLoot.get("character").get("inventory").isEmpty(), "Esperava item coletado no inventário");
        assertTrue(afterLoot.get("dungeonMap").get("rooms").get(lootRoomId).get("items").isEmpty(),
                "Sala deveria ficar vazia após coletar");
    }

    @Test
    void equiparItemColetadoAtualizaEquippedERemoveDoInventario() throws Exception {
        JsonNode afterLoot = collectOneLootItem("Fara");
        JsonNode item = afterLoot.get("character").get("inventory").get(0);
        String sessionId = afterLoot.get("id").asText();
        String itemId = item.get("id").asText();
        String slot = ItemCatalog.categoryOf(item.get("baseType").asText()).compatibleSlots().get(0).name();

        MvcResult equipResult = mockMvc.perform(post("/api/session/" + sessionId + "/equip")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("itemId", itemId, "slot", slot))))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode afterEquip = objectMapper.readTree(equipResult.getResponse().getContentAsString());

        assertEquals(itemId, afterEquip.get("character").get("equipped").get(slot).get("id").asText());
        assertFalse(containsItemId(afterEquip.get("character").get("inventory"), itemId),
                "Item equipado não deveria continuar no inventário");
    }

    @Test
    void equiparEmSlotIncompativelDevolve400() throws Exception {
        JsonNode afterLoot = collectOneLootItem("Gwen");
        JsonNode item = afterLoot.get("character").get("inventory").get(0);
        String sessionId = afterLoot.get("id").asText();
        String itemId = item.get("id").asText();
        List<Slot> compatible = ItemCatalog.categoryOf(item.get("baseType").asText()).compatibleSlots();
        Slot incompatible = Arrays.stream(Slot.values()).filter(s -> !compatible.contains(s)).findFirst().orElseThrow();

        mockMvc.perform(post("/api/session/" + sessionId + "/equip")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("itemId", itemId, "slot", incompatible.name()))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void equiparItemInexistenteDevolve400() throws Exception {
        JsonNode session = createSession(30L, "Hale", "NORMAL");
        String sessionId = session.get("id").asText();

        mockMvc.perform(post("/api/session/" + sessionId + "/equip")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("itemId", "nao-existe", "slot", "HEAD"))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void desequiparDevolveItemAoInventario() throws Exception {
        JsonNode afterLoot = collectOneLootItem("Ivo");
        JsonNode item = afterLoot.get("character").get("inventory").get(0);
        String sessionId = afterLoot.get("id").asText();
        String itemId = item.get("id").asText();
        String slot = ItemCatalog.categoryOf(item.get("baseType").asText()).compatibleSlots().get(0).name();

        mockMvc.perform(post("/api/session/" + sessionId + "/equip")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("itemId", itemId, "slot", slot))))
                .andExpect(status().isOk());

        MvcResult unequipResult = mockMvc.perform(post("/api/session/" + sessionId + "/unequip")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("slot", slot))))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode afterUnequip = objectMapper.readTree(unequipResult.getResponse().getContentAsString());

        JsonNode equippedSlot = afterUnequip.get("character").get("equipped").get(slot);
        assertTrue(equippedSlot == null || equippedSlot.isMissingNode(), "Slot deveria ficar vazio após desequipar");
        assertTrue(containsItemId(afterUnequip.get("character").get("inventory"), itemId),
                "Item desequipado deveria voltar ao inventário");
    }

    @Test
    void desequiparSlotInvalidoDevolve400() throws Exception {
        JsonNode session = createSession(31L, "Joia", "NORMAL");
        String sessionId = session.get("id").asText();

        mockMvc.perform(post("/api/session/" + sessionId + "/unequip")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("slot", "NAO_EXISTE"))))
                .andExpect(status().isBadRequest());
    }

    /** Cria sessão, move até a primeira sala LOOT vizinha da entrada e coleta o item, devolvendo
     * a sessão resultante (com o item já no inventário). */
    private JsonNode collectOneLootItem(String name) throws Exception {
        long lootSeed = findSeedWithNeighbor("LOOT");
        JsonNode session = createSession(lootSeed, name, "NORMAL");
        String sessionId = session.get("id").asText();
        String lootRoomId = firstNeighborOfType(session, "LOOT");

        mockMvc.perform(post("/api/session/" + sessionId + "/move")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("roomId", lootRoomId))))
                .andExpect(status().isOk());

        MvcResult lootResult = mockMvc.perform(post("/api/session/" + sessionId + "/loot"))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(lootResult.getResponse().getContentAsString());
    }

    private boolean containsItemId(JsonNode inventory, String itemId) {
        for (JsonNode item : inventory) {
            if (item.get("id").asText().equals(itemId)) {
                return true;
            }
        }
        return false;
    }

    private JsonNode createSession(long seed, String name, String mode) throws Exception {
        String body = objectMapper.writeValueAsString(Map.of("name", name, "mode", mode, "seed", seed));
        MvcResult result = mockMvc.perform(post("/api/session")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    private String firstNeighborOfType(JsonNode session, String type) {
        JsonNode rooms = session.get("dungeonMap").get("rooms");
        JsonNode current = rooms.get(session.get("currentRoomId").asText());
        for (JsonNode neighborIdNode : current.get("connectedRoomIds")) {
            String neighborId = neighborIdNode.asText();
            if (rooms.get(neighborId).get("type").asText().equals(type)) {
                return neighborId;
            }
        }
        throw new IllegalStateException("Nenhum vizinho do tipo " + type);
    }

    /** Cria sessões HARDCORE com seeds sucessivas até uma derrota acontecer logo na entrada,
     * devolvendo o id dessa sessão (já removida pelo servidor, RF-44). */
    private String fightUntilHardcoreLoss() throws Exception {
        for (long seed = 1; seed <= 500; seed++) {
            JsonNode session = createSession(seed, "Busca", "HARDCORE");
            String sessionId = session.get("id").asText();
            JsonNode rooms = session.get("dungeonMap").get("rooms");
            JsonNode current = rooms.get(session.get("currentRoomId").asText());
            String enemyRoomId = null;
            for (JsonNode neighborIdNode : current.get("connectedRoomIds")) {
                if (rooms.get(neighborIdNode.asText()).get("type").asText().equals("ENEMY")) {
                    enemyRoomId = neighborIdNode.asText();
                    break;
                }
            }
            if (enemyRoomId == null) {
                continue;
            }

            MvcResult result = mockMvc.perform(post("/api/session/" + sessionId + "/move")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(Map.of("roomId", enemyRoomId))))
                    .andExpect(status().isOk())
                    .andReturn();
            JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
            int xpAfter = body.get("session").get("character").get("experience").asInt();
            if (xpAfter == 0) {
                return sessionId;
            }
        }
        fail("Nenhuma seed testada resultou em derrota logo na entrada");
        return null;
    }

    /** Procura uma seed cuja sala de entrada tenha um vizinho direto do tipo pedido, evitando
     * pathfinding multi-passo no teste (mantém o teste simples e robusto). */
    private long findSeedWithNeighbor(String type) throws Exception {
        for (long seed = 1; seed <= 500; seed++) {
            JsonNode session = createSession(seed, "Busca", "NORMAL");
            JsonNode rooms = session.get("dungeonMap").get("rooms");
            JsonNode current = rooms.get(session.get("currentRoomId").asText());
            for (JsonNode neighborIdNode : current.get("connectedRoomIds")) {
                if (rooms.get(neighborIdNode.asText()).get("type").asText().equals(type)) {
                    return seed;
                }
            }
        }
        fail("Nenhuma seed testada tinha vizinho do tipo " + type + " junto à entrada");
        return -1;
    }

    private List<String> toStringList(JsonNode arrayNode) {
        List<String> values = new ArrayList<>();
        arrayNode.forEach(node -> values.add(node.asText()));
        return values;
    }
}
