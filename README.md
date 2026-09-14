# Labirinto Dungeônico

Jogo *roguelike* de exploração de masmorras com geração procedural via **autômato celular**, combate automático baseado em velocidade (ATB) e itens com afixos aleatórios.

O projeto é dividido em dois módulos:

- **`backend/`** — Spring Boot (Java 21). É a autoridade das regras do jogo: gera a masmorra, resolve o combate e sorteia o loot. Nenhuma regra é calculada no cliente.
- **`app/`** — Flutter. Cuida de apresentação e entrada do jogador: mapa, ficha do personagem, inventário e log de combate em tempo real.

A comunicação entre os dois é HTTP/JSON para ações pontuais (mapa, personagem, inventário) e WebSocket para eventos de combate em tempo real.

## Documentação

Requisitos funcionais, não-funcionais, regras de negócio e o que já está implementado vs. planejado estão em [`docs/requisitos.md`](docs/requisitos.md).

## Estrutura

```
backend/
  src/main/java/com/furios/labirinto_dungeonico/
    api/          # controllers REST + handler WebSocket
    character/    # Character, Attributes, GameMode
    combat/       # CombatResolver (ATB), Enemy, CombatEvent
    dungeon/      # MapGenerator, DungeonMap, Room
    item/         # Item, Affix, LootGenerator, Rarity
    session/      # SessionService, GameSession
  src/main/resources/data/affixes.json

app/
  lib/
    core/models/    # modelos espelhando o backend (Character, Item, DungeonMap, ...)
    core/network/   # ApiClient (HTTP), CombatSocketClient (WebSocket)
    features/       # DungeonMapScreen, CombatScreen, InventoryScreen, CharacterScreen
```

## Rodando localmente

**Backend**

```
cd backend
./mvnw spring-boot:run
```

**App**

```
cd app
flutter pub get
flutter run
```

`ApiClient` e `CombatSocketClient` recebem a URL do backend por parâmetro (`app/lib/core/network/`); ainda não há uma tela ou configuração fixa para isso.

## Estado atual

Esqueleto inicial implementado (ver histórico de commits e §10 de `docs/requisitos.md` para o detalhamento do que está pronto vs. planejado). Não há persistência em banco de dados, autenticação nem multiplayer — fora de escopo nesta versão.
