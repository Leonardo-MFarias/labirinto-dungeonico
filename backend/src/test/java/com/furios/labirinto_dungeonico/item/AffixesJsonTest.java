package com.furios.labirinto_dungeonico.item;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.io.InputStream;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Guarda de regressão para PEND-01: data/affixes.json referenciava raridades (RARO, ÉPICO,
 * LENDÁRIO com acento) que não existem em Rarity, o que quebrava a desserialização.
 */
class AffixesJsonTest {

    @Test
    void affixesJsonDesserializaComRaridadesValidas() throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        try (InputStream stream = getClass().getResourceAsStream("/data/affixes.json")) {
            List<Affix> affixes = mapper.readValue(stream, mapper.getTypeFactory()
                    .constructCollectionType(List.class, Affix.class));

            assertEquals(8, affixes.size());
        }
    }
}
