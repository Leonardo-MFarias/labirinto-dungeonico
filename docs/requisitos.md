# Documento de Requisitos — Labirinto Dungeônico

| Campo | Valor |
|---|---|
| Projeto | Labirinto Dungeônico |
| Versão do documento | 2.8 |
| Data | 15/09/2026 |
| Status | Núcleo jogável de ponta a ponta (backend + app); equipamento e navegação global implementados (v2.3); combate usando equipamento (RN-26), balanceamento do andar 1 (RN-16) e ícone/cor por item (RF-58/RF-59) implementados a partir de feedback de playtesting (v2.5); avançar de andar pela sala EXIT (RF-19) implementado (v2.6); nivelamento e distribuição de pontos de atributo (RF-06/RF-07) implementados (v2.7); **persistência local de personagem por nome (RF-60 a RF-65, RN-30 a RN-32) levantada em v2.8 — ainda não implementada** |
| Autor | furiossam@hotmail.com |
| Baseado no commit | `3b87fa9` — *feat: esqueleto do backend Spring Boot e do app Flutter* |

---

## 1. Introdução

### 1.1 Propósito

Este documento especifica os requisitos funcionais e não-funcionais do **Labirinto Dungeônico**, um jogo *roguelike* de exploração de masmorras com geração procedural, combate automático baseado em velocidade e sistema de itens com afixos aleatórios.

O documento serve como referência para desenvolvimento, validação e rastreabilidade. Ele registra tanto o que já está implementado quanto o que está previsto, distinguindo explicitamente os dois estados (ver §10).

### 1.2 Escopo do produto

O Labirinto Dungeônico é um jogo **single-player com servidor autoritativo**:

- O **backend** (Spring Boot / Java 21) é a autoridade das regras: gera a masmorra, resolve o combate, sorteia o loot e mantém o estado da sessão. Nenhuma regra de jogo é calculada no cliente.
- O **aplicativo** (Flutter) é responsável por apresentação e entrada do jogador: renderiza o mapa, a ficha do personagem, o inventário e o log de combate em tempo real.

Um jogador controla **um personagem por sessão**. Não há autenticação, contas de usuário, ranking global nem interação entre jogadores nesta versão. Persistência em banco de dados e multiplayer são explicitamente **fora de escopo** (ver §11).

### 1.3 Definições, acrônimos e abreviações

| Termo | Definição |
|---|---|
| **Afixo** (*Affix*) | Modificador aplicado a um item, que altera atributos ou concede efeitos (ex.: "Flamejante" → +3 de dano de fogo). |
| **Andar / Profundidade** (*dungeon depth*) | Nível da masmorra. Influencia a força dos inimigos e a qualidade do loot. |
| **Autômato Celular** (*Cellular Automaton*) | Algoritmo de geração da masmorra: parte de uma grade `width` × `height` preenchida aleatoriamente (piso/parede) e a suaviza por sucessivas iterações segundo uma regra de vizinhança, produzindo cavernas orgânicas em vez de salas retangulares conectadas por corredores. |
| **ATB** (*Active Time Battle*) | Modelo de combate em que cada combatente age quando sua barra de tempo — preenchida em função do atributo `speed` — completa. |
| **Durabilidade** | Contador de uso de uma arma. Reduz a cada golpe desferido; ao chegar a zero, a arma fica quebrada até ser reparada. |
| **Hardcore** | Modo de jogo em que a morte do personagem é permanente. |
| **itemLevel** | Nível do item, derivado da profundidade em que foi gerado. Determina os afixos elegíveis. |
| **Loot** | Itens obtidos por exploração ou combate. |
| **Masmorra** (*Dungeon*) | Conjunto de salas conectadas gerado proceduralmente a partir de uma seed. |
| **Power score** | Valor único que resume o poder de um inimigo, calculado por soma ponderada de seus atributos efetivos e `maxHealth`. Usado para determinar o intervalo de respawn (RN-22). |
| **RF / RNF / RN** | Requisito Funcional / Requisito Não-Funcional / Regra de Negócio. |
| **Roguelike** | Gênero caracterizado por geração procedural, morte permanente e progressão por run. |
| **Run** | Uma tentativa completa de exploração, do início até a morte ou conclusão. |
| **Sala** (*Room*) | Célula atômica da grade do mapa, com coordenadas `x`/`y`. Possui um tipo, conexões, itens e possivelmente um inimigo. Toda célula da grade tem uma sala correspondente, inclusive as intransponíveis (tipo `WALL`). |
| **Seed** | Semente numérica do gerador pseudoaleatório. Determina a masmorra gerada. |
| **Slot** | Posição de equipamento do personagem (ex.: arma, elmo, peitoral). |

### 1.4 Referências

- Código-fonte do backend: `backend/src/main/java/com/furios/labirinto_dungeonico/`
- Código-fonte do app: `app/lib/`
- Tabela de afixos: `backend/src/main/resources/data/affixes.json`

### 1.5 Convenções de prioridade

| Prioridade | Significado |
|---|---|
| **Essencial** | Sem este requisito o produto não entrega valor. Obrigatório no MVP. |
| **Importante** | Agrega valor significativo; pode ficar para a versão seguinte ao MVP. |
| **Desejável** | Melhoria incremental. Implementar se houver folga. |

---

## 2. Descrição geral

### 2.1 Perspectiva do produto

```
┌──────────────────────────┐        HTTP/JSON          ┌──────────────────────────────┐
│      App Flutter         │ ────────────────────────> │   Backend Spring Boot        │
│  (apresentação/entrada)  │ <──────────────────────── │   (autoridade das regras)    │
│                          │                           │                              │
│  • DungeonMapScreen      │        WebSocket          │  • MapGenerator     (RNG)    │
│  • CombatScreen          │ <═══════════════════════> │  • CombatResolver   (ATB)    │
│  • InventoryScreen       │   eventos de combate      │  • LootGenerator    (RNG)    │
│  • CharacterScreen       │                           │  • SessionService (memória)  │
└──────────────────────────┘                           └──────────────────────────────┘
                                                                     │
                                                                     ▼
                                                            data/affixes.json
```

O estado do jogo vive **exclusivamente no servidor** (`SessionService`, atualmente em memória). O cliente mantém apenas uma cópia de leitura para renderização.

### 2.2 Atores

| Ator | Descrição |
|---|---|
| **Jogador** | Usuário final. Cria o personagem, explora a masmorra, combate e gerencia o inventário. Único ator humano. |
| **Sistema de Geração Procedural** | Ator de sistema. Produz masmorras e itens a partir de seeds. |
| **Resolvedor de Combate** | Ator de sistema. Simula os ticks de combate e emite os eventos resultantes. |

### 2.3 Funções principais

1. Criação e progressão de personagem.
2. Geração procedural de masmorras.
3. Navegação e exploração de salas.
4. Combate automático por velocidade, transmitido em tempo real.
5. Geração, coleta e gerenciamento de itens com afixos.

### 2.4 Premissas e restrições

| ID | Descrição |
|---|---|
| PR-01 | O backend executa em Java 21 com Spring Boot 4.1.1 (Maven). |
| PR-02 | O app é desenvolvido em Flutter com Dart SDK `^3.12.2`. |
| PR-03 | A comunicação usa HTTP para operações de estado e WebSocket (`/ws/combat`) para o fluxo de eventos de combate. |
| PR-04 | Serialização em JSON via Jackson (backend) e `dart:convert` (app). |
| PR-05 | O jogo é single-player. Não há requisito de concorrência entre jogadores em uma mesma masmorra. |
| PR-06 | **Superada em v2.8 (RN-31)**: como todo personagem tem nome obrigatório (RF-01) e toda sessão passa a ser salva automaticamente por nome (RF-60), o estado deixa de ser volátil de forma geral — reiniciar o backend não descarta mais nenhuma sessão em andamento, desde que a gravação em disco já tenha ocorrido (sem janela de perda entre a mutação e a gravação, RF-60). |
| PR-07 | O aplicativo depende de conectividade com o backend. Não há modo offline. |
| PR-08 | Sem coleta de dados pessoais nesta versão — não há tratamento aplicável de LGPD. |

### 2.5 Dependências externas

| Dependência | Uso |
|---|---|
| `spring-boot-starter-webmvc` | Camada REST. |
| `spring-boot-starter-websocket` | Canal de eventos de combate. |
| `jackson-databind` / `-core` / `-annotations` | Serialização JSON (declaradas explicitamente no `pom.xml`). |
| `http` (Dart) | Cliente REST do app. |
| `web_socket_channel` (Dart) | Cliente WebSocket do app. |

---

## 3. Requisitos Funcionais

### 3.1 Módulo Personagem

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-01** | O sistema deve permitir criar um personagem informando nome e modo de jogo, gerando um identificador único. **A partir de v2.8 (RN-30)**: o nome passa a ser o identificador do save — criar com um nome já salvo não deve simplesmente criar um segundo personagem homônimo; deve seguir o fluxo de RF-65 (continuar/nova jornada mantendo progresso/nova jornada do zero). | Essencial | Implementado de ponta a ponta (`POST /api/session`; diálogo "Nova run" em `HomeScreen`) — **ainda não reflete RN-30**: hoje aceita nomes repetidos livremente, criando personagens distintos com o mesmo nome (RF-60 a RF-65 pendentes) |
| **RF-02** | O sistema deve permitir ao jogador escolher o modo de jogo (`NORMAL` ou `HARDCORE`) no momento da criação. | Essencial | Implementado de ponta a ponta (`GameMode` no corpo de `POST /api/session`; seletor no diálogo "Nova run") |
| **RF-03** | O sistema deve atribuir ao personagem os seis atributos base: força, agilidade, vitalidade, velocidade, defesa e inteligência. | Essencial | Implementado (todos = 5 na criação — ver §4.1, valor de balanceamento assumido) |
| **RF-04** | O sistema deve permitir consultar a ficha do personagem (nome, nível, experiência, atributos, modo e equipamentos). | Essencial | Implementado (`GET /api/session/{id}/character`) |
| **RF-05** | O sistema deve acumular experiência ao término de combates vencidos. | Essencial | Implementado (`Character.gainExperience`, curva de nível — RN-28 — a partir de v2.7) |
| **RF-06** | O sistema deve elevar o nível do personagem quando a experiência atingir o limiar da curva de progressão. | Essencial | Implementado (v2.7): `Character.gainExperience` sobe de nível em loop enquanto o saldo atingir `xpToNextLevel()` (RN-28), suportando subir mais de um nível de uma vez num ganho grande de XP. |
| **RF-07** | O sistema deve conceder pontos de atributo a cada nível e permitir que o jogador os distribua. | Importante | Implementado de ponta a ponta (v2.7): cada level up concede pontos (RN-29); `POST /api/session/{id}/character/attributes` (`Character.allocateAttributePoint`) distribui um ponto num dos seis atributos, 400 (`InvalidAttributeAllocationException`) se não houver saldo ou o atributo for inválido; `CharacterScreen` mostra o saldo e um botão "+" por atributo. |
| **RF-08** | O sistema deve calcular os **atributos efetivos** do personagem somando os atributos base aos modificadores dos itens equipados. | Essencial | Implementado (`Character.effectiveAttributes()`: soma, sobre os atributos base, os modificadores de afixos dos itens equipados cuja chave bate com um campo de `Attributes` — `damage`/`durability`/etc. são ignorados por não serem atributos; campo novo e paralelo a `attributes` no JSON). Desde v2.4 (RN-26), o combate também consulta este valor para o jogador — deixou de ser só um número exibido na ficha. |
| **RF-09** | O aplicativo deve exibir a ficha de atributos e a progressão do personagem. | Essencial | Implementado (`CharacterScreen`: nome, modo, nível, XP, barra de vida, os seis atributos base **e** efetivos lado a lado — RF-08 —, saldo de pontos de atributo e botão "+" por atributo quando há saldo — RF-07, v2.7). |

### 3.2 Módulo Masmorra

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-10** | O sistema deve gerar uma masmorra proceduralmente a partir de uma seed numérica e das dimensões `width` × `height` da grade, usando um autômato celular (preenchimento aleatório ponderado seguido de iterações de suavização) para decidir quais células são andáveis. A quantidade final de salas andáveis é uma consequência emergente do algoritmo, não um parâmetro de entrada. | Essencial | Implementado (`RandomMapGenerator`: preenchimento + suavização + flood fill; parâmetros em §12, Q-06) |
| **RF-11** | O sistema deve produzir masmorras idênticas para a mesma seed e as mesmas dimensões de grade (determinismo). | Essencial | Implementado (testado em `RandomMapGeneratorTest`) |
| **RF-12** | O sistema deve isolar, após a suavização, a maior região andável conectada da grade (*flood fill*) e garantir que exista ao menos um caminho da entrada (`ENTRANCE`) até a saída (`EXIT`) dentro dela; células fora dessa região tornam-se `WALL`. | Essencial | Implementado (testado em `RandomMapGeneratorTest`) |
| **RF-13** | O sistema deve classificar cada célula da grade em um dos tipos: `ENTRANCE`, `EMPTY`, `LOOT`, `ENEMY`, `EXIT` (andáveis) ou `WALL` (intransponível, resultado do autômato celular). | Essencial | Implementado (tipo definido na geração; conteúdo de `LOOT`/`ENEMY` populado por `DungeonPopulator` — RF-14/RF-15 — apenas para masmorras criadas via `POST /api/session`, não pelo endpoint cru `/api/dungeon/generate`) |
| **RF-14** | O sistema deve povoar salas do tipo `ENEMY` com um inimigo cuja força escale com a profundidade da masmorra. | Essencial | Implementado (`DungeonPopulator` + `EnemyFactory`, RN-16) |
| **RF-15** | O sistema deve povoar salas do tipo `LOOT` com um ou mais itens gerados pelo módulo de loot. | Essencial | Implementado (`DungeonPopulator`, um item por sala `LOOT`, via `RandomLootGenerator`) |
| **RF-16** | O sistema deve permitir ao jogador mover-se de uma sala para outra **somente** se houver conexão direta entre elas. | Essencial | Implementado de ponta a ponta: backend valida (`POST /api/session/{id}/move`, 400 se inválido, RN-15) e `DungeonMapScreen` só permite tocar em salas conectadas, chamando a sessão real via `GameController`. |
| **RF-17** | O sistema deve registrar quais salas já foram visitadas na sessão. | Importante | Implementado de ponta a ponta (`GameSession.visitedRoomIds()` no backend, refletido direto na UI — sem estado local duplicado no app). |
| **RF-18** | O aplicativo deve exibir o mapa da masmorra em grade `width` × `height` (usando `Room.x`/`Room.y`), com as células `WALL` sempre visíveis como contorno, destacando a sala atual, as visitadas e as adjacentes não exploradas (*fog of war* apenas sobre o conteúdo — item/inimigo — das salas andáveis ainda não visitadas). | Essencial | Implementado (`DungeonMapScreen`: busca o mapa do backend, grade colorida com legenda, sala atual/visitadas/adjacentes destacadas, fog of war sobre LOOT/ENEMY não visitados) |
| **RF-19** | O sistema deve permitir avançar para um novo andar ao alcançar a sala `EXIT`, gerando uma nova masmorra com profundidade incrementada. | Importante | Implementado de ponta a ponta (v2.6): `POST /api/session/{id}/descend` (`SessionController.descend`) exige que o personagem esteja na sala `EXIT` (400 via `InvalidDescendException` caso contrário), gera e povoa a masmorra do novo andar com uma seed derivada da seed atual e da nova profundidade (determinismo, RN-12, sem depender de seed vinda do cliente) e reposiciona o personagem na entrada via `GameSession.descendTo` — que também **limpa `visitedRoomIds`**, já que os ids de sala são posicionais (`"x,y"`) e se repetem entre andares. Ação explícita do jogador (botão "Descer" em `DungeonMapScreen`, só visível na sala EXIT), não automática ao entrar na sala — mesmo padrão de RF-35 (loot). Vida e inventário são preservados entre andares (não fazem parte de `descendTo`). Verificado manualmente no Chrome: personagem foi da profundidade 1 até a sala EXIT (6 combates no caminho), clicou em "Descer" e avançou para a profundidade 2 com vida preservada (26/45) e mapa totalmente novo. |

### 3.3 Módulo Combate

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-20** | O sistema deve iniciar um combate automaticamente quando o personagem entrar em uma sala do tipo `ENEMY` que ainda contenha um inimigo vivo. | Essencial | Implementado — mas via HTTP, não WebSocket (ver nota abaixo): `POST /api/session/{id}/move` detecta o inimigo vivo na sala destino e resolve o combate na mesma requisição. |
| **RF-21** | O sistema deve resolver o combate em ticks, concedendo a ação ao combatente conforme o atributo `speed` de cada lado (modelo ATB). | Essencial | Implementado (`SpeedBasedCombatResolver`: gauge por `speed`, ação a cada 100 de gauge, empate → jogador primeiro, RN-05) |
| **RF-22** | O sistema deve calcular, a cada ação, se ela resulta em acerto normal, acerto crítico ou erro. | Essencial | Implementado (chance de erro e de crítico por agilidade — valores assumidos, ver §4.1) |
| **RF-23** | O sistema deve produzir um evento de combate (`CombatEvent`) para cada ação, contendo tipo, ator, alvo, valor e timestamp. | Essencial | Implementado |
| **RF-24** | O sistema deve transmitir os eventos de combate ao aplicativo pelo WebSocket `/ws/combat`, na ordem em que ocorrem. | Essencial | **Não implementado** (`CombatSocketHandler` continua stub). Nesta versão o combate é resolvido de forma síncrona dentro de `POST /move`, que devolve a lista completa de `CombatEvent` na resposta (ver PEND-13) — migrar para streaming via WS fica como trabalho futuro. |
| **RF-25** | O sistema deve encerrar o combate quando um dos combatentes atingir vida zero, emitindo `DEATH` seguido de `COMBAT_END`. | Essencial | Implementado |
| **RF-26** | O sistema deve conceder experiência e loot ao jogador após uma vitória. | Essencial | Implementado (fórmulas de XP e chance de drop assumidas, ver §4.1) |
| **RF-27** | O sistema deve aplicar a consequência da derrota conforme o modo de jogo (ver RN-01 e RN-02). | Essencial | Implementado (HARDCORE encerra a sessão; NORMAL volta à entrada com vida cheia e penalidade de XP) |
| **RF-28** | O aplicativo deve exibir o log de combate em tempo real, com rolagem automática e destaque visual por tipo de evento. | Essencial | Implementado, mas simulado no cliente: como o backend devolve todos os eventos de uma vez (PEND-13), `CombatScreen` os revela um a um (~350ms cada, com scroll automático e cor+ícone por tipo) em vez de receber via WebSocket de verdade. |
| **RF-29** | O aplicativo deve exibir as barras de vida do personagem e do inimigo, atualizadas a cada evento recebido. | Importante | Implementado (`CombatScreen`: barras animadas conforme os eventos são revelados) |

### 3.4 Módulo Itens e Loot

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-30** | O sistema deve gerar itens com tipo base, `itemLevel`, raridade, atributos base e lista de afixos. | Essencial | Implementado (`RandomLootGenerator`). `baseStats` continua sempre vazio — não há catálogo de tipos base com atributos intrínsecos ainda, só uma lista fixa provisória de nomes em `DungeonPopulator.ITEM_BASE_TYPES`. |
| **RF-31** | O sistema deve sortear a raridade do item de forma ponderada pela profundidade da masmorra. | Essencial | Implementado (fórmula de pesos assumida, ver §4.1) |
| **RF-32** | O sistema deve carregar a tabela de afixos a partir de `data/affixes.json` na inicialização. | Essencial | Implementado (`AffixTable`, `@Component` carregado no startup) |
| **RF-33** | O sistema deve sortear apenas afixos elegíveis, respeitando `minItemLevel` e `minRarity` (ver RN-08). | Essencial | Implementado |
| **RF-34** | O sistema deve determinar a quantidade de afixos do item conforme sua raridade (ver RN-09). | Essencial | Implementado (tabela assumida, ver §4.1) |
| **RF-35** | O sistema deve permitir ao jogador coletar itens presentes na sala atual, movendo-os para o inventário. | Essencial | Implementado de ponta a ponta (`POST /api/session/{id}/loot`; botão "Coletar" em `InventoryScreen` quando a sala atual tem itens) |
| **RF-36** | O sistema deve permitir consultar o inventário do personagem. | Essencial | Implementado de ponta a ponta (`InventoryScreen` lista `character.inventory`) |
| **RF-37** | O sistema deve permitir equipar um item em um dos oito slots do personagem — `HEAD`, `CHEST`, `LEGS`, `FEET`, `HAND_LEFT`, `HAND_RIGHT`, `ACCESSORY_1`, `ACCESSORY_2` (RN-23) —, substituindo o item anteriormente equipado nesse slot, que retorna ao inventário. Um item só pode ser equipado em slot(s) compatíveis com sua categoria de equipamento (RN-24); armas e escudos podem ir em qualquer uma das duas mãos, em qualquer combinação (RN-25). | Essencial | Implementado de ponta a ponta (`POST /api/session/{id}/equip`, `Character.equip`, enum `Slot`, `EquipmentCategory`/`ItemCatalog`; UI de arraste em `CharacterScreen`/`EquipmentSlots`, RF-56) |
| **RF-38** | O sistema deve permitir desequipar um item de um slot específico, devolvendo-o ao inventário e deixando o slot vazio. | Essencial | Implementado de ponta a ponta (`POST /api/session/{id}/unequip`, `Character.unequip`; toque no item equipado em `EquipmentSlots`) |
| **RF-39** | O sistema deve permitir descartar um item do inventário de forma irreversível. | Desejável | Não implementado |
| **RF-40** | O aplicativo deve listar os itens do inventário com nome, raridade (diferenciada por cor) e afixos. | Essencial | Implementado (`InventoryScreen`: tipo base, raridade por cor + rótulo textual — RNF-09 —, e nomes dos afixos quando houver) |
| **RF-41** | O aplicativo deve comparar o item selecionado com o item atualmente equipado no mesmo slot, indicando ganho ou perda por atributo. | Desejável | Implementado (toque longo num item do inventário em `CharacterScreen` abre diálogo comparando os modificadores de atributo do item com o(s) equipado(s) no(s) slot(s) compatível(is)) |
| **RF-58** | O aplicativo deve exibir um ícone específico por categoria de equipamento (RN-24: `WEAPON`, `SHIELD`, `HEAD_ARMOR`, `CHEST_ARMOR`, `LEG_ARMOR`, `FOOT_ARMOR`, `ACCESSORY`) em vez de só o nome em texto, tanto na lista do inventário (`InventoryScreen`) quanto nos slots de equipamento (`EquipmentSlots`). | Desejável | Implementado (`core/models/equipment_category.dart`: `iconForBaseType`, ícones do Material Design confirmados no `icons.dart` do SDK antes do uso — Q-09 resolvida). Ícone em cor neutra, não tingido pela cor de raridade (raridades claras como Normal ficavam praticamente invisíveis tingidas — achado em teste manual). |
| **RF-59** | O aplicativo deve exibir um selo/contorno colorido indicando o(s) tipo(s) de afixo do item (RN-27), além da cor de raridade já existente (RNF-09) — as duas cores não podem se sobrepor/confundir. | Desejável | Implementado (`core/models/affix_colors.dart`: `primaryAffixColor`, selo circular com contorno sutil para não sumir quando a cor for clara; aparece na lista do inventário, no chip arrastável e nos slots de equipamento — resolve Q-08 a favor de "em todo lugar que mostra o item"). |

### 3.5 Módulo Sessão

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-42** | O sistema deve criar uma sessão de jogo associando um personagem a uma masmorra, com identificador único. | Essencial | Implementado (`POST /api/session`) |
| **RF-43** | O sistema deve permitir recuperar o estado completo de uma sessão pelo seu identificador. | Essencial | Implementado (`GET /api/session/{id}`) |
| **RF-44** | O sistema deve encerrar a sessão quando o personagem morrer em modo `HARDCORE`. | Essencial | Implementado de ponta a ponta (`SessionService.remove`; app mostra "Run encerrada" e volta ao diálogo de nova run — `GameController.isHardcoreDeath`) |
| **RF-45** | O sistema deve expor um endpoint de verificação de saúde da aplicação. | Importante | Implementado (`/api/health`) |
| **RF-46** | O aplicativo deve permitir configurar o endereço base do backend (host e porta). | Importante | Parcial (`ApiClient.baseUrl`) |

### 3.6 Módulo Durabilidade de Armas

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-47** | O sistema deve atribuir durabilidade máxima e durabilidade atual a todo item cujo `baseType` seja uma arma. | Essencial | Não implementado |
| **RF-48** | O sistema deve reduzir a durabilidade atual da arma equipada a cada ataque bem-sucedido (`ATTACK` ou `CRITICAL_HIT`) desferido pelo personagem em combate. | Essencial | Não implementado |
| **RF-49** | O sistema deve impedir que a durabilidade de uma arma fique negativa, travando-a em zero. | Essencial | Não implementado |
| **RF-50** | Ao atingir durabilidade zero, o sistema deve marcar a arma como quebrada, deixando de aplicar seus afixos e bônus de dano no cálculo do combate (ver RN-20), sem desequipá-la automaticamente. | Essencial | Não implementado |
| **RF-51** | O sistema deve permitir reparar uma arma (equipada ou no inventário), restaurando sua durabilidade ao valor máximo. | Importante | Não implementado |
| **RF-52** | O aplicativo deve exibir a durabilidade atual/máxima da arma equipada na ficha do personagem e no inventário (ex.: "42/60"). | Essencial | Não implementado |
| **RF-53** | O aplicativo deve alertar visualmente quando a durabilidade da arma equipada estiver crítica (abaixo de 20%) e quando estiver quebrada. | Importante | Não implementado |

### 3.7 Módulo Respawn de Inimigos

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-54** | O sistema deve permitir que uma sala do tipo `ENEMY` cujo inimigo foi derrotado volte a conter um inimigo vivo (*respawn*), após decorrido o intervalo de tempo configurável definido em RN-22. | Importante | Não implementado |
| **RF-55** | O sistema deve escalar a força do inimigo gerado por respawn com a profundidade atual da masmorra, seguindo a mesma regra de escalonamento de RF-14 (RN-16). | Importante | Não implementado |

### 3.8 Módulo Equipamento e Navegação (v2.2)

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-56** | O aplicativo deve permitir equipar um item arrastando-o do inventário até o slot compatível na ficha do personagem (*drag-and-drop*), destacando visualmente os slots compatíveis durante o arraste e recusando o *drop* em slots incompatíveis com a categoria do item (RN-24). | Essencial | Implementado (`CharacterScreen`: painel de inventário arrastável + `EquipmentSlots` com os oito `DragTarget`; destaque verde/vermelho via `compatibleSlots` — tabela client-side só para UX, RN-13 mantém o servidor como validação real) |
| **RF-57** | O aplicativo deve permitir navegar entre as telas de Mapa, Combate, Inventário e Personagem a partir de qualquer uma delas (navegação global), sem precisar voltar à tela inicial a cada troca. | Importante | Implementado (`GameShell`: `NavigationBar` + `IndexedStack` com as quatro telas vivas simultaneamente, compartilhando o mesmo `GameController`; `HomeScreen` agora abre o shell em vez de cada tela isolada) |

### 3.9 Módulo Persistência Local (v2.8)

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-60** | O sistema deve persistir automaticamente a sessão ativa (personagem, masmorra, sala atual, andar e salas visitadas) em armazenamento local no backend, associado ao nome do personagem, a cada mutação relevante de estado (mover, combater, coletar, equipar/desequipar, distribuir atributo, descer de andar). | Essencial | Não implementado |
| **RF-61** | O sistema deve permitir consultar, a partir de um nome de personagem, se existe um save associado a ele. | Essencial | Não implementado |
| **RF-62** | O sistema deve permitir retomar uma jornada salva a partir do nome do personagem, restaurando o estado completo (RF-60) exatamente como estava no momento do último salvamento. | Essencial | Não implementado |
| **RF-63** | O sistema deve permitir iniciar uma nova jornada reaproveitando o nome e a progressão (nível, experiência, atributos, inventário, equipamento) de um personagem já salvo, gerando uma masmorra nova a partir da profundidade 1 e substituindo o save anterior por essa nova jornada. | Importante | Não implementado |
| **RF-64** | O sistema deve apagar o save associado a um personagem quando ele morrer em modo `HARDCORE` (RN-01), consistente com a permanência da morte — o nome volta a ficar disponível para uma nova criação do zero. | Essencial | Não implementado |
| **RF-65** | O aplicativo deve, ao criar uma nova run com um nome que já possui save (RF-61), oferecer ao jogador a escolha entre **continuar** a jornada salva (RF-62), iniciar **nova jornada mantendo o progresso** (RF-63) ou iniciar **nova jornada do zero** (substitui o save, mesmo comportamento de criação atual), em vez de seguir direto para a criação. | Essencial | Não implementado |

---

## 4. Regras de Negócio

| ID | Regra |
|---|---|
| **RN-01** | **Morte em modo HARDCORE**: ao chegar a zero de vida, o personagem é permanentemente perdido e a sessão é destruída. Não há continuação. |
| **RN-02** | **Morte em modo NORMAL**: ao chegar a zero de vida, o personagem retorna à sala de entrada do andar atual, com penalidade de experiência. O inventário é preservado. |
| **RN-03** | **Modo imutável**: o modo de jogo é definido na criação do personagem e não pode ser alterado depois. |
| **RN-04** | **Ordem de raridade**: a escala crescente de qualidade é `OBSOLETO < ARCAICO < TRIVIAL < NORMAL < COMUM < INCOMUM < LENDARIO < MITICO < DIVINO < ASTRAL`. Comparações de raridade seguem a ordem de declaração do enum. |
| **RN-05** | **Iniciativa**: a ordem de ação no combate é determinada pelo atributo `speed`. Quanto maior o `speed`, mais frequentes as ações do combatente. Em empate de tick, o jogador age primeiro. |
| **RN-06** | **Cálculo de dano**: o dano de um golpe é função do atributo `strength` do atacante reduzido pelo `defense` do alvo, com piso mínimo de 1 ponto de dano. |
| **RN-07** | **Acerto crítico**: a chance de crítico deriva do atributo `agility` do atacante. Um crítico aplica multiplicador sobre o dano-base e gera evento do tipo `CRITICAL_HIT`. |
| **RN-08** | **Elegibilidade de afixo**: um afixo só pode ser aplicado a um item se `item.itemLevel >= afixo.minItemLevel` **e** `item.rarity >= afixo.minRarity` na ordem definida por RN-04. |
| **RN-09** | **Quantidade de afixos**: a quantidade de afixos sorteados é limitada pela raridade do item — raridades mais altas comportam mais afixos. Um mesmo afixo não pode ser aplicado duas vezes ao mesmo item. |
| **RN-10** | **itemLevel**: o `itemLevel` de um item gerado é igual à profundidade (andar) da masmorra em que foi gerado. |
| **RN-11** | **Vida máxima**: a vida máxima do personagem é função do atributo `vitality` e do nível. |
| **RN-12** | **Determinismo da seed**: a mesma seed, com os mesmos parâmetros de geração, deve produzir exatamente a mesma masmorra e as mesmas sequências de loot. |
| **RN-13** | **Autoridade do servidor**: nenhuma regra de jogo — geração, dano, sorteio de loot, progressão — é calculada no cliente. O aplicativo apenas apresenta o estado recebido. |
| **RN-14** | **Um personagem por sessão**: cada `GameSession` referencia exatamente um `Character` e uma `DungeonMap`. |
| **RN-15** | **Conectividade de sala**: o movimento entre salas só é válido se o identificador da sala de destino constar em `connectedRoomIds` da sala de origem. |
| **RN-16** | **Escalonamento por profundidade**: a força dos inimigos e a probabilidade de raridades altas crescem monotonicamente com a profundidade. **Revisão v2.4** (a pedido do usuário, após playtesting mostrar ~35–40% de vitória já no andar 1 — ver nota em §4.1): o inimigo do andar 1 nasce **mais fraco** que um personagem recém-criado, não empatado com ele; a força do inimigo só alcança a do personagem base no andar 5 ("andar de equilíbrio"), e cresce além dele nos andares seguintes como antes (fórmula em §4.1, implementada em `EnemyFactory`). |
| **RN-17** | **Escopo da durabilidade**: apenas itens de categoria "arma" possuem durabilidade nesta versão. Armaduras e acessórios não são afetados. |
| **RN-18** | **Consumo de durabilidade**: cada ataque bem-sucedido (`ATTACK` ou `CRITICAL_HIT`) desferido com a arma equipada reduz sua durabilidade atual em 1 ponto. Golpes que resultam em `MISS` não consomem durabilidade. |
| **RN-19** | **Durabilidade máxima**: o valor máximo de durabilidade é definido pelo `baseType` da arma e pode ser alterado por afixos (ex.: o afixo "Frágil" já presente em `affixes.json` reduz a durabilidade máxima). |
| **RN-20** | **Arma quebrada**: uma arma com durabilidade zero é tratada como quebrada — o dano do golpe passa a usar apenas o piso mínimo definido por RN-06 (equivalente a lutar desarmado), e seus afixos deixam de contribuir para os atributos efetivos (RF-08), até reparo (RN-21) ou substituição do equipamento. |
| **RN-21** | **Reparo**: reparar uma arma restaura sua durabilidade ao valor máximo instantaneamente. *(O custo ou mecanismo de reparo — moeda, material coletável ou reparo gratuito ao retornar à entrada — ainda não está definido; ver §12, Q-01.)* |
| **RN-22** | **Respawn de inimigo (por tempo, escalado por power score)**: um inimigo derrotado reaparece na sala somente após decorrer, no relógio do servidor, um intervalo de tempo desde o momento da derrota. O poder do inimigo que será gerado é expresso por um **power score** — soma ponderada dos seis atributos efetivos do `Enemy` (`strength`, `agility`, `vitality`, `speed`, `defense`, `intelligence`) e de `maxHealth`. O intervalo cresce monotonicamente com o power score: `intervaloRespawn = clamp(intervaloBase + powerScore × fatorEscala, mínimo, máximo)`. Os pesos de cada atributo, `intervaloBase`, `fatorEscala` e os limites mínimo/máximo residem em `data/respawn.json` (mesma convenção de `data/affixes.json`), como parâmetro de balanceamento (RNF-16), não codificado no fonte. O intervalo é contado a partir de `Room.enemyDefeatedAt`; a checagem é feita no momento em que o jogador entra na sala (RF-16), sem processo em segundo plano. Por depender apenas do relógio do servidor (nunca de tempo informado pelo cliente), a regra preserva a autoridade do servidor (RN-13); por não fazer parte da geração da masmorra, não é abrangida pelo determinismo de seed de RN-12. |
| **RN-23** | **Slots de equipamento (v2.2)**: o personagem possui exatamente oito slots: `HEAD`, `CHEST`, `LEGS`, `FEET`, `HAND_LEFT`, `HAND_RIGHT`, `ACCESSORY_1`, `ACCESSORY_2`. Cada slot guarda no máximo um item. |
| **RN-24** | **Categoria de equipamento e compatibilidade de slot (v2.2)**: todo item equipável pertence a exatamente uma categoria — `WEAPON`, `SHIELD`, `HEAD_ARMOR`, `CHEST_ARMOR`, `LEG_ARMOR`, `FOOT_ARMOR` ou `ACCESSORY` —, determinada pelo `baseType`. Um item só pode ser equipado em slot(s) compatíveis com sua categoria: `HEAD_ARMOR`→`HEAD`; `CHEST_ARMOR`→`CHEST`; `LEG_ARMOR`→`LEGS`; `FOOT_ARMOR`→`FEET`; `ACCESSORY`→`ACCESSORY_1` ou `ACCESSORY_2`; `WEAPON`/`SHIELD`→`HAND_LEFT` ou `HAND_RIGHT`. *(O catálogo atual de `baseType` — espada, machado, elmo, peitoral, anel, bota, ver `DungeonPopulator.ITEM_BASE_TYPES` — não tem nenhum tipo `LEG_ARMOR` nem `SHIELD`; precisa ganhar ao menos um de cada para os slots `LEGS` e a opção de escudo nas mãos serem alcançáveis por loot.)* |
| **RN-25** | **Combinação das mãos (v2.2)**: `HAND_LEFT` e `HAND_RIGHT` aceitam `WEAPON` ou `SHIELD` de forma independente uma da outra — qualquer combinação é válida: arma + escudo, arma + arma (duas armas) ou escudo + escudo (dois escudos). |
| **RN-26** | **Atributos efetivos no combate (v2.4)**: o resolvedor de combate usa os **atributos efetivos** do personagem (RF-08 — base + modificadores dos itens equipados), não os atributos base, para toda a resolução do combate (dano e seu piso mínimo — RN-06 —, chance de crítico — RN-07 —, velocidade de ação no ATB — RN-05). Resolve a Q-07: por ora, empunhar duas armas (RN-25) só acumula os bônus de atributo de ambas via atributos efetivos — **não** concede uma ação de ataque extra por tick; essa mecânica fica fora de escopo desta regra. O inimigo não é afetado (não possui itens equipados nesta versão). Implementado em `SpeedBasedCombatResolver` (calcula `player.effectiveAttributes()` uma vez no início da resolução). |
| **RN-27** | **Cor por tipo de afixo (v2.4)**: cada tipo de modificador de afixo tem uma cor temática fixa, exibida num selo/contorno separado da cor de raridade (RNF-09) — nunca substituindo-a: `damage`→vermelho, `durability`→marrom, `fireDamage`→laranja, `speed`→ciano, `defense`→azul-aço, `magicPower`→roxo, `holyDamage`→dourado, `darkDamage`→roxo-escuro. Um item com afixos de mais de um tipo mostra o selo do afixo mais relevante, por uma ordem de prioridade fixa (elementais/raros primeiro — `holyDamage`, `darkDamage`, `fireDamage`, `magicPower` —, atributos genéricos depois). Implementado em `core/models/affix_colors.dart` (`primaryAffixColor`). |
| **RN-28** | **Curva de experiência e level up (v2.7)**: a XP necessária para ir do nível L ao L+1 é `100 × L` (fórmula assumida, ver §4.1). Ao acumular XP suficiente, o personagem sobe de nível — um ganho grande de XP pode subir mais de um nível numa só chamada (loop em `Character.gainExperience`). Cada level up soma ao HP atual o mesmo ganho de HP máximo daquele nível (10, RN-11) — **não** é um heal completo: dano sofrido antes do level up continua refletido. (Um heal completo foi cogitado e descartado nesta versão — tornaria HARDCORE artificialmente seguro em baixa profundidade, bastando continuar subindo de nível para nunca acumular dano.) |
| **RN-29** | **Pontos de atributo por nível (v2.7)**: cada level up concede 3 pontos de atributo (fórmula assumida, ver §4.1), acumulados em `Character.unspentAttributePoints` até serem distribuídos um de cada vez, em qualquer um dos seis atributos, via `POST /api/session/{id}/character/attributes`. Não há limite de pontos em um único atributo nem forma de desfazer uma distribuição nesta versão. |
| **RN-30** | **Nome como identificador do save (v2.8)**: o nome do personagem é o identificador único do save, **independentemente do modo de jogo** — só pode existir um save por nome. Criar ou continuar informando um nome já salvo sempre referencia o mesmo save (RF-61 a RF-65); não há dois saves distintos "Aria (Normal)" e "Aria (Hardcore)" simultâneos. |
| **RN-31** | **Persistência local no backend (v2.8)**: os saves residem em armazenamento local do processo do backend (arquivo ou banco embutido — mecanismo exato em aberto, ver §12 Q-10), nunca no cliente. O aplicativo não lê nem escreve o save diretamente, apenas consome os endpoints do servidor (RF-60 a RF-65), preservando a autoridade do servidor (RN-13). Revisa a premissa PR-06 (§2.4): o estado deixa de ser 100% volátil — reiniciar o backend não descarta mais os personagens salvos, só as sessões que nunca chegaram a ser salvas (se houver uma janela entre mutação e persistência) e qualquer sessão que não tenha nome associado a um save. |
| **RN-32** | **Save e morte em HARDCORE (v2.8)**: ao morrer em modo `HARDCORE`, o sistema remove tanto a sessão em memória (RN-01, já existente) quanto o save persistido associado ao nome (RF-64), na mesma operação — não há janela em que o save sobrevive à sessão. O nome fica livre para uma nova criação do zero (RF-01) depois disso. |

### 4.1 Fórmulas assumidas nesta implementação (v2.0)

Várias RN acima descrevem só a direção qualitativa de uma fórmula (ex.: RN-07 "deriva de agility", RN-11 "função de vitality e nível", RN-16 "cresce monotonicamente"), sem fixar valores. Ao implementar a cadeia sessão → combate → loot, os valores abaixo foram escolhidos e codificados como constantes nomeadas (mesmo padrão das constantes do autômato celular, §10.2/Q-06) — são valores de balanceamento **a revisar**, não regras de negócio fechadas:

| Fórmula | Valor assumido | Onde |
|---|---|---|
| Vida máxima do personagem (RN-11) | `20 + vitality×5 + (level-1)×10` | `Character.maxHealth()` |
| Atributos iniciais do personagem (RF-01/03) | Todos os seis atributos = 5 | `SessionController.create` |
| Chance de erro no combate | 5% fixo | `SpeedBasedCombatResolver` |
| Chance de crítico (RN-07) | 1% por ponto de `agility`, capado em 50% | `SpeedBasedCombatResolver` |
| Multiplicador de crítico | 1.5× o dano-base | `SpeedBasedCombatResolver` |
| Gauge do ATB (RN-05) | Cada lado acumula `speed` por tick; age ao atingir 100 | `SpeedBasedCombatResolver` |
| Escala de atributos do inimigo por profundidade (RN-16) | **Revisada v2.4** (ver nota de balanceamento abaixo): `MIN_ATTRIBUTE=2` no andar 1, subindo linearmente até `BASE_ATTRIBUTE=5` no `EASE_IN_DEPTH=5` (andar de equilíbrio — força igual à de um personagem recém-criado), e daí em diante `5 + (depth-EASE_IN_DEPTH)×1`, como na fórmula original de v2.0 — `depth≤5 ? round(2 + 3×(depth-1)/4) : 5 + (depth-5)` | `EnemyFactory` |
| XP concedida ao vencer (RF-26) | `enemy.maxHealth()/2 + soma dos seis atributos do inimigo` | `SessionController.fight` |
| Chance de drop de loot ao vencer (RF-26) | 70%, exatamente 1 item | `SessionController.grantLoot` |
| Penalidade de XP na derrota em modo NORMAL (RN-02) | 10% da XP atual (piso 0); vida restaurada ao máximo | `SessionController.fight` |
| Peso de raridade por profundidade (RN-16) | Peso-base decrescente por raridade + bônus `depth × ordinal(raridade)` — desloca a massa de probabilidade para raridades altas conforme a profundidade sobe (testado estatisticamente em `RandomLootGeneratorTest`, não célula a célula) | `RandomLootGenerator` |
| Quantidade de afixos por raridade (RN-09) | 0 até `TRIVIAL`, 1 até `COMUM`, 2 `INCOMUM`, 3 `LENDARIO`, 4 `MITICO`, 5 `DIVINO`, 6 `ASTRAL` | `RandomLootGenerator` |
| Catálogo de tipo base de item (RF-30) | Lista fixa provisória: espada, machado, elmo, peitoral, anel, bota — sem atributos intrínsecos (`baseStats` sempre vazio) | `DungeonPopulator.ITEM_BASE_TYPES` |
| XP para o próximo nível (RN-28) | `100 × nível atual` | `Character.xpToNextLevel()` |
| Pontos de atributo por level up (RN-29) | 3 | `Character.ATTRIBUTE_POINTS_PER_LEVEL` |

**Nota de balanceamento observada**: com atributos iniciais fixos em 5 e o personagem sem progressão (RF-06/07 ainda não implementados), a taxa de vitória num primeiro combate no andar 1 ficou em torno de 35–40% em teste manual (amostra de 100 seeds) — o inimigo do andar 1, por ter os mesmos atributos base, ainda leva vantagem estrutural (mais vida, mais velocidade). Aceitável para validar o mecanismo, mas provavelmente exige ajuste antes de qualquer teste com jogadores reais. **Confirmado pelo usuário em playtesting real (v2.4)**: o andar 1 empatado deixa a primeira luta na sorte. Corrigido: inimigos agora nascem mais fracos e só alcançam a força "de equilíbrio" (a mesma de antes) no andar 5 (RN-16, fórmula acima, implementada em `EnemyFactory`) — testado manualmente no Chrome: personagem levou só 3 de dano (42/45 de vida) até vencer o inimigo do andar 1, contra os golpes de 3 de dano do jogador a cada acerto.

---

## 5. Requisitos Não-Funcionais

### 5.1 Desempenho

| ID | Requisito | Métrica de aceitação |
|---|---|---|
| **RNF-01** | A geração de uma masmorra deve ser concluída rapidamente o bastante para não ser percebida como espera. | ≤ 200 ms para uma grade 40×25 (1000 células), no servidor. |
| **RNF-02** | O intervalo entre a geração de um evento de combate no servidor e sua exibição no aplicativo deve ser imperceptível. | ≤ 100 ms em rede local. |
| **RNF-03** | As respostas dos endpoints REST de consulta devem ser rápidas. | ≤ 300 ms no percentil 95. |
| **RNF-04** | A interface do aplicativo deve manter fluidez durante a animação do log de combate. | ≥ 60 fps; sem *jank* perceptível. |

### 5.2 Confiabilidade

| ID | Requisito |
|---|---|
| **RNF-05** | A queda da conexão WebSocket durante um combate não pode corromper o estado da sessão no servidor. Ao reconectar, o cliente deve recuperar o estado atual da sessão. |
| **RNF-06** | O aplicativo deve tratar falhas de rede e códigos de status diferentes de 200, exibindo mensagem compreensível ao jogador em vez de encerrar abruptamente. |
| **RNF-07** | O sorteio pseudoaleatório deve usar geradores semeados explicitamente, jamais fontes de aleatoriedade globais não reprodutíveis, para viabilizar RN-12. |

### 5.3 Usabilidade

| ID | Requisito |
|---|---|
| **RNF-08** | A interface deve ser integralmente em português do Brasil. |
| **RNF-09** | As raridades devem ser distinguíveis por cor **e** por rótulo textual, para não depender apenas da percepção de cor. |
| **RNF-10** | Toda ação destrutiva (descartar item, iniciar run em modo hardcore) deve exigir confirmação explícita. |
| **RNF-11** | O jogador deve conseguir compreender o resultado de um combate lendo apenas o log, sem necessidade de conhecer as fórmulas internas. |

### 5.4 Portabilidade

| ID | Requisito |
|---|---|
| **RNF-12** | O aplicativo deve compilar e executar em Android, Windows e Web a partir de uma base de código única. |
| **RNF-13** | A interface deve ser responsiva, adaptando-se a telas de celular e de desktop. |
| **RNF-14** | O backend deve executar em qualquer sistema operacional com JDK 21, sem dependência de recursos específicos de plataforma. |

### 5.5 Manutenibilidade

| ID | Requisito |
|---|---|
| **RNF-15** | As regras de jogo variáveis (geração, combate, loot) devem estar por trás de interfaces (`MapGenerator`, `CombatResolver`, `LootGenerator`), permitindo substituir a implementação sem alterar os consumidores. |
| **RNF-16** | Dados de balanceamento (afixos, tabelas de raridade, curvas de XP) devem residir em arquivos de recurso, não codificados no fonte. |
| **RNF-17** | O código do aplicativo deve seguir a separação em camadas já estabelecida: `core/models`, `core/network`, `features/<funcionalidade>`. |
| **RNF-18** | O backend deve manter a organização por domínio (`character`, `combat`, `dungeon`, `item`, `session`) com a camada `api` isolando o transporte. |
| **RNF-19** | O código deve passar sem avisos em `dart analyze` (app) e na compilação do Maven (backend). |

### 5.6 Testabilidade

| ID | Requisito |
|---|---|
| **RNF-20** | As regras de negócio de combate e de loot devem ser testáveis unitariamente com seed fixa, produzindo resultados determinísticos e verificáveis. |
| **RNF-21** | Cada requisito funcional essencial deve ter ao menos um teste automatizado associado. |
| **RNF-22** | O gerador de masmorra deve ter teste que valide a existência de caminho entre entrada e saída (RF-12) para um conjunto de seeds. |

### 5.7 Segurança

| ID | Requisito |
|---|---|
| **RNF-23** | O servidor deve validar toda entrada recebida do cliente (identificadores de sala, de item, de sessão), rejeitando comandos inválidos ou inconsistentes com o estado. |
| **RNF-24** | A configuração de origens do WebSocket, atualmente `*`, deve ser restringida às origens conhecidas antes de qualquer publicação fora de ambiente de desenvolvimento. |
| **RNF-25** | Mensagens de erro retornadas ao cliente não devem expor *stack traces* nem detalhes internos de implementação. |

### 5.8 Observabilidade

| ID | Requisito |
|---|---|
| **RNF-26** | O endpoint `/api/health` deve refletir a disponibilidade real da aplicação. |
| **RNF-27** | O servidor deve registrar em log a criação de sessões, o início e o fim de combates e os erros de processamento, com o identificador da sessão. |

---

## 6. Casos de Uso

### UC-01 — Iniciar nova run

| Campo | Conteúdo |
|---|---|
| **Ator principal** | Jogador |
| **Requisitos** | RF-01, RF-02, RF-03, RF-10, RF-42, RF-61, RF-65 |
| **Pré-condições** | Backend disponível; aplicativo configurado com o endereço do servidor. |
| **Pós-condições** | Sessão criada, personagem posicionado na sala `ENTRANCE`. |

**Fluxo principal**

1. O jogador seleciona "Nova run" na tela inicial.
2. O sistema solicita nome e modo de jogo.
3. O jogador informa o nome e escolhe `NORMAL` ou `HARDCORE`.
4. O sistema confirma a escolha de `HARDCORE` explicitamente (RNF-10).
5. O sistema verifica se já existe um save para o nome informado (RF-61); não havendo, segue para o passo 6.
6. O sistema cria o personagem com os atributos iniciais.
7. O sistema gera uma masmorra a partir de uma seed.
8. O sistema cria a sessão associando personagem e masmorra.
9. O sistema posiciona o personagem na sala de entrada e exibe o mapa.

**Fluxos alternativos**

- *4a.* O jogador cancela a confirmação de hardcore → retorna ao passo 3.
- *5a.* Já existe save para o nome informado (RF-65) → o sistema oferece três opções em vez de seguir para o passo 6: **continuar** a jornada salva (aciona UC-08), **nova jornada mantendo o progresso** do save (RF-63 — pula direto para o passo 8, reaproveitando nível/atributos/inventário/equipamento, e o save anterior é substituído pela nova jornada) ou **nova jornada do zero** (segue normalmente para o passo 6, e o save anterior é substituído).
- *8a.* Falha na geração da masmorra → o sistema exibe erro e não cria a sessão.

**Exceções**

- *E1.* Backend indisponível → o aplicativo exibe mensagem de indisponibilidade e oferece nova tentativa (RNF-06).

---

### UC-02 — Explorar a masmorra

| Campo | Conteúdo |
|---|---|
| **Ator principal** | Jogador |
| **Requisitos** | RF-16, RF-17, RF-18, RF-19, RF-54, RF-55 |
| **Pré-condições** | Sessão ativa; personagem vivo. |
| **Pós-condições** | Personagem na nova sala; sala marcada como visitada. |

**Fluxo principal**

1. O aplicativo exibe o mapa com a sala atual e as salas adjacentes.
2. O jogador seleciona uma sala adjacente.
3. O sistema valida a conexão entre as salas (RN-15).
4. O sistema move o personagem e marca a sala como visitada.
5. O sistema resolve o conteúdo da sala conforme o tipo:
   - `EMPTY` → nada ocorre;
   - `LOOT` → aciona UC-04;
   - `ENEMY` → aciona UC-03;
   - `EXIT` → oferece avançar de andar.

**Fluxos alternativos**

- *3a.* Sala não conectada → o sistema recusa o movimento e mantém o estado.
- *5a.* Sala `ENEMY` com inimigo já derrotado e intervalo de respawn (RN-22) ainda não decorrido → tratada como `EMPTY`.
- *5b.* Sala `ENEMY` com inimigo já derrotado e intervalo de respawn (RN-22) já decorrido → o sistema gera um novo inimigo, escalado pela profundidade atual (RF-55), e a sala volta a acionar UC-03.

---

### UC-03 — Combater um inimigo

| Campo | Conteúdo |
|---|---|
| **Ator principal** | Jogador |
| **Atores de sistema** | Resolvedor de Combate |
| **Requisitos** | RF-20 a RF-29 |
| **Pré-condições** | Personagem em sala `ENEMY` com inimigo vivo. |
| **Pós-condições** | Inimigo derrotado (com XP e loot concedidos) **ou** personagem derrotado. |

**Fluxo principal**

1. O sistema inicia o combate e abre o canal WebSocket.
2. O sistema simula os ticks, concedendo ações por `speed` (RN-05).
3. A cada ação, o sistema calcula acerto, crítico ou erro (RN-06, RN-07) e emite o `CombatEvent` correspondente.
4. O aplicativo exibe cada evento no log em tempo real e atualiza as barras de vida.
5. Ao zerar a vida de um combatente, o sistema emite `DEATH` e em seguida `COMBAT_END`.
6. Em caso de vitória, o sistema concede experiência e loot.

**Fluxos alternativos**

- *3a.* Cada acerto desferido pelo personagem com a arma equipada reduz sua durabilidade (RN-18); ao chegar a zero, os golpes seguintes usam o piso de dano de RN-20 até a arma ser reparada ou trocada (UC-07).
- *5a.* **Derrota em modo NORMAL** → o personagem retorna à entrada com penalidade de XP (RN-02).
- *5b.* **Derrota em modo HARDCORE** → a sessão é encerrada e o personagem, perdido (RN-01).
- *6a.* A experiência atinge o limiar → o personagem sobe de nível (RF-06).

**Exceções**

- *E1.* Conexão WebSocket cai durante o combate → o servidor conclui a resolução; ao reconectar, o cliente recupera o estado final da sessão (RNF-05).

---

### UC-04 — Coletar e equipar itens

| Campo | Conteúdo |
|---|---|
| **Ator principal** | Jogador |
| **Atores de sistema** | Gerador de Loot |
| **Requisitos** | RF-30 a RF-41, RF-56 |
| **Pré-condições** | Sessão ativa; item disponível na sala ou no inventário. |
| **Pós-condições** | Inventário e/ou equipamentos atualizados; atributos efetivos recalculados. |

**Fluxo principal**

1. O jogador entra em sala `LOOT` ou vence um combate.
2. O sistema gera o item: raridade ponderada pela profundidade (RF-31), afixos elegíveis sorteados (RN-08, RN-09).
3. O sistema apresenta o item ao jogador.
4. O jogador coleta o item, que vai para o inventário.
5. O jogador abre o inventário e arrasta o item até o slot compatível na ficha do personagem (RF-56); durante o arraste, o aplicativo destaca visualmente o(s) slot(s) compatíveis com a categoria do item (RN-24).
6. O aplicativo compara o item com o equipado no mesmo slot (RF-41).
7. O jogador solta o item sobre um slot compatível para equipá-lo.
8. O sistema devolve o item anterior daquele slot ao inventário e recalcula os atributos efetivos (RF-08).

**Fluxos alternativos**

- *4a.* O jogador ignora o item → o item permanece na sala.
- *5a.* O jogador solta o item sobre um slot incompatível com sua categoria → o aplicativo recusa o *drop* e o item volta ao inventário, sem alterar o equipamento (RN-24).
- *7a.* Slot vazio → nenhum item retorna ao inventário.
- *7b.* Item de categoria `WEAPON`/`SHIELD` solto sobre `HAND_LEFT` ou `HAND_RIGHT` já ocupado → substitui apenas aquela mão, a outra mão permanece como estava (RN-25).

---

### UC-05 — Consultar personagem

| Campo | Conteúdo |
|---|---|
| **Ator principal** | Jogador |
| **Requisitos** | RF-04, RF-07, RF-08, RF-09 |
| **Pré-condições** | Sessão ativa. |

**Fluxo principal**

1. O jogador abre a tela de personagem.
2. O sistema exibe nome, modo, nível, experiência atual e limiar do próximo nível.
3. O sistema exibe os atributos base e os efetivos, evidenciando a contribuição dos equipamentos.
4. Havendo pontos de atributo não distribuídos, o jogador os aloca.
5. O sistema recalcula os atributos efetivos.

---

### UC-06 — Avançar de andar

| Campo | Conteúdo |
|---|---|
| **Ator principal** | Jogador |
| **Requisitos** | RF-19, RF-10, RN-16 |
| **Pré-condições** | Personagem na sala `EXIT`. |
| **Pós-condições** | Nova masmorra gerada com profundidade incrementada; personagem na nova entrada. |

**Fluxo principal**

1. O jogador confirma o avanço na sala de saída.
2. O sistema incrementa a profundidade da sessão.
3. O sistema gera uma nova masmorra com inimigos e loot escalados (RN-16).
4. O sistema posiciona o personagem na nova sala de entrada, preservando nível, atributos e inventário.

---

### UC-07 — Reparar uma arma

| Campo | Conteúdo |
|---|---|
| **Ator principal** | Jogador |
| **Requisitos** | RF-51, RF-52, RF-53 |
| **Pré-condições** | Sessão ativa; jogador possui uma arma com durabilidade abaixo do máximo, equipada ou no inventário. |
| **Pós-condições** | Durabilidade da arma restaurada ao máximo; afixos e bônus voltam a se aplicar (RN-20). |

**Fluxo principal**

1. O jogador seleciona uma arma com durabilidade reduzida no inventário ou na ficha do personagem.
2. O jogador aciona a opção de reparo.
3. O sistema restaura a durabilidade da arma ao valor máximo (RN-21).
4. O sistema recalcula os atributos efetivos do personagem, reincorporando os afixos da arma se ela estava quebrada (RF-08).

**Fluxos alternativos**

- *1a.* A arma já está com durabilidade máxima → a opção de reparo fica indisponível.

**Observação**: o mecanismo de custo do reparo (moeda, material ou disponibilidade apenas em pontos específicos da masmorra) é uma questão em aberto — ver §12, Q-01.

---

### UC-08 — Continuar jornada salva (v2.8)

| Campo | Conteúdo |
|---|---|
| **Ator principal** | Jogador |
| **Requisitos** | RF-60, RF-61, RF-62 |
| **Pré-condições** | Existe um save no backend associado ao nome informado (RF-61); nenhuma sessão em memória com aquele nome está ativa no momento (RN-30 — um nome, um save). |
| **Pós-condições** | Sessão restaurada em memória exatamente como estava no último salvamento (mesma masmorra, sala atual, andar, salas visitadas, personagem). |

**Fluxo principal**

1. O jogador informa o nome de um personagem salvo (UC-01, passo 5a) e escolhe "Continuar".
2. O sistema localiza o save associado ao nome (RF-61).
3. O sistema restaura a sessão completa a partir do save (RF-62): masmorra, sala atual, andar, salas visitadas e personagem (nível, experiência, atributos, inventário, equipamento).
4. O sistema devolve a sessão restaurada e o aplicativo exibe o mapa na sala em que o jogador parou.

**Fluxos alternativos**

- *2a.* Não existe save para o nome informado → o sistema recusa e o aplicativo segue o fluxo de criação normal (UC-01).

**Exceções**

- *E1.* Save corrompido ou ilegível → o sistema exibe erro e não restaura a sessão (RNF-06); o nome permanece indisponível para nova criação até o save ser removido manualmente (mecanismo de recuperação em aberto — ver §12, Q-11).

---

## 7. Modelo de domínio e dicionário de dados

```
GameSession ──1───1── Character ──1───*── Item (inventory)
     │                    │       └──1───*── Item (equipped, por slot)
     │                    └──1───1── Attributes
     │
     └──1───1── DungeonMap ──1───*── Room ──0..1── Enemy ──1───1── Attributes
                                      └──1───*── Item ──1───*── Affix
```

| Entidade | Campo | Tipo | Descrição |
|---|---|---|---|
| **Character** | `id` | String | Identificador único, imutável. |
| | `name` | String | Nome escolhido pelo jogador, imutável. |
| | `mode` | GameMode | `HARDCORE` ou `NORMAL`, imutável (RN-03). |
| | `level` | int | Nível atual. Inicia em 1. |
| | `experience` | int | Experiência acumulada. Inicia em 0. |
| | `attributes` | Attributes | Atributos base. |
| | `inventory` | List\<Item\> | Itens carregados. |
| | `equipped` | Map\<Slot, Item\> | Slot → item equipado (RN-23); no máximo um item por slot dos oito (`HEAD`, `CHEST`, `LEGS`, `FEET`, `HAND_LEFT`, `HAND_RIGHT`, `ACCESSORY_1`, `ACCESSORY_2`). Implementado com o enum `Slot` (v2.3); serializado como `Map<String, Item>` no JSON (chave = `Slot.name()`), sem mudança de contrato para o app. |
| | `effectiveAttributes` | Attributes | RF-08: atributos base + soma dos modificadores de afixo dos itens equipados que correspondem a um campo de `Attributes`. Calculado, não persistido; ainda não usado pelo combate (Q-07). |
| **Attributes** | `strength` | int | Base do dano físico (RN-06). |
| | `agility` | int | Base da chance de crítico (RN-07). |
| | `vitality` | int | Base da vida máxima (RN-11). |
| | `speed` | int | Frequência de ação no combate (RN-05). |
| | `defense` | int | Redução de dano recebido (RN-06). |
| | `intelligence` | int | Base do poder mágico. |
| **DungeonMap** | `seed` | String | Semente da geração (RN-12). |
| | `entranceRoomId` | String | Identificador da sala inicial. |
| | `width`, `height` | int | Dimensões da grade do autômato celular, em células. |
| | `rooms` | Map\<String, Room\> | **Todas** as células da grade (`width` × `height`), indexadas por `"{x},{y}"` — grade densa, sem buracos, inclusive as `WALL`. |
| **Room** | `id` | String | Identificador único no mapa, no formato `"{x},{y}"`. |
| | `type` | RoomType | `ENTRANCE`, `EMPTY`, `LOOT`, `ENEMY`, `EXIT` (andáveis) ou `WALL` (intransponível). |
| | `x`, `y` | int | Coordenadas da célula na grade (0-indexadas; `x` cresce para a direita, `y` para baixo). |
| | `items` | List\<Item\> | Itens presentes na sala. Vazio em salas `WALL`. |
| | `connectedRoomIds` | List\<String\> | Salas andáveis ortogonalmente adjacentes, alcançáveis diretamente (RN-15). Sempre vazio em salas `WALL`, e nunca aponta para uma `WALL`. |
| | `enemy` | Enemy | Inimigo presente, ou nulo. |
| | `enemyDefeatedAt` | Instant | Momento em que o inimigo da sala foi derrotado; nulo enquanto a sala nunca teve inimigo derrotado. Usado para calcular o respawn por tempo (RN-22); limpo quando um novo inimigo é gerado. |
| **Enemy** | `id`, `name` | String | Identificação. |
| | `attributes` | Attributes | Atributos do inimigo. |
| | `currentHealth`, `maxHealth` | int | Vida atual e máxima. |
| **Item** | `id` | String | Identificador único (UUID). |
| | `baseType` | String | Tipo base; determina a categoria de equipamento e, por ela, o(s) slot(s) compatíveis (RN-24). Continua uma string livre no modelo (sem campo de categoria próprio) — a categorização é feita por uma tabela estática `baseType → EquipmentCategory` (`item/ItemCatalog.java`, backend) espelhada só para UX no app (`equipment_category.dart`); catálogo agora inclui `calca` (LEG_ARMOR) e `escudo` (SHIELD), que faltavam. |
| | `itemLevel` | int | Nível do item (RN-10). |
| | `rarity` | Rarity | Raridade (RN-04). |
| | `prefixes` | List\<Affix\> | Afixos aplicados. |
| | `baseStats` | Map\<String, Double\> | Atributos intrínsecos do tipo base. |
| | `maxDurability` | int | Durabilidade máxima. Aplicável somente quando `baseType` é uma arma (RN-17). |
| | `currentDurability` | int | Durabilidade atual. Reduz a cada acerto (RN-18); nunca negativa (RF-49). |
| **Affix** | `id`, `name` | String | Identificação. |
| | `modifiers` | Map\<String, Double\> | Atributo → valor somado. |
| | `minItemLevel` | int | Nível mínimo de item (RN-08). |
| | `minRarity` | Rarity | Raridade mínima (RN-08). |
| **CombatEvent** | `type` | CombatEventType | `ATTACK`, `CRITICAL_HIT`, `MISS`, `DEATH`, `COMBAT_END`. |
| | `actorId`, `targetId` | String | Quem age e quem sofre. |
| | `amount` | int | Valor associado (dano, cura). |
| | `timestamp` | long | Momento do evento, em milissegundos. |

---

## 8. Interfaces externas

### 8.1 Endpoints REST implementados

| Método | Caminho | Descrição | Requisito |
|---|---|---|---|
| `GET` | `/api/health` | Verificação de saúde. Retorna `"ok"`. | RF-45 |
| `GET` | `/api/character/ping` | Sonda do módulo de personagem (provisório, sem uso real desde que `SessionController` assumiu os endpoints de personagem). | — |
| `POST` | `/api/dungeon/generate?width={w}&height={h}&seed={s}` | Gera uma masmorra via autômato celular **sem povoar** `ENEMY`/`LOOT` (usado pela tela de Mapa do app). `width` padrão 40, `height` padrão 25. `seed` opcional; se omitida, deriva do relógio do servidor (não reproduzível). | RF-10, RF-11 |
| `POST` | `/api/session` | Cria personagem (atributos padrão, ver §4.1) e sessão, gera e povoa uma masmorra 40×25 na profundidade 1. Corpo: `{ name, mode, seed? }`. Devolve a sessão completa (201). | RF-01, RF-02, RF-03, RF-42 |
| `GET` | `/api/session/{id}` | Retorna o estado completo da sessão (404 se não existir). | RF-43 |
| `GET` | `/api/session/{id}/character` | Retorna só a ficha do personagem. | RF-04 |
| `POST` | `/api/session/{id}/move` | Move para a sala informada (400 se não conectada à atual, RN-15). Se a sala destino tem inimigo vivo, resolve o combate nessa mesma chamada (RF-20 a RF-27) e aplica o resultado. Corpo: `{ roomId }`. Resposta: `{ session, combatEvents }` — `combatEvents` é `null` quando não houve luta. | RF-16, RF-17, RF-20 a RF-27 |
| `POST` | `/api/session/{id}/loot` | Coleta todos os itens da sala atual para o inventário, esvaziando a sala. | RF-35 |
| `POST` | `/api/session/{id}/equip` | Equipa um item do inventário num slot. Corpo: `{ itemId, slot }` (`slot` como string, ex. `"HAND_LEFT"`). 400 se o item não existir no inventário, a categoria for incompatível com o slot, ou o nome do slot for inválido. Devolve a sessão completa. | RF-37, RN-23 a RN-25 |
| `POST` | `/api/session/{id}/unequip` | Desequipa o slot informado, devolvendo o item ao inventário (não-op se já vazio). Corpo: `{ slot }`. 400 se o nome do slot for inválido. Devolve a sessão completa. | RF-38 |
| `POST` | `/api/session/{id}/descend` | Avança para o próximo andar a partir da sala `EXIT` do andar atual (400 via `InvalidDescendException` se o personagem não estiver nela). Gera e povoa a masmorra do novo andar com seed derivada da atual (RN-12) e reposiciona o personagem na entrada, limpando `visitedRoomIds`. Devolve a sessão completa. | RF-19 |
| `POST` | `/api/session/{id}/character/attributes` | Distribui um ponto de atributo não gasto (RN-29). Corpo: `{ attribute }` (nome do atributo em SCREAMING_SNAKE_CASE, ex. `"STRENGTH"`). 400 (`InvalidAttributeAllocationException`) se não houver saldo ou o nome for inválido. Devolve a sessão completa. | RF-07 |

### 8.2 Endpoints REST previstos

| Método | Caminho | Descrição | Requisito |
|---|---|---|---|
| `GET` | `/api/characters/{name}/save` | Consulta se existe um save para o nome informado (200 com um resumo — nível, modo, profundidade — ou 404 se não houver). | RF-61 |
| `POST` | `/api/characters/{name}/continue` | Restaura a sessão completa a partir do save associado ao nome (404 se não houver save). Devolve a sessão completa, como um `POST /api/session` bem-sucedido. | RF-62 |
| `POST` | `/api/session` (revisão) | Ganha um comportamento novo quando `name` já tem save (RN-30): por padrão devolve 409 em vez de criar um segundo personagem homônimo, a menos que o corpo inclua `keepProgress: true` (RF-63 — cria uma masmorra nova reaproveitando o personagem salvo) ou `overwrite: true` (RF-65, opção "do zero" — cria normalmente, substituindo o save anterior). | RF-01, RF-63, RF-65 |

### 8.3 Canal WebSocket

**Não implementado nesta versão** (`CombatSocketHandler` continua stub, RF-24 pendente — ver PEND-13). O combate hoje é resolvido de forma síncrona por `POST /api/session/{id}/move` (§8.1), que devolve a lista completa de `CombatEvent` na resposta em vez de transmiti-los em tempo real. O desenho abaixo é o alvo original, mantido como referência para quando a migração for feita:

| Endpoint | Direção | Conteúdo |
|---|---|---|
| `/ws/combat` | Cliente → Servidor | Comando de início de combate, contendo o identificador da sessão. |
| `/ws/combat` | Servidor → Cliente | Sequência de `CombatEvent` serializados em JSON, um por mensagem, na ordem de ocorrência. |

**Contrato do evento** (formato serializado):

```json
{
  "type": "CRITICAL_HIT",
  "actorId": "char-1",
  "targetId": "enemy-3",
  "amount": 27,
  "timestamp": 1757308800000
}
```

---

## 9. Matriz de rastreabilidade

| Requisito | Regras associadas | Casos de uso | Artefato de código |
|---|---|---|---|
| RF-01, RF-02, RF-03 | RN-03, RN-14 | UC-01 | `character/Character.java`, `character/GameMode.java`, `character/Attributes.java` |
| RF-04, RF-09 | — | UC-05 | `api/controller/SessionController.java` (`getCharacter`), `features/character/character_screen.dart` |
| RF-05, RF-06, RF-07 | RN-11, RN-28, RN-29 | UC-03, UC-05 | `character/Character.java` (`gainExperience`, `allocateAttributePoint`), `character/AttributeType.java`, `api/controller/SessionController.java` (`allocateAttribute`), `features/character/character_screen.dart` |
| RF-08 | RN-08 | UC-04, UC-05 | `character/Character.java` (`effectiveAttributes`), `features/character/character_screen.dart` |
| RF-10, RF-11, RF-12, RF-13 | RN-12, RN-15 | UC-01, UC-06 | `dungeon/MapGenerator.java`, `dungeon/RandomMapGenerator.java`, `dungeon/RoomType.java` |
| RF-14, RF-15 | RN-16 | UC-02 | `dungeon/DungeonPopulator.java`, `combat/EnemyFactory.java` |
| RF-16, RF-17 | RN-15 | UC-02 | `session/GameSession.java` (`moveTo`), `api/controller/SessionController.java` (`move`), `core/game/game_controller.dart`, `features/dungeon_map/dungeon_map_screen.dart` |
| RF-18 | — | UC-02 | `core/game/game_controller.dart`, `features/dungeon_map/dungeon_map_screen.dart` |
| RF-19 | RN-12 | UC-02 | `session/GameSession.java` (`descendTo`), `api/controller/SessionController.java` (`descend`), `features/dungeon_map/dungeon_map_screen.dart` |
| RF-20 a RF-23 | RN-05, RN-06, RN-07 | UC-03 | `combat/CombatResolver.java`, `combat/SpeedBasedCombatResolver.java`, `combat/CombatEvent.java`, `api/controller/SessionController.java` (`move`/`fight`) |
| RF-24 | RN-13 | UC-03 | `api/websocket/CombatSocketHandler.java` (*ainda stub — ver PEND-13*), `api/config/WebSocketConfig.java`, `core/network/combat_socket_client.dart` (*ainda sem uso — ver PEND-13*) |
| RF-25, RF-26, RF-27 | RN-01, RN-02 | UC-03 | `combat/CombatEventType.java`, `api/controller/SessionController.java` (`fight`, `grantLoot`) |
| RF-28, RF-29 | — | UC-03 | `core/game/game_controller.dart`, `features/combat/combat_screen.dart` |
| RF-30, RF-31 | RN-10, RN-16 | UC-04 | `item/LootGenerator.java`, `item/RandomLootGenerator.java`, `item/Rarity.java` |
| RF-32, RF-33, RF-34 | RN-08, RN-09 | UC-04 | `item/Affix.java`, `item/AffixTable.java`, `resources/data/affixes.json` |
| RF-35, RF-36, RF-39 | — | UC-04 | `character/Character.java` (`inventory`), `api/controller/SessionController.java` (`loot`), `features/inventory/inventory_screen.dart` |
| RF-37, RF-38 | RN-23, RN-24, RN-25 | UC-04 | `character/Slot.java`, `item/EquipmentCategory.java`, `item/ItemCatalog.java`, `character/Character.java` (`equip`, `unequip`), `api/controller/SessionController.java` (`equip`, `unequip`), `api/dto/EquipRequest.java`/`UnequipRequest.java`, `character/InvalidEquipException.java` |
| RF-40, RF-41 | RN-04 | UC-04 | `features/inventory/inventory_screen.dart`, `features/character/character_screen.dart` (`_showCompare`, RF-41) |
| RF-56 | RN-23, RN-24, RN-25 | UC-04 | `features/character/equipment_slots.dart`, `features/character/character_screen.dart`, `core/models/equipment_category.dart` |
| RF-57 | — | — | `features/shell/game_shell.dart`, `lib/main.dart` (`_openShell`), `features/dungeon_map/dungeon_map_screen.dart` (`onCombatTriggered`), `features/combat/combat_screen.dart` (`onFinished`) |
| RF-42, RF-43, RF-44 | RN-01, RN-14 | UC-01, UC-03 | `session/GameSession.java`, `session/SessionService.java`, `api/controller/SessionController.java`, `core/game/game_controller.dart`, `lib/main.dart` (diálogo "Nova run") |
| RF-45 | — | — | `api/controller/HealthController.java` |
| RF-46 | — | UC-01 | `core/network/api_client.dart` (`_defaultBackendBaseUrl` fixo, sem UI) |
| RF-47 a RF-50 | RN-17, RN-18, RN-19, RN-20 | UC-03 | `item/Item.java` (*a estender*), `combat/SpeedBasedCombatResolver.java` (*a estender*) |
| RF-51 | RN-21 | UC-07 | *a criar* — serviço de reparo de itens |
| RF-52, RF-53 | — | UC-07, UC-05 | `features/inventory/inventory_screen.dart`, `features/character/character_screen.dart` |
| RF-54, RF-55 | RN-22, RN-16 | UC-02 | `dungeon/Room.java` (*a estender*), `combat/Enemy.java` |

---

## 10. Situação atual e pendências

### 10.1 Panorama

O jogo agora é jogável **de ponta a ponta pela interface**, não só por HTTP: o app Flutter tem um fluxo real de criar personagem/sessão (diálogo "Nova run" em `HomeScreen`), explorar o mapa gerado e povoado de verdade (`DungeonMapScreen`, ligada à sessão via `GameController`), combater automaticamente ao entrar numa sala com inimigo (`CombatScreen`, log e barras de vida animados a partir dos eventos que o backend já resolveu), ver a consequência de vitória/derrota, coletar loot (`InventoryScreen`) e conferir a ficha (`CharacterScreen`). O backend resolve sessão, movimento com validação de conectividade (RN-15), combate ATB real (RN-05/06/07), XP/loot na vitória, progressão por nível (RF-05 a RF-07, desde v2.7) e a consequência de derrota (RN-01/02) — tudo coberto por 82 testes automatizados no backend e 40 no app (contagens de v2.7; ver §10.3 para o que mudou em cada versão). RF-24 (transmitir combate por WebSocket) é a exceção notável: o combate é resolvido de forma síncrona dentro de `/move` e a "sensação de tempo real" é simulada no cliente (ver PEND-13); `CombatSocketHandler` e `combat_socket_client.dart` seguem sem uso. **Desde v2.6/v2.7**, RF-19 (avançar de andar) e RF-05 a RF-07 (progressão) saíram de pendentes para implementados — ver as entradas correspondentes no histórico de revisões (§13) em vez do resumo antigo deste parágrafo, que ficou defasado nessas duas rodadas. **Em v2.8**, novo requisito de persistência local por nome (RF-60 a RF-65, §3.9) foi levantado mas ainda **não implementado** — ainda pendentes, além dele: durabilidade de armas (RF-47 a RF-53), respawn de inimigos (RF-54, RF-55) e descarte de item (RF-39). O **módulo de equipamento e navegação** (RF-08, RF-37, RF-38, RF-41, RF-56, RF-57; RN-23 a RN-25), definido em v2.2 a pedido do usuário após testar o app manualmente, foi implementado nesta versão (v2.3): enum `Slot` (oito posições, com as duas mãos aceitando arma ou escudo em qualquer combinação — RN-25 — e dois acessórios), categorização de `baseType` em sete categorias via `ItemCatalog` (backend, espelhada só para UX no app), endpoints `POST /api/session/{id}/equip`/`unequip`, tela de equipar por arraste em `CharacterScreen` (`EquipmentSlots`, drag-and-drop nativo do Flutter, sem dependência nova) e navegação global via `GameShell` (`NavigationBar` + `IndexedStack`, Material 3). Testado manualmente de ponta a ponta no Chrome: criar sessão → coletar item → arrastar até slot compatível (aceito) e incompatível (recusado, item volta à lista) → desequipar → trocar de aba sem perder estado → lutar duas vezes na mesma visita ao shell (confirma que a animação de combate reinicia corretamente a cada luta, não só na primeira) → morte em modo NORMAL preserva equipamento. Combate usava os atributos base, não os efetivos, até v2.4/v2.5 (ver abaixo). **Feedback de playtesting real do usuário (v2.4)**: equipar item de fato não mudava nada no combate, e o inimigo do andar 1 empatado com o personagem tornava a primeira luta uma loteria; pedido também de ícone por categoria de equipamento e cor por tipo de afixo. **Resolvido em v2.5**: `SpeedBasedCombatResolver` passou a usar `player.effectiveAttributes()` (RN-26); `EnemyFactory` revisado para o inimigo nascer mais fraco no andar 1 e só igualar o personagem no andar 5 (RN-16); `InventoryScreen`/`CharacterScreen`/`EquipmentSlots` ganharam ícone por categoria (RF-58) e selo de cor por afixo (RF-59, RN-27) — achado e corrigido em teste manual: o ícone não podia ser tingido pela cor de raridade porque raridades claras (Normal) ficavam invisíveis; a cor de raridade ficou só no selo. Testado manualmente no Chrome de ponta a ponta (criar sessão, vencer o inimigo do andar 1 levando pouco dano, coletar e equipar item, ver ícone/selo de cor). Ver §10.3 item 5.6.

### 10.2 Inconsistências identificadas no código atual

Pontos observados durante o levantamento, que exigem decisão antes da implementação:

| ID | Descrição | Impacto |
|---|---|---|
| ~~PEND-01~~ | ~~`data/affixes.json` referencia as raridades `RARO`, `ÉPICO` e `LENDÁRIO` (com acento), que **não existem** no enum `Rarity`. A desserialização do arquivo falhará.~~ **Resolvido** (v1.8): raridades substituídas por valores válidos do enum, preservando a ordem relativa original (`RARO`→`LENDARIO`, `ÉPICO`→`MITICO`, `LENDÁRIO`→`DIVINO`); guarda de regressão em `AffixesJsonTest`. | — |
| ~~PEND-02~~ | ~~`Attributes` do backend possui seis campos; o `Attributes` do app possui apenas quatro (faltam `defense` e `intelligence`).~~ **Resolvido** (v1.8): campos adicionados ao `Attributes` do app. | — |
| ~~PEND-03~~ | ~~`CombatEventType` é serializado pelo Java como `CRITICAL_HIT`, mas `CombatEvent.fromJson` no app esperava `criticalHit`, lançando exceção para críticos.~~ **Resolvido** (v1.8): `CombatEvent.fromJson` converte de `SCREAMING_SNAKE_CASE` para o nome do enum Dart antes de resolver o valor. | — |
| ~~PEND-04~~ | ~~`Item` do backend possui `baseStats`, campo ausente no `Item.fromJson` do app.~~ **Resolvido** (v1.8): `baseStats` adicionado ao `Item` do app. | — |
| ~~PEND-05~~ | ~~`DungeonMap` e `Room` do app não possuem `fromJson`.~~ **Resolvido** (v1.6): `Room.fromJson`/`DungeonMap.fromJson` implementados, incluindo `x`/`y`/`width`/`height`. | — |
| ~~PEND-06~~ | ~~`DungeonController` deriva a seed de `System.currentTimeMillis()` e não a aceita na requisição, impossibilitando reproduzir uma masmorra.~~ **Resolvido** (v1.7): parâmetro `seed` opcional adicionado ao endpoint; cai no relógio do servidor somente se omitido. | — |
| ~~PEND-07~~ | ~~`RandomMapGenerator` ignora os parâmetros `width`/`height` e sempre devolve uma única sala; o autômato celular em si (preenchimento + suavização + *flood fill*) ainda não está implementado.~~ **Resolvido** (v1.7): autômato celular implementado (preenchimento ponderado, suavização B678/S345678, flood fill da maior região, entrada/saída pelos pontos mais distantes por BFS). | — |
| **PEND-08** | `SessionService` mantém as sessões em memória; reiniciar o servidor descarta todo o progresso. | Aceito nesta versão (PR-06). |
| **PEND-09** | `ApiClient.generateDungeon` não trata status diferentes de 200 nem erros de rede. Mitigado parcialmente em v1.9: `DungeonMapScreen` captura a exceção lançada (`FutureBuilder.hasError`) e exibe mensagem amigável + retry, mas o `ApiClient` em si ainda não valida o status code. | Conflita com RNF-06. |
| **PEND-10** | `WebSocketConfig` permite qualquer origem (`setAllowedOrigins("*")`). | Conflita com RNF-24. |
| **PEND-11** | Não há testes automatizados além do teste de contexto gerado pelo Spring Initializr. | Conflita com RNF-21 — parcialmente superado a partir de v1.7 (`RandomMapGeneratorTest`, `AffixesJsonTest`) e no app (`model_contracts_test.dart`, `dungeon_map_screen_test.dart`), mas cobertura ainda está longe de RNF-21 (nem todo RF essencial tem teste). |
| ~~PEND-12~~ | ~~O backend não liberava CORS para os endpoints REST; qualquer chamada do app Flutter web (origem própria, ex. `http://localhost:5050`) para `http://localhost:8080` era bloqueada pelo navegador — descoberto ao testar `DungeonMapScreen` de verdade no Chrome (`ClientException: Failed to fetch`).~~ **Resolvido** (v1.9): `WebConfig` libera `/api/**` para origens `localhost`/`127.0.0.1` em qualquer porta (RNF-24 — restrito, não `*`; revisar antes de publicação fora do ambiente de desenvolvimento). | — |
| **PEND-13** | RF-24 pede que os eventos de combate sejam transmitidos por `/ws/combat` em tempo real; nesta versão o combate é resolvido de forma síncrona dentro de `POST /api/session/{id}/move`, que devolve a lista completa de `CombatEvent` na resposta HTTP. `CombatSocketHandler` continua stub. Decisão deliberada para manter a rodada de sessão/combate/loot no escopo combinado com o usuário (ver docs/requisitos.md v2.0 e o plano da sessão). | Conflita com RF-24, PR-03. Migrar para streaming via WS é trabalho futuro. |
| **PEND-14** | `Enemy.currentHealth()` não reflete dano parcial sofrido durante um combate em que o personagem perdeu: como `Enemy` é imutável e `SpeedBasedCombatResolver` só rastreia a vida do inimigo localmente (variável `enemyHealth`, nunca escrita de volta no registro), um inimigo que sobrevive a uma luta aparece com vida cheia na próxima consulta à sessão, mesmo tendo levado dano real durante o combate anterior. | Sem impacto funcional nesta versão (não há multi-round persistente nem RF que exija isso), mas pode surpreender ao inspecionar a API. Considerar ao implementar respawn (RF-54/55) ou combates repetíveis. |
| **PEND-15** | Desde que `DungeonMapScreen` passou a usar a sessão real (v2.1), `ApiClient.generateDungeon` (endpoint cru `/api/dungeon/generate`) e `core/network/combat_socket_client.dart` (WebSocket) ficaram sem nenhum chamador no app — continuam corretos e testados do lado que existe (backend/o próprio `ApiClient`), só não são mais exercitados pela UI. | Nenhum — mantidos deliberadamente: o endpoint cru continua documentado em §8.1, e o cliente WS é o ponto de partida natural para a migração de PEND-13. Reavaliar remoção se ficarem obsoletos de vez. |

### 10.3 Ordem de implementação sugerida

1. ~~**Corrigir os contratos** (PEND-01 a PEND-05) — sem isso nenhuma integração funciona.~~ Concluído (v1.6 a v1.8).
2. ~~**Geração de masmorra** (RF-10 a RF-13) com seed explícita (PEND-06, PEND-07).~~ Concluído (v1.7).
3. ~~**Sessão e navegação** (RF-42, RF-43, RF-16) — entrega a jogabilidade mínima.~~ Concluído (v2.0).
4. ~~**Combate** (RF-20 a RF-27) — o núcleo do jogo.~~ Concluído (v2.0), mas via HTTP síncrono, não WebSocket (RF-24/RF-28/RF-29 seguem pendentes — ver PEND-13).
5. ~~**Loot** (RF-30 a RF-36, RF-40).~~ Concluído (v2.0 backend, v2.1 app: `InventoryScreen`).
5.5. ~~**Equipamento e navegação** (RF-08, RF-37, RF-38, RF-41, RF-56, RF-57; RN-23 a RN-25).~~ Concluído (v2.3): enum `Slot`, categoria de equipamento por `baseType` (com `calca`/LEG_ARMOR e `escudo`/SHIELD adicionados ao catálogo), endpoint de equipar/desequipar, tela de arraste e navegação global entre Mapa/Combate/Inventário/Personagem.
5.6. ~~**Equipamento efetivo no combate + balanceamento do andar 1 + ícones/cores de item** (RN-26, RN-16 revisada, RF-58, RF-59).~~ Concluído (v2.5): combate usa `effectiveAttributes()` do jogador; `EnemyFactory` revisado com aquecimento até o andar 5; ícone por categoria e selo de cor por afixo no inventário, ficha e slots.
6. **Durabilidade de armas** (RF-47 a RF-53) — depende do loot já existir (já existe, v2.0).
7. ~~**Progressão** (RF-05 a RF-07 — RF-08 já concluído em v2.3, ver item 5.5).~~ Concluído (v2.7): curva de XP e level up (RN-28), pontos de atributo distribuíveis (RN-29).
8. ~~**Andares e escalonamento** (RF-19, RN-16 — o escalonamento de inimigos por profundidade já existe, v2.0; falta avançar de andar).~~ Concluído (v2.6): `POST /api/session/{id}/descend`, ação explícita na sala EXIT.
9. **Respawn de inimigos** (RF-54, RF-55) — inclui criar `data/respawn.json` com os pesos do power score e os limites do intervalo.
10. **Persistência local de personagem** (RF-60 a RF-65, RN-30 a RN-32, v2.8) — depende de resolver Q-10 (mecanismo de armazenamento) antes de começar; não depende de nenhum outro item pendente desta lista.

---

## 11. Fora de escopo

Os itens abaixo são **explicitamente excluídos** desta versão. Ficam registrados como evolução possível:

| Item | Justificativa |
|---|---|
| Autenticação e contas de usuário | O produto é single-player sem identidade persistente — persistência local por nome (RF-60 a RF-65, v2.8) não é uma conta, é uma chave de save sem senha/dono. |
| Persistência em nuvem, sincronização entre dispositivos ou múltiplos saves por nome | Fora de escopo mesmo após v2.8: a persistência local (RN-30, RN-31) é um save único por nome, no disco da máquina que roda o backend — não sincroniza entre instalações nem guarda histórico de saves anteriores para o mesmo nome. |
| Multiplayer, cooperativo ou competitivo | Escopo consideravelmente maior; exigiria sincronização de estado e resolução de conflitos. |
| Ranking / placar global | Depende de contas — persistência local por nome (v2.8) não é suficiente para isso. |
| Monetização e compras no aplicativo | Não aplicável. |
| Áudio, trilha sonora e efeitos sonoros | Não essencial para validar as mecânicas. |
| Animações e arte de personagens/inimigos | A versão inicial usa representação textual e geométrica. |
| Internacionalização além do português | RNF-08 fixa pt-BR como único idioma. |
| Modo offline | O servidor é a autoridade das regras (RN-13). |

---

## 12. Questões em aberto

| ID | Questão | Requisitos afetados | Decisão necessária |
|---|---|---|---|
| **Q-01** | Qual o mecanismo de reparo de armas: gratuito ao retornar à entrada, consumo de material coletável como loot, ou uma moeda dedicada (o que exigiria modelar uma economia, hoje fora de escopo)? | RF-51, RN-21, UC-07 | Definir antes de implementar o serviço de reparo. |
| **Q-02** | A durabilidade máxima varia por `baseType` de arma (ex.: espada dura mais que adaga) ou é um valor único para todas as armas, alterado apenas por afixos? | RF-47, RN-19 | Definir a tabela de durabilidade base por tipo de arma. |
| **Q-03** | Uma arma quebrada (RN-20) pode ainda ser equipada normalmente, ou o sistema deve impedir o combate até reparo/troca? | RF-50, RN-20, UC-03 | Confirmar se o piso de dano é suficiente ou se deve haver bloqueio. |
| ~~Q-06~~ | ~~Quais os parâmetros do autômato celular (...) e onde residem?~~ **Resolvida** (v1.7): 45% de probabilidade inicial de parede, 4 iterações de suavização, regra B678/S345678 (vizinhança de Moore), região mínima de 10% da grade (com até 10 tentativas usando seed derivada antes de aceitar uma região menor). Por ora residem como constantes em `RandomMapGenerator` (não em arquivo de dados); migrar para `data/dungeon.json` fica como melhoria futura de RNF-16 se o balanceamento exigir ajuste sem recompilar. | RF-10, RF-11, RF-12, RNF-16 |
| ~~Q-07~~ | ~~Empunhar duas armas (RN-25) concede uma ação de ataque extra por tick no combate ATB, ou só acumula os bônus de atributo de ambas via atributos efetivos (RF-08)?~~ **Resolvida** (v2.4): só acumula atributos, sem ação extra — RN-26, implementada em `SpeedBasedCombatResolver`. | RF-08, RF-21, RN-25, RN-26, UC-03 | — |
| ~~Q-08~~ | ~~O selo de cor por afixo (RN-27) deve aparecer só na lista do inventário, ou também nos slots de equipamento e no diálogo de comparação (RF-41)?~~ **Resolvida** (v2.4): aparece em todo lugar que mostra o item — lista do inventário, chip arrastável em `CharacterScreen` e slots de equipamento. Não foi adicionado ao diálogo de comparação (RF-41) por ora — ele já compara os atributos numericamente, o selo de cor seria redundante ali. | RF-40, RF-56, RF-59, RN-27 | — |
| ~~Q-09~~ | ~~Qual ícone específico do Material Design representa cada uma das sete categorias de equipamento (RN-24)?~~ **Resolvida** (v2.4): `Icons.gavel` (arma), `Icons.shield` (escudo), `Icons.sports_motorsports` (elmo), `Icons.checkroom` (peitoral), `Icons.accessibility_new` (calça), `Icons.directions_walk` (bota), `Icons.diamond` (acessório) — todos confirmados existentes em `icons.dart` do SDK Flutter antes do uso, evitando erro de compilação. | RF-58 | — |
| **Q-10** | Qual o mecanismo exato de armazenamento local do save (RN-31): um arquivo JSON por personagem (`data/saves/{nome}.json`, mesmo padrão de `data/affixes.json`), um banco embutido (H2/SQLite) num único arquivo, ou outra opção? Também em aberto: nomes de personagem hoje aceitam qualquer string (RF-01) — precisam de normalização (case-insensitive? acentos? caracteres especiais proibidos por segurança de nome de arquivo, já que o nome vira parte de um caminho em disco na opção de arquivo por nome) antes de virar chave de save? | RF-60, RN-30, RN-31 | Definir antes de implementar a persistência. |
| **Q-11** | Um save corrompido ou ilegível (UC-08, E1) bloqueia o nome permanentemente, já que RN-30 exige um save por nome? O sistema precisa de um endpoint para apagar/recriar um save específico, ou isso é um problema raro o bastante para resolver manualmente (apagando o arquivo/registro direto no servidor) nesta versão? | RF-61, RF-62, RN-30, UC-08 | Definir se entra um endpoint de exclusão de save nesta rodada ou fica para depois. |

---

## 13. Histórico de revisões

| Versão | Data | Autor | Descrição |
|---|---|---|---|
| 1.0 | 08/09/2026 | furiossam@hotmail.com | Versão inicial. Levantamento a partir do esqueleto no commit `3b87fa9`. |
| 1.1 | 08/09/2026 | furiossam@hotmail.com | Adicionado o módulo de durabilidade de armas (RF-47 a RF-53, RN-17 a RN-21, UC-07) e a seção de questões em aberto. |
| 1.2 | 10/09/2026 | furiossam@hotmail.com | Adicionado o módulo de respawn de inimigos (RF-54, RF-55, RN-22), o fluxo alternativo correspondente em UC-02 e a questão em aberto sobre o gatilho (Q-04). |
| 1.3 | 10/09/2026 | furiossam@hotmail.com | Definido o gatilho de respawn como baseado em tempo (RN-22), adicionado o campo `Room.enemyDefeatedAt` e substituída a questão sobre o gatilho (Q-04) pela questão sobre o valor do intervalo (Q-05). |
| 1.4 | 10/09/2026 | furiossam@hotmail.com | Definido que o intervalo de respawn (RN-22) escala com o poder do inimigo (RN-16); Q-05 ajustada para tratar da fórmula e dos valores exatos dessa escala. |
| 1.5 | 10/09/2026 | furiossam@hotmail.com | Definida a fórmula do intervalo de respawn como power score (soma ponderada dos atributos efetivos do `Enemy` e `maxHealth`), com parâmetros em `data/respawn.json` (RN-22); termo "Power score" incluído no glossário (§1.3); Q-05 encerrada. |
| 1.6 | 11/09/2026 | furiossam@hotmail.com | Geração de masmorra redefinida para usar autômato celular: `DungeonMap` ganhou `width`/`height`, `Room` ganhou `x`/`y` e o tipo `WALL`; a grade passou a ser densa (toda célula é uma `Room`, inclusive paredes) e `connectedRoomIds` passou a ser calculado a partir da adjacência ortogonal de células andáveis. O parâmetro de geração `roomCount` (RF-10, endpoint `/api/dungeon/generate`) foi substituído por `width`/`height`, já que a quantidade de salas é emergente do algoritmo. Adicionados `Room.fromJson`/`DungeonMap.fromJson` no app (resolve PEND-05). Termo "Autômato Celular" incluído no glossário (§1.3); nova questão em aberto Q-06 sobre os parâmetros de suavização do algoritmo. |
| 1.7 | 14/09/2026 | furiossam@hotmail.com | Autômato celular implementado em `RandomMapGenerator` (RF-10 a RF-13): preenchimento ponderado (45% parede), suavização por 4 iterações com regra B678/S345678, isolamento da maior região andável por flood fill, entrada/saída nos pontos mais distantes por BFS e `connectedRoomIds` calculado por adjacência ortogonal; determinismo garantido reutilizando a seed (RF-11); tentativas com seed derivada se a região ficar pequena demais. Endpoint `/api/dungeon/generate` passou a aceitar `seed` opcional (resolve PEND-06); `ApiClient.generateDungeon` do app acompanhou a mudança. Adicionado `RandomMapGeneratorTest` (determinismo, densidade da grade, caminho entrada→saída, ausência de conexão com `WALL`), cobrindo RNF-20/RNF-22. Resolvidas PEND-07 e Q-06 (parâmetros do autômato documentados como constantes, migração para arquivo de dados adiada). Classificação de salas `LOOT`/`ENEMY` ainda não popula conteúdo real (RF-14, RF-15 seguem pendentes). |
| 1.8 | 14/09/2026 | furiossam@hotmail.com | Corrigidos os quatro contratos divergentes entre backend e app (PEND-01 a PEND-04): `data/affixes.json` passou a usar raridades válidas do enum `Rarity` (`RARO`→`LENDARIO`, `ÉPICO`→`MITICO`, `LENDÁRIO`→`DIVINO`), com guarda de regressão em `AffixesJsonTest`; `Attributes` do app ganhou `defense`/`intelligence`; `CombatEvent.fromJson` do app passou a converter o nome do enum de `SCREAMING_SNAKE_CASE` (formato serializado pelo Java) para o `lowerCamelCase` do enum Dart antes de resolvê-lo; `Item` do app ganhou `baseStats`. Adicionados testes de modelo no app (`test/core/models/model_contracts_test.dart`) cobrindo os quatro casos. Nenhuma mudança de comportamento visível ainda — os módulos que consomem esses contratos (loot, ficha de atributos, log de combate) continuam pendentes; esta versão apenas remove os bloqueios de integração. |
| 1.9 | 14/09/2026 | furiossam@hotmail.com | `DungeonMapScreen` implementada de ponta a ponta (RF-18): busca o mapa via `ApiClient.generateDungeon` (com campo de seed opcional na própria tela), renderiza a grade `width`×`height` com cores por `RoomType`, legenda, sala atual destacada, salas visitadas e adjacentes não exploradas, fog of war sobre o conteúdo (LOOT/ENEMY) de salas ainda não visitadas, e permite mover entre salas conectadas tocando na célula (validação de conectividade e mensagem de erro para movimento inválido, RN-15) — movimento e "visitadas" são geridos **apenas no cliente** por enquanto, já que não há sessão/endpoint de movimento no backend ainda (RF-16/RF-17 permanecem parciais). Erros de rede tratados com mensagem amigável + retry (mitiga PEND-09 na tela, RNF-06). Testado ao vivo no Chrome via `flutter run -d web-server`, o que revelou e motivou a correção de PEND-12 (CORS: backend não liberava `/api/**` para a origem do app web; `WebConfig` adicionado restringindo a `localhost`/`127.0.0.1`, RNF-24). Adicionados testes de widget (`test/features/dungeon_map/dungeon_map_screen_test.dart`): carregamento, movimento válido, movimento inválido, erro de rede. |
| 2.0 | 14/09/2026 | furiossam@hotmail.com | Cadeia completa sessão → movimento → combate → loot implementada no backend (RF-01 a RF-04, RF-14 a RF-17, RF-20 a RF-23, RF-25 a RF-27, RF-30 a RF-36, RF-42 a RF-44), testável por HTTP e coberta por 52 testes automatizados (`SpeedBasedCombatResolverTest`, `EnemyFactoryTest`, `RandomLootGeneratorTest`, `SessionControllerTest`). `Character` ganhou vida (`currentHealth`/`maxHealth`, RN-11); `GameSession` ganhou estado mutável (`currentRoomId`, `visitedRoomIds`, `depth`); novos `EnemyFactory`, `AffixTable`, `DungeonPopulator`, `SessionController` e `ApiExceptionHandler`. **Decisão deliberada**: RF-24 (WebSocket) não foi implementada — `POST /api/session/{id}/move` resolve o combate de forma síncrona e devolve os `CombatEvent` na própria resposta HTTP (novo PEND-13); `CombatSocketHandler` continua stub. Fórmulas sem valor definido nos requisitos (vida máxima, chance de crítico, escala de inimigo por profundidade, XP/loot na vitória, raridade por profundidade, quantidade de afixos) documentadas como valores assumidos em §4.1, sujeitos a balanceamento. Encontrado e corrigido durante o desenvolvimento: inimigos escalavam a partir de `5+depth` (mais fortes que o personagem já no andar 1) — ajustado para `5+(depth-1)`; e um bug onde `move()` salvava a sessão de volta incondicionalmente após o combate, ressuscitando sessões que `fight()` já tinha removido por morte em HARDCORE (RF-44) — coberto por `derrotaEmHardcoreEncerraASessao`. Telas Flutter de Combate/Inventário/Personagem continuam fora de escopo (decidido com o usuário); `DungeonMapScreen` não foi conectada à nova sessão do backend. Novo PEND-14 documentando que `Enemy.currentHealth()` não reflete dano parcial entre combates (sem impacto funcional nesta versão). |
| 2.1 | 14/09/2026 | furiossam@hotmail.com | App Flutter conectado à cadeia sessão → mapa → combate → loot do backend (RF-01, RF-02, RF-09, RF-16 a RF-18, RF-25 a RF-27 (consumo), RF-28, RF-29, RF-35, RF-36, RF-40, RF-42, RF-44). Novo `core/game/game_controller.dart` (`ChangeNotifier` simples, sem lib de state management nova) compartilhado entre as telas via construtor. `DungeonMapScreen` reescrita para usar a sessão real em vez da simulação local antiga; `CombatScreen`, `InventoryScreen`, `CharacterScreen` saíram de placeholders "TODO" para telas reais; `HomeScreen` ganhou um diálogo "Nova run" (nome/modo/seed) que cria a sessão antes de navegar, mantendo os 4 botões sempre visíveis (nenhuma mudança no `widget_test.dart` original). Como o backend resolve o combate de uma vez só (PEND-13), `CombatScreen` simula a sensação de tempo real revelando os eventos um a um no cliente (RF-28/RF-29). Pequeno ajuste no backend: `Character.maxHealth()` é um método calculado e não aparecia no JSON por padrão do Jackson (só `getX`/`isX` são detectados automaticamente) — `@JsonProperty("maxHealth")` adicionado, com teste de regressão. Bug pego e corrigido durante o teste manual no Chrome: `CombatScreen._skip()` não cancelava o timer da revelação já agendado, deixando um pendente (`Future.delayed` recursivo trocado por `Timer` cancelável). Novo PEND-15: `ApiClient.generateDungeon` e `combat_socket_client.dart` ficaram sem chamador na UI (mantidos deliberadamente). Testado manualmente de ponta a ponta no Chrome: criar sessão → mover → combater (vitória com loot/XP reais e derrota com reset a NORMAL) → conferir inventário e ficha. 23 testes automatizados no app (modelos, `DungeonMapScreen`, `CombatScreen`, `InventoryScreen`, `CharacterScreen`, `HomeScreen`), 52 no backend. |
| 2.2 | 14/09/2026 | furiossam@hotmail.com | **Somente documentação** — nenhum código alterado. A pedido do usuário após testar o app manualmente, definido o módulo de equipamento (novo §3.8: RF-56 tela de equipar por arraste, RF-57 navegação global entre Mapa/Combate/Inventário/Personagem) e as regras que o sustentam: RN-23 (oito slots — `HEAD`, `CHEST`, `LEGS`, `FEET`, `HAND_LEFT`, `HAND_RIGHT`, `ACCESSORY_1`, `ACCESSORY_2`), RN-24 (sete categorias de equipamento por `baseType`, compatibilidade item↔slot) e RN-25 (as duas mãos aceitam arma ou escudo independentemente, qualquer combinação vale — arma+escudo, arma+arma ou escudo+escudo). RF-37 e RF-38 (equipar/desequipar) reescritos para referenciar os slots concretos; UC-04 ganhou os passos de arraste e os fluxos alternativos de slot incompatível e de trocar só uma mão. `Character.equipped` e `Item.baseType` anotados no dicionário de dados (§7) como pendentes de migrar de `String` genérica para os enums `Slot`/categoria. Novo Q-07 em aberto: duas armas equipadas concedem ataque extra ou só empilham atributos via RF-08 (ainda não implementado)? Achado durante a especificação: o catálogo de `baseType` (`DungeonPopulator.ITEM_BASE_TYPES`) não tem nenhum tipo `LEG_ARMOR` nem `SHIELD` — anotado em RN-24, a resolver na implementação. Implementação completa (backend + tela de arraste + navegação global) fica para uma rodada futura, planejada à parte. |
| 2.3 | 15/09/2026 | furiossam@hotmail.com | Módulo de equipamento e navegação (§3.8, definido em v2.2) implementado de ponta a ponta. **Backend**: novo enum `character/Slot.java` (oito posições); `item/EquipmentCategory.java` (sete categorias, com `compatibleSlots()`); `item/ItemCatalog.java` (tabela estática `baseType → EquipmentCategory`, taxonomia fixa — não é dado de balanceamento, então não segue o padrão `AffixTable`/RNF-16); `character/InvalidEquipException.java` → 400 em `ApiExceptionHandler`; `Character.equipped` migrado de `Map<String,Item>` para `Map<Slot,Item>` (mesmo formato no JSON, sem quebra de contrato); novos métodos `Character.equip`/`unequip`/`effectiveAttributes()` (RF-08 — soma só modificadores de afixo cujo nome bate com um campo de `Attributes`, ignorando `damage`/`durability`/etc.); novos endpoints `POST /api/session/{id}/equip`/`unequip` em `SessionController`, devolvendo a sessão completa (mesmo padrão de `move`/`loot`); `DungeonPopulator.ITEM_BASE_TYPES` ganhou `calca` (LEG_ARMOR) e `escudo` (SHIELD), que faltavam no catálogo (RN-24). 13 novos testes (`CharacterTest` + `SessionControllerTest`), 66 no total. **App**: `core/models/equipment_category.dart` (tabela client-side só para destaque visual no arraste — RF-56 —, nunca autoritativa, RN-13); `features/character/equipment_slots.dart` (oito `DragTarget<Item>`, destaque verde/vermelho); `CharacterScreen` ganhou painel de inventário arrastável, tabela de atributos base×efetivo (RF-08/RF-09) e diálogo de comparação por toque longo (RF-41); novo `features/shell/game_shell.dart` (RF-57 — `NavigationBar` + `IndexedStack` com as quatro telas vivas simultaneamente sob o mesmo `GameController`, substituindo a navegação por `Navigator.push` isolado a partir da Home); `DungeonMapScreen`/`CombatScreen` ganharam `onCombatTriggered`/`onFinished` opcionais para o shell controlar a troca de aba sem quebrar o uso standalone dessas telas (preservado para os testes existentes). **Bug pego e corrigido durante o teste manual no Chrome**: como o `IndexedStack` do shell mantém `CombatScreen` viva entre lutas (ao contrário do `Navigator.push` antigo, que recriava a tela a cada combate), a animação de revelação (que só dispara em `initState`) não reiniciava numa segunda luta na mesma visita ao shell — corrigido com `key: ValueKey(controller.lastCombatEvents)`, que força o Flutter a recriar o estado a cada novo combate (identidade da lista muda a cada luta). Testado manualmente de ponta a ponta no Chrome (`flutter run -d web-server` + backend em JDK 21): criar sessão → coletar item → arrastar até slot compatível/incompatível → desequipar → alternar abas sem perder estado → duas lutas seguidas no mesmo shell (confirma o fix acima) → morte em modo NORMAL preserva equipamento. 33 testes automatizados no app (10 novos: equip/slots/comparação em `character_screen_test.dart`, `onFinished` em `combat_screen_test.dart`, `onCombatTriggered` em `dungeon_map_screen_test.dart`, `game_shell_test.dart` novo, navegação entre abas em `home_screen_test.dart`). Nenhuma dependência nova (Flutter `Draggable`/`DragTarget` e Material 3 `NavigationBar` já disponíveis). Combate continua usando atributos base, não efetivos — decisão deliberada (Q-07 atualizada). |
| 2.4 | 15/09/2026 | furiossam@hotmail.com | **Somente documentação** — nenhum código alterado. A partir de feedback do usuário jogando manualmente a v2.3 (§3.8 recém-implementado): (1) o inimigo do andar 1 nasce com os mesmos atributos do personagem, tornando a primeira luta uma questão de sorte — RN-16 revisada (inimigo nasce mais fraco, só alcança a força "de equilíbrio" atual no andar 5; fórmula em §4.1) e a "Nota de balanceamento observada" atualizada confirmando o problema em produção; (2) equipar item não muda o combate — Q-07 resolvida (empunhar duas armas só acumula atributos via atributos efetivos, sem ação extra) e formalizada como RN-26 nova (`SpeedBasedCombatResolver` deve passar a usar `effectiveAttributes()`, não `attributes()`); (3) pedido novo de ícone por categoria de equipamento e selo de cor por tipo de afixo — novas RF-58 (ícone, Desejável) e RF-59 (selo de cor, Desejável) em §3.4, com a tabela de cores por afixo em RN-27 nova (`damage`→vermelho, `durability`→marrom, `fireDamage`→laranja, `speed`→ciano, `defense`→azul-aço, `magicPower`→roxo, `holyDamage`→dourado, `darkDamage`→roxo-escuro) e duas questões em aberto novas (Q-08: onde o selo aparece; Q-09: quais ícones do Material Design existem de fato para cada categoria — a confirmar na implementação). Novo item "5.6" em §10.3 com prioridade alta para RN-26/RN-16 (jogabilidade central) e baixa para RF-58/RF-59 (cosmético). Implementação de tudo isto fica para uma rodada futura. |
| 2.5 | 15/09/2026 | furiossam@hotmail.com | Os três itens definidos em v2.4 implementados. **Backend**: `EnemyFactory` revisado (RN-16) — `MIN_ATTRIBUTE=2` no andar 1, sobe linearmente até `BASE_ATTRIBUTE=5` no `EASE_IN_DEPTH=5`, cresce como antes daí em diante; `SpeedBasedCombatResolver` passou a calcular `player.effectiveAttributes()` uma vez no início de `resolve()` e usá-lo em todo o cálculo do lado do jogador (RN-26) — resolve Q-07 (sem ação extra por empunhar duas armas). 10 novos testes (4 em `EnemyFactoryTest` para o novo formato de escalonamento, 1 em `SpeedBasedCombatResolverTest` provando que um item com bônus grande vira uma derrota certa em vitória), 71 no total. **Achado durante a implementação**: `SessionControllerTest.derrotaEmHardcoreEncerraASessao` dependia de uma seed de sorte pra achar uma derrota logo na entrada — com o inimigo do andar 1 bem mais fraco isso ficou estatisticamente quase impossível (o inimigo praticamente não consegue mais vencer sozinho no andar 1); o helper `fightUntilHardcoreLoss` foi reescrito para explorar o mapa inteiro por DFS, lutando contra todo inimigo encontrado, até o dano residual (sem cura entre lutas) acumular o suficiente — achado e corrigido no processo: o primeiro DFS não *movia de volta* o personagem no servidor ao retroceder (só atualizava a pilha local), violando RN-15 e devolvendo 400; corrigido movendo de fato a cada passo, inclusive nos retrocessos. **App**: novo `core/models/affix_colors.dart` (`primaryAffixColor`, RN-27, com ordem de prioridade de desempate); `equipment_category.dart` ganhou `iconForBaseType` (RF-58) com os sete ícones confirmados em `icons.dart` do SDK Flutter antes do uso (Q-09); `rarity_colors.dart` novo (extraído de `inventory_screen.dart` pra reuso em `CharacterScreen`); `InventoryScreen`, `CharacterScreen` (`_itemChip`, `EquipmentSlots`) ganharam o ícone e o selo de afixo (RF-59, Q-08 resolvida a favor de aparecer em todo lugar que mostra o item). **Bug visual pego e corrigido em teste manual no Chrome**: o ícone tingido com a cor de raridade ficava praticamente invisível pra raridades claras (Normal é quase branco) contra o fundo claro do app — corrigido deixando o ícone em cor neutra e movendo a cor de raridade pra um selo circular com contorno sutil, redundante com o selo de afixo. Testado manualmente de ponta a ponta no Chrome: combate contra o inimigo do andar 1 (personagem levou só 3 de dano até vencer, confirmando RN-16), coleta e equipar item (ícone e selo visíveis e legíveis). 33 testes no app continuam passando (nenhum teste novo de app nesta rodada — mudança puramente visual, já coberta pelos testes existentes de renderização das telas). |
| 2.6 | 15/09/2026 | furiossam@hotmail.com | RF-19 (avançar de andar) implementado de ponta a ponta. **Backend**: `GameSession.dungeonMap`/`depth` deixaram de ser `final`; novo `GameSession.descendTo(DungeonMap)` — troca o mapa, incrementa a profundidade, reposiciona na entrada e **limpa `visitedRoomIds`** (ids de sala são posicionais `"x,y"` e se repetem entre andares, então o progresso do andar anterior não pode vazar como "visitado" no novo); novo endpoint `POST /api/session/{id}/descend`, exigindo o personagem na sala `EXIT` (400 via `InvalidDescendException` caso contrário), com seed do novo andar derivada da seed atual e da nova profundidade (mesmo padrão de `DungeonPopulator`, preserva RN-12/RN-13 sem depender de seed do cliente). Ação **explícita** do jogador (não automática ao entrar na sala EXIT) — mesmo padrão de RF-35 (loot), já que a redação de RF-19 usa "permitir", não "automaticamente" como RF-20. 2 novos testes de integração (BFS até a sala EXIT via HTTP, e o caso de 400 fora dela), 73 no total. **App**: `ApiClient.descend`/`GameController.descend`; `DungeonMapScreen` ganhou um botão "Descer" visível só na sala EXIT. Testado manualmente de ponta a ponta no Chrome: personagem levado da entrada até a sala EXIT (6 combates no caminho), botão "Descer" acionado, profundidade foi de 1 para 2 com mapa totalmente novo e vida preservada. |
| 2.7 | 15/09/2026 | furiossam@hotmail.com | RF-06 (level up) e RF-07 (distribuir pontos de atributo) implementados de ponta a ponta. **Backend**: `Character.gainExperience` passou a subir de nível em loop enquanto o saldo atingir `xpToNextLevel()` (`100 × nível`, RN-28 nova — um ganho grande de XP pode subir mais de um nível de uma vez); cada level up soma 3 pontos de atributo (RN-29 nova) a `unspentAttributePoints` e soma ao HP atual só o ganho de HP máximo daquele nível (10) — **não** um heal completo. Novo enum `AttributeType`, `Character.allocateAttributePoint`, `InvalidAttributeAllocationException` → 400; novo endpoint `POST /api/session/{id}/character/attributes`. 9 novos testes (6 unitários em `CharacterTest`, 3 de integração em `SessionControllerTest`), 82 no total. **Decisão revertida durante a implementação**: a primeira versão curava o personagem por completo a cada level up: quebrou `derrotaEmHardcoreEncerraASessao` (o DFS pelo mapa inteiro acumulando dano parou de conseguir matar o personagem, porque os heals periódicos por level up resetavam o dano mais rápido do que ele acumulava) — trocado para somar só o delta de HP máximo do nível, preservando o dano sofrido antes. **App**: `Character.unspentAttributePoints`; `CharacterScreen` ganhou o aviso de pontos disponíveis e um botão "+" por atributo. **Achado durante os testes de widget**: adicionar a terceira coluna (o botão) à tabela de atributos empurrou a seção de equipamento para fora da área que o `SliverList` do `ListView` materializa por padrão em `flutter test` (800×600) — três testes existentes passaram a falhar silenciosamente (sem exceção, o widget simplesmente não existe na árvore); corrigido encolhendo o botão (`iconSize`, `visualDensity: VisualDensity.compact`) e trocando `dragUntilVisible` por `tester.ensureVisible` onde necessário. Testado manualmente de ponta a ponta no Chrome (seed 41, mesmo caminho de 6 combates até a sala EXIT de v2.6): personagem chegou ao nível 2 com 8 XP e 3 pontos disponíveis, "+" em Força aplicado com sucesso (5→6, saldo 3→2). |
| 2.8 | 15/09/2026 | furiossam@hotmail.com | **Somente documentação** — nenhum código alterado. A pedido do usuário, levantado o requisito de persistência local de personagem por nome: novo §3.9 (RF-60 a RF-65 — salvar automaticamente a cada mutação, consultar/retomar/substituir save por nome, apagar save na morte em HARDCORE) e RN-30 a RN-32 (nome como identificador único do save independente do modo; persistência reside só no backend, nunca no cliente, preservando RN-13; save apagado junto com a sessão na morte HARDCORE, RN-01). Decisões fechadas com o usuário via pergunta direta antes de redigir: persistência no backend (não no app), save da sessão completa (não só do personagem — "continuar" restaura mapa/sala/andar exatos), save apagado na morte HARDCORE, nome único no geral (não por modo). PR-06 revisada (§2.4): o estado deixa de ser volátil de forma geral, já que todo personagem tem nome obrigatório e toda sessão passa a ser salva por nome. RF-01 anotado como não conforme a RN-30 ainda (aceita nomes repetidos livremente). UC-01 ganhou o fluxo alternativo 5a (nome já salvo → continuar/nova jornada mantendo progresso/nova jornada do zero); novo UC-08 (Continuar jornada salva). §8.2 ganhou os três endpoints previstos (`GET /api/characters/{name}/save`, `POST /api/characters/{name}/continue`, revisão de `POST /api/session` com `keepProgress`/`overwrite`). §11 (Fora de escopo) ajustada — persistência em nuvem/múltiplos saves por nome continuam fora, mas o save local por nome deixou de estar 100% fora de escopo. Duas questões novas em §12: Q-10 (mecanismo de armazenamento exato — arquivo por nome vs. banco embutido — e normalização do nome como chave) e Q-11 (o que fazer com um save corrompido, dado que RN-30 permite só um save por nome). Nada implementado ainda — fica para uma rodada futura. |
