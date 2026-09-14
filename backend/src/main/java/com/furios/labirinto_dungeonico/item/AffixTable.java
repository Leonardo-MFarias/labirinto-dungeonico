package com.furios.labirinto_dungeonico.item;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.List;

/** Carrega {@code data/affixes.json} uma única vez na inicialização (RF-32). */
@Component
public class AffixTable {

    private final List<Affix> affixes;

    public AffixTable() {
        ObjectMapper mapper = new ObjectMapper();
        try (InputStream stream = getClass().getResourceAsStream("/data/affixes.json")) {
            affixes = mapper.readValue(stream, mapper.getTypeFactory()
                    .constructCollectionType(List.class, Affix.class));
        } catch (IOException e) {
            throw new UncheckedIOException("Falha ao carregar data/affixes.json", e);
        }
    }

    public List<Affix> all() {
        return affixes;
    }
}
