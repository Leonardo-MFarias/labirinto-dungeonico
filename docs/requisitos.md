# Documento de Requisitos — Labirinto Dungeônico

| Campo | Valor |
|---|---|
| Projeto | Labirinto Dungeônico |
| Versão do documento | 1.7 |
| Data | 14/09/2026 |
| Status | Baseline inicial (esqueleto implementado) |
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
| PR-06 | Nesta versão o estado é volátil: reiniciar o backend descarta todas as sessões. |
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
| **RF-01** | O sistema deve permitir criar um personagem informando nome e modo de jogo, gerando um identificador único. | Essencial | Não implementado |
| **RF-02** | O sistema deve permitir ao jogador escolher o modo de jogo (`NORMAL` ou `HARDCORE`) no momento da criação. | Essencial | Modelo pronto (`GameMode`) |
| **RF-03** | O sistema deve atribuir ao personagem os seis atributos base: força, agilidade, vitalidade, velocidade, defesa e inteligência. | Essencial | Modelo pronto (`Attributes`) |
| **RF-04** | O sistema deve permitir consultar a ficha do personagem (nome, nível, experiência, atributos, modo e equipamentos). | Essencial | Não implementado |
| **RF-05** | O sistema deve acumular experiência ao término de combates vencidos. | Essencial | Parcial (`gainExperience` sem curva) |
| **RF-06** | O sistema deve elevar o nível do personagem quando a experiência atingir o limiar da curva de progressão. | Essencial | Não implementado |
| **RF-07** | O sistema deve conceder pontos de atributo a cada nível e permitir que o jogador os distribua. | Importante | Não implementado |
| **RF-08** | O sistema deve calcular os **atributos efetivos** do personagem somando os atributos base aos modificadores dos itens equipados. | Essencial | Não implementado |
| **RF-09** | O aplicativo deve exibir a ficha de atributos e a progressão do personagem. | Essencial | Tela existe, sem conteúdo |

### 3.2 Módulo Masmorra

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-10** | O sistema deve gerar uma masmorra proceduralmente a partir de uma seed numérica e das dimensões `width` × `height` da grade, usando um autômato celular (preenchimento aleatório ponderado seguido de iterações de suavização) para decidir quais células são andáveis. A quantidade final de salas andáveis é uma consequência emergente do algoritmo, não um parâmetro de entrada. | Essencial | Implementado (`RandomMapGenerator`: preenchimento + suavização + flood fill; parâmetros em §12, Q-06) |
| **RF-11** | O sistema deve produzir masmorras idênticas para a mesma seed e as mesmas dimensões de grade (determinismo). | Essencial | Implementado (testado em `RandomMapGeneratorTest`) |
| **RF-12** | O sistema deve isolar, após a suavização, a maior região andável conectada da grade (*flood fill*) e garantir que exista ao menos um caminho da entrada (`ENTRANCE`) até a saída (`EXIT`) dentro dela; células fora dessa região tornam-se `WALL`. | Essencial | Implementado (testado em `RandomMapGeneratorTest`) |
| **RF-13** | O sistema deve classificar cada célula da grade em um dos tipos: `ENTRANCE`, `EMPTY`, `LOOT`, `ENEMY`, `EXIT` (andáveis) ou `WALL` (intransponível, resultado do autômato celular). | Essencial | Implementado (tipo definido na geração; conteúdo de `LOOT`/`ENEMY` ainda não populado — ver RF-14/RF-15) |
| **RF-14** | O sistema deve povoar salas do tipo `ENEMY` com um inimigo cuja força escale com a profundidade da masmorra. | Essencial | Não implementado |
| **RF-15** | O sistema deve povoar salas do tipo `LOOT` com um ou mais itens gerados pelo módulo de loot. | Essencial | Não implementado |
| **RF-16** | O sistema deve permitir ao jogador mover-se de uma sala para outra **somente** se houver conexão direta entre elas. | Essencial | Não implementado |
| **RF-17** | O sistema deve registrar quais salas já foram visitadas na sessão. | Importante | Não implementado |
| **RF-18** | O aplicativo deve exibir o mapa da masmorra em grade `width` × `height` (usando `Room.x`/`Room.y`), com as células `WALL` sempre visíveis como contorno, destacando a sala atual, as visitadas e as adjacentes não exploradas (*fog of war* apenas sobre o conteúdo — item/inimigo — das salas andáveis ainda não visitadas). | Essencial | Tela existe, sem conteúdo |
| **RF-19** | O sistema deve permitir avançar para um novo andar ao alcançar a sala `EXIT`, gerando uma nova masmorra com profundidade incrementada. | Importante | Não implementado |

### 3.3 Módulo Combate

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-20** | O sistema deve iniciar um combate automaticamente quando o personagem entrar em uma sala do tipo `ENEMY` que ainda contenha um inimigo vivo. | Essencial | Não implementado |
| **RF-21** | O sistema deve resolver o combate em ticks, concedendo a ação ao combatente conforme o atributo `speed` de cada lado (modelo ATB). | Essencial | Stub (`SpeedBasedCombatResolver`) |
| **RF-22** | O sistema deve calcular, a cada ação, se ela resulta em acerto normal, acerto crítico ou erro. | Essencial | Não implementado |
| **RF-23** | O sistema deve produzir um evento de combate (`CombatEvent`) para cada ação, contendo tipo, ator, alvo, valor e timestamp. | Essencial | Modelo pronto |
| **RF-24** | O sistema deve transmitir os eventos de combate ao aplicativo pelo WebSocket `/ws/combat`, na ordem em que ocorrem. | Essencial | Handler vazio |
| **RF-25** | O sistema deve encerrar o combate quando um dos combatentes atingir vida zero, emitindo `DEATH` seguido de `COMBAT_END`. | Essencial | Parcial (só `COMBAT_END`) |
| **RF-26** | O sistema deve conceder experiência e loot ao jogador após uma vitória. | Essencial | Não implementado |
| **RF-27** | O sistema deve aplicar a consequência da derrota conforme o modo de jogo (ver RN-01 e RN-02). | Essencial | Não implementado |
| **RF-28** | O aplicativo deve exibir o log de combate em tempo real, com rolagem automática e destaque visual por tipo de evento. | Essencial | Tela existe, sem conteúdo |
| **RF-29** | O aplicativo deve exibir as barras de vida do personagem e do inimigo, atualizadas a cada evento recebido. | Importante | Não implementado |

### 3.4 Módulo Itens e Loot

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-30** | O sistema deve gerar itens com tipo base, `itemLevel`, raridade, atributos base e lista de afixos. | Essencial | Stub (`RandomLootGenerator`) |
| **RF-31** | O sistema deve sortear a raridade do item de forma ponderada pela profundidade da masmorra. | Essencial | Não implementado |
| **RF-32** | O sistema deve carregar a tabela de afixos a partir de `data/affixes.json` na inicialização. | Essencial | Arquivo existe, não é lido |
| **RF-33** | O sistema deve sortear apenas afixos elegíveis, respeitando `minItemLevel` e `minRarity` (ver RN-08). | Essencial | Não implementado |
| **RF-34** | O sistema deve determinar a quantidade de afixos do item conforme sua raridade (ver RN-09). | Essencial | Não implementado |
| **RF-35** | O sistema deve permitir ao jogador coletar itens presentes na sala atual, movendo-os para o inventário. | Essencial | Não implementado |
| **RF-36** | O sistema deve permitir consultar o inventário do personagem. | Essencial | Modelo pronto |
| **RF-37** | O sistema deve permitir equipar um item em um slot, substituindo o item anteriormente equipado, que retorna ao inventário. | Essencial | Modelo pronto (`equipped`) |
| **RF-38** | O sistema deve permitir desequipar um item, devolvendo-o ao inventário. | Essencial | Não implementado |
| **RF-39** | O sistema deve permitir descartar um item do inventário de forma irreversível. | Desejável | Não implementado |
| **RF-40** | O aplicativo deve listar os itens do inventário com nome, raridade (diferenciada por cor) e afixos. | Essencial | Tela existe, sem conteúdo |
| **RF-41** | O aplicativo deve comparar o item selecionado com o item atualmente equipado no mesmo slot, indicando ganho ou perda por atributo. | Desejável | Não implementado |

### 3.5 Módulo Sessão

| ID | Requisito | Prioridade | Situação |
|---|---|---|---|
| **RF-42** | O sistema deve criar uma sessão de jogo associando um personagem a uma masmorra, com identificador único. | Essencial | Modelo pronto (`GameSession`) |
| **RF-43** | O sistema deve permitir recuperar o estado completo de uma sessão pelo seu identificador. | Essencial | Parcial (`SessionService.find`) |
| **RF-44** | O sistema deve encerrar a sessão quando o personagem morrer em modo `HARDCORE`. | Essencial | Não implementado |
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
| **RN-16** | **Escalonamento por profundidade**: a força dos inimigos e a probabilidade de raridades altas crescem monotonicamente com a profundidade. |
| **RN-17** | **Escopo da durabilidade**: apenas itens de categoria "arma" possuem durabilidade nesta versão. Armaduras e acessórios não são afetados. |
| **RN-18** | **Consumo de durabilidade**: cada ataque bem-sucedido (`ATTACK` ou `CRITICAL_HIT`) desferido com a arma equipada reduz sua durabilidade atual em 1 ponto. Golpes que resultam em `MISS` não consomem durabilidade. |
| **RN-19** | **Durabilidade máxima**: o valor máximo de durabilidade é definido pelo `baseType` da arma e pode ser alterado por afixos (ex.: o afixo "Frágil" já presente em `affixes.json` reduz a durabilidade máxima). |
| **RN-20** | **Arma quebrada**: uma arma com durabilidade zero é tratada como quebrada — o dano do golpe passa a usar apenas o piso mínimo definido por RN-06 (equivalente a lutar desarmado), e seus afixos deixam de contribuir para os atributos efetivos (RF-08), até reparo (RN-21) ou substituição do equipamento. |
| **RN-21** | **Reparo**: reparar uma arma restaura sua durabilidade ao valor máximo instantaneamente. *(O custo ou mecanismo de reparo — moeda, material coletável ou reparo gratuito ao retornar à entrada — ainda não está definido; ver §12, Q-01.)* |
| **RN-22** | **Respawn de inimigo (por tempo, escalado por power score)**: um inimigo derrotado reaparece na sala somente após decorrer, no relógio do servidor, um intervalo de tempo desde o momento da derrota. O poder do inimigo que será gerado é expresso por um **power score** — soma ponderada dos seis atributos efetivos do `Enemy` (`strength`, `agility`, `vitality`, `speed`, `defense`, `intelligence`) e de `maxHealth`. O intervalo cresce monotonicamente com o power score: `intervaloRespawn = clamp(intervaloBase + powerScore × fatorEscala, mínimo, máximo)`. Os pesos de cada atributo, `intervaloBase`, `fatorEscala` e os limites mínimo/máximo residem em `data/respawn.json` (mesma convenção de `data/affixes.json`), como parâmetro de balanceamento (RNF-16), não codificado no fonte. O intervalo é contado a partir de `Room.enemyDefeatedAt`; a checagem é feita no momento em que o jogador entra na sala (RF-16), sem processo em segundo plano. Por depender apenas do relógio do servidor (nunca de tempo informado pelo cliente), a regra preserva a autoridade do servidor (RN-13); por não fazer parte da geração da masmorra, não é abrangida pelo determinismo de seed de RN-12. |

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
| **Requisitos** | RF-01, RF-02, RF-03, RF-10, RF-42 |
| **Pré-condições** | Backend disponível; aplicativo configurado com o endereço do servidor. |
| **Pós-condições** | Sessão criada, personagem posicionado na sala `ENTRANCE`. |

**Fluxo principal**

1. O jogador seleciona "Nova run" na tela inicial.
2. O sistema solicita nome e modo de jogo.
3. O jogador informa o nome e escolhe `NORMAL` ou `HARDCORE`.
4. O sistema confirma a escolha de `HARDCORE` explicitamente (RNF-10).
5. O sistema cria o personagem com os atributos iniciais.
6. O sistema gera uma masmorra a partir de uma seed.
7. O sistema cria a sessão associando personagem e masmorra.
8. O sistema posiciona o personagem na sala de entrada e exibe o mapa.

**Fluxos alternativos**

- *4a.* O jogador cancela a confirmação de hardcore → retorna ao passo 3.
- *6a.* Falha na geração da masmorra → o sistema exibe erro e não cria a sessão.

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
| **Requisitos** | RF-30 a RF-41 |
| **Pré-condições** | Sessão ativa; item disponível na sala ou no inventário. |
| **Pós-condições** | Inventário e/ou equipamentos atualizados; atributos efetivos recalculados. |

**Fluxo principal**

1. O jogador entra em sala `LOOT` ou vence um combate.
2. O sistema gera o item: raridade ponderada pela profundidade (RF-31), afixos elegíveis sorteados (RN-08, RN-09).
3. O sistema apresenta o item ao jogador.
4. O jogador coleta o item, que vai para o inventário.
5. O jogador abre o inventário e seleciona um item.
6. O aplicativo compara o item com o equipado no mesmo slot (RF-41).
7. O jogador equipa o item.
8. O sistema devolve o item anterior daquele slot ao inventário e recalcula os atributos efetivos (RF-08).

**Fluxos alternativos**

- *4a.* O jogador ignora o item → o item permanece na sala.
- *7a.* Slot vazio → nenhum item retorna ao inventário.

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
| | `equipped` | Map\<String, Item\> | Slot → item equipado. |
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
| | `baseType` | String | Tipo base (define o slot). |
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
| `GET` | `/api/character/ping` | Sonda do módulo de personagem (provisório). | — |
| `POST` | `/api/dungeon/generate?width={w}&height={h}&seed={s}` | Gera uma masmorra via autômato celular. `width` padrão 40, `height` padrão 25. `seed` opcional; se omitida, deriva do relógio do servidor (não reproduzível). | RF-10, RF-11 |

### 8.2 Endpoints REST previstos

| Método | Caminho | Descrição | Requisito |
|---|---|---|---|
| `POST` | `/api/session` | Cria personagem e sessão. Corpo: `{ name, mode, seed? }`. | RF-01, RF-42 |
| `GET` | `/api/session/{id}` | Retorna o estado completo da sessão. | RF-43 |
| `POST` | `/api/session/{id}/move` | Move para a sala informada. Corpo: `{ roomId }`. | RF-16 |
| `POST` | `/api/session/{id}/descend` | Avança para o próximo andar. | RF-19 |
| `POST` | `/api/session/{id}/loot` | Coleta os itens da sala atual. | RF-35 |
| `POST` | `/api/session/{id}/equip` | Equipa um item. Corpo: `{ itemId, slot }`. | RF-37 |
| `POST` | `/api/session/{id}/unequip` | Desequipa o slot informado. | RF-38 |
| `GET` | `/api/session/{id}/character` | Retorna a ficha do personagem. | RF-04 |
| `POST` | `/api/session/{id}/attributes` | Distribui pontos de atributo. | RF-07 |

### 8.3 Canal WebSocket

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
| RF-04, RF-09 | — | UC-05 | `api/controller/CharacterController.java`, `features/character/character_screen.dart` |
| RF-05, RF-06, RF-07 | RN-11 | UC-03, UC-05 | `character/Character.java` (`gainExperience`) |
| RF-08 | RN-08 | UC-04, UC-05 | *a criar* — serviço de atributos efetivos |
| RF-10, RF-11, RF-12, RF-13 | RN-12, RN-15 | UC-01, UC-06 | `dungeon/MapGenerator.java`, `dungeon/RandomMapGenerator.java`, `dungeon/RoomType.java` |
| RF-14, RF-15 | RN-16 | UC-02 | `dungeon/Room.java`, `combat/Enemy.java` |
| RF-16, RF-17 | RN-15 | UC-02 | `dungeon/Room.java` (`connectedRoomIds`) |
| RF-18 | — | UC-02 | `features/dungeon_map/dungeon_map_screen.dart` |
| RF-19 | RN-16 | UC-06 | `dungeon/MapGenerator.java` |
| RF-20 a RF-23 | RN-05, RN-06, RN-07 | UC-03 | `combat/CombatResolver.java`, `combat/SpeedBasedCombatResolver.java`, `combat/CombatEvent.java` |
| RF-24 | RN-13 | UC-03 | `api/websocket/CombatSocketHandler.java`, `api/config/WebSocketConfig.java`, `core/network/combat_socket_client.dart` |
| RF-25, RF-26, RF-27 | RN-01, RN-02 | UC-03 | `combat/CombatEventType.java` |
| RF-28, RF-29 | — | UC-03 | `features/combat/combat_screen.dart` |
| RF-30, RF-31 | RN-10, RN-16 | UC-04 | `item/LootGenerator.java`, `item/RandomLootGenerator.java`, `item/Rarity.java` |
| RF-32, RF-33, RF-34 | RN-08, RN-09 | UC-04 | `item/Affix.java`, `resources/data/affixes.json` |
| RF-35 a RF-39 | — | UC-04 | `character/Character.java` (`inventory`, `equipped`) |
| RF-40, RF-41 | RN-04 | UC-04 | `features/inventory/inventory_screen.dart` |
| RF-42, RF-43, RF-44 | RN-01, RN-14 | UC-01, UC-03 | `session/GameSession.java`, `session/SessionService.java` |
| RF-45 | — | — | `api/controller/HealthController.java` |
| RF-46 | — | UC-01 | `core/network/api_client.dart` |
| RF-47 a RF-50 | RN-17, RN-18, RN-19, RN-20 | UC-03 | `item/Item.java` (*a estender*), `combat/SpeedBasedCombatResolver.java` (*a estender*) |
| RF-51 | RN-21 | UC-07 | *a criar* — serviço de reparo de itens |
| RF-52, RF-53 | — | UC-07, UC-05 | `features/inventory/inventory_screen.dart`, `features/character/character_screen.dart` |
| RF-54, RF-55 | RN-22, RN-16 | UC-02 | `dungeon/Room.java` (*a estender*), `combat/Enemy.java` |

---

## 10. Situação atual e pendências

### 10.1 Panorama

O repositório contém o **esqueleto arquitetural completo**: os modelos de domínio, as interfaces de extensão (`MapGenerator`, `CombatResolver`, `LootGenerator`), o roteamento REST/WebSocket e as quatro telas do aplicativo. A **geração de masmorra está implementada** (RF-10 a RF-13, via `RandomMapGenerator`, com testes de determinismo e conectividade); as **demais regras seguem pendentes** — marcadas por `// TODO` no fonte. Dos 55 requisitos funcionais, RF-10, RF-11, RF-12, RF-13 e RF-45 estão implementados; cinco têm modelo pronto sem comportamento; os demais estão pendentes — incluindo o módulo de durabilidade de armas (RF-47 a RF-53), que ainda não possui nenhum campo correspondente no modelo `Item` de nenhum dos dois lados (backend e app), e o módulo de respawn de inimigos (RF-54, RF-55), cujo gatilho é por tempo escalado pelo power score do inimigo (RN-22), com pesos e limites a residir em `data/respawn.json`.

### 10.2 Inconsistências identificadas no código atual

Pontos observados durante o levantamento, que exigem decisão antes da implementação:

| ID | Descrição | Impacto |
|---|---|---|
| **PEND-01** | `data/affixes.json` referencia as raridades `RARO`, `ÉPICO` e `LENDÁRIO` (com acento), que **não existem** no enum `Rarity` (`OBSOLETO, ARCAICO, TRIVIAL, NORMAL, COMUM, INCOMUM, LENDARIO, MITICO, DIVINO, ASTRAL`). A desserialização do arquivo falhará. | Bloqueia RF-32. |
| **PEND-02** | `Attributes` do backend possui seis campos; o `Attributes` do app possui apenas quatro (faltam `defense` e `intelligence`). Os contratos divergem. | Bloqueia RF-03, RF-09. |
| **PEND-03** | `CombatEventType` é serializado pelo Java como `CRITICAL_HIT`, mas `CombatEvent.fromJson` no app usa `values.byName(...)` esperando `criticalHit`. A conversão lançará exceção para críticos. | Bloqueia RF-28. |
| **PEND-04** | `Item` do backend possui `baseStats`, campo ausente no `Item.fromJson` do app. | Afeta RF-40, RF-41. |
| ~~PEND-05~~ | ~~`DungeonMap` e `Room` do app não possuem `fromJson`.~~ **Resolvido** (v1.6): `Room.fromJson`/`DungeonMap.fromJson` implementados, incluindo `x`/`y`/`width`/`height`. | — |
| ~~PEND-06~~ | ~~`DungeonController` deriva a seed de `System.currentTimeMillis()` e não a aceita na requisição, impossibilitando reproduzir uma masmorra.~~ **Resolvido** (v1.7): parâmetro `seed` opcional adicionado ao endpoint; cai no relógio do servidor somente se omitido. | — |
| ~~PEND-07~~ | ~~`RandomMapGenerator` ignora os parâmetros `width`/`height` e sempre devolve uma única sala; o autômato celular em si (preenchimento + suavização + *flood fill*) ainda não está implementado.~~ **Resolvido** (v1.7): autômato celular implementado (preenchimento ponderado, suavização B678/S345678, flood fill da maior região, entrada/saída pelos pontos mais distantes por BFS). | — |
| **PEND-08** | `SessionService` mantém as sessões em memória; reiniciar o servidor descarta todo o progresso. | Aceito nesta versão (PR-06). |
| **PEND-09** | `ApiClient.generateDungeon` não trata status diferentes de 200 nem erros de rede. | Conflita com RNF-06. |
| **PEND-10** | `WebSocketConfig` permite qualquer origem (`setAllowedOrigins("*")`). | Conflita com RNF-24. |
| **PEND-11** | Não há testes automatizados além do teste de contexto gerado pelo Spring Initializr. | Conflita com RNF-21. |

### 10.3 Ordem de implementação sugerida

1. **Corrigir os contratos** (PEND-01 a PEND-05) — sem isso nenhuma integração funciona.
2. **Geração de masmorra** (RF-10 a RF-13) com seed explícita (PEND-06, PEND-07).
3. **Sessão e navegação** (RF-42, RF-43, RF-16) — entrega a jogabilidade mínima.
4. **Combate** (RF-20 a RF-28) — o núcleo do jogo.
5. **Loot e inventário** (RF-30 a RF-40).
6. **Durabilidade de armas** (RF-47 a RF-53) — depende do loot já existir.
7. **Progressão** (RF-05 a RF-08).
8. **Andares e escalonamento** (RF-19, RN-16).
9. **Respawn de inimigos** (RF-54, RF-55) — inclui criar `data/respawn.json` com os pesos do power score e os limites do intervalo.

---

## 11. Fora de escopo

Os itens abaixo são **explicitamente excluídos** desta versão. Ficam registrados como evolução possível:

| Item | Justificativa |
|---|---|
| Autenticação e contas de usuário | O produto é single-player sem identidade persistente. |
| Persistência em banco de dados (*save/load*) | Estado volátil é aceitável para validar as mecânicas (PR-06). |
| Multiplayer, cooperativo ou competitivo | Escopo consideravelmente maior; exigiria sincronização de estado e resolução de conflitos. |
| Ranking / placar global | Depende de contas e persistência. |
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
