# Histórico de mudanças

## Novo chefe: Miguel, o Arcanjo Velado

- Modelo enviado pelo autor, reduzido para ~48 mil triângulos e separado em partes (2 asas, 4 braços, cabeça) para animar por código:
  asas batendo e recolhendo, braços com garras se mexendo, cabeça, olhos das asas que acendem, auréola de luz girando.
- 5200 de vida, entrada descendo do céu e um selo de sangue no chão.
- Sete ataques próprios: **Ceifa dos Quatro Braços** (pule), **Olhar das Asas** (rajadas dos olhos, dá para devolver no soco),
  **Cruz de Sangue** (gêiseres em cruz no jogador; na fase 2 também em X), **Corrente de Penitência** (mira, trava e puxa),
  **Passo do Eclipse** (some e esmaga atrás de você), **Rosário de Sangue** (espiral de contas) e **Coroa de Espinhos** (anel que se fecha).
- Abaixo de 50%: **Eclipse** — o céu escurece, a auréola fica vermelha e ele acelera.
- **Arena própria** (`scripts/miguel_arena.gd`): santuário em ruínas no vazio, colunas quebradas, arcos góticos, rochas flutuando e um sol negro.
- Entrada **MIGUEL** no menu e um modelo próprio na barra dos chefes.

## Barra dos chefes e fontes novas

- **Barra dos chefes** redesenhada (`scripts/boss_bar.gd`), com moldura em cápsula, 10 segmentos, pontas curvas,
  rastro de dano e um modelo por chefe:
  - **Deus**: moldura púrpura, espinhos negros abertos, olho coroado com raios dourados e lágrima de sangue,
    sangue pingando da barra.
  - **Gabriel**: moldura de marfim e ouro, asas abertas, auréola e espada descendo pela barra.
  - Nome em Cinzel Decorative com espaçamento e filetes dourados; título abaixo da barra; tremor ao levar dano.
- **Fontes de sangue** da Sala do Trono trocadas pelo modelo enviado pelo autor: mármore e ouro, toda a água vira
  sangue (bacia, cortinas da bacia de cima e o jorro), sem as moedas e sem o piso do modelo.

## HUD nova e recargas com as mãos

- **HUD nova** (`scripts/hud2.gd`): emblema de vida com hexagrama e anel, barra de sangue com rastro de dano,
  estamina contínua com os 3 dashes marcados, losangos de dash, saltos de parede; painel do arsenal com o
  **modelo 3D da arma** girando devagar, munição grande com ícones por tipo, barra de carga/calor, barra de recarga
  e os slots das armas.
- **Pistola** mais baixa e com o cabo dentro das duas mãos.
- **Recarga da pistola**: a mão esquerda solta o pente, busca outro, encaixa por baixo e puxa o ferrolho
  (a arma deita para a esquerda para isso). Sem o giro no fim.
- **Recarga da escopeta**: a arma deita para a direita, a mão esquerda busca cada cartucho e empurra na janela;
  no fim, bombeia (sem o giro no ar).
- Cotovelos sempre para baixo e para fora, e o ombro avança quando a arma está longe.

## Braços animados

- Saiu a mão branca com rachaduras. No lugar entram os braços do arquivo `fps_test` (modelo + animação enviados pelo autor).
- A animação roda em loop (respiração e pegada da pistola) e as mãos seguem a arma por IK de dois ossos (`scripts/fp_ik.gd`):
  pistola com as duas mãos, mão esquerda no cano/bomba nas armas longas, mão pegando cartucho na recarga da escopeta,
  as duas mãos nas espadas aladas e o soco com a mão esquerda.

## Pistola

- A arma 1 agora é uma **pistola** (modelo enviado pelo autor): ferrolho que recua a cada tiro e ejeta cápsulas,
  recarga trocando o pente e puxando o ferrolho. Continua girando e carregando o ricochete.

## Mortes explosivas

- Todo inimigo comum explode em pedaços ao morrer, de qualquer jeito: as peças do corpo voam, giram, quicam e deixam
  manchas de sangue no chão e nas paredes, com carne, ossos e um jato de sangue. O tempo congela como no aparo.

## Configurações de vídeo

- Nova tela de configurações com abas **Vídeo / Jogo / Áudio**: modo de tela (janela, janela sem borda, tela cheia),
  resolução (nativa, 4K, 2K ultrawide, 2K, ultrawide, Full HD, HD…), VSync, limite de FPS, antisserrilhado,
  tamanho da interface, brilho, visual retrô, contador de FPS, inverter mouse e intensidade do tremor de tela.
- Suporte a ultrawide: a imagem abre para os lados (FOV horizontal maior) e a interface escala com a resolução.

## Sala do Trono

- Nova música da batalha final: **Throne of Ash and Gold**, de DanteSL.

- O modo **Deus** agora começa numa antecâmara escura. O portão dourado se abre para a **Sala do Trono**: mármore branco
  e ouro, tapete e rios de sangue, quatro fontes e dez cachoeiras de sangue nas paredes, rosácea e o trono no alto do altar.
- **Cutscene** de entrada (pula com Espaço): Deus fala na língua dele, o Eloráh, com uma voz de 24 pessoas, com legendas.

## Trilha sonora e Blasfêmia

- Trilha sonora própria, sintetizada em código (coral, órgão, sinos e percussão industrial):
  - **Réquiem para um Deus** no menu;
  - **Hosana em Chamas** nas ondas, em duas camadas: o coral toca sempre e a fúria (bateria, baixo e metais)
    entra conforme o rank sobe;
  - **Gloria Sanguinis** para Deus, com a camada de sangue somando na segunda fase.
- Menu principal novo, desenhado em código: auréola quebrada cheia de olhos, raios de luz, cinzas e sangue,
  painel com descrição, perigo e recorde de cada modo, configurações e controles.
- Ranking de heresia (Devoto → Supremo Sacrilégio) e a barra de **Blasfêmia** (tecla G).

## Deicide

- O jogo passa a se chamar **Deicide**.
- Revólver novo no mesmo estilo da escopeta (armação vermelha, cano de aço, detalhes dourados), com tambor
  que gira, cão que bate e recarga bala por bala.
- Barras de **volume geral** e **volume da música** no menu.

## Deus

- Novo chefe colossal com a animação original do modelo, crista de 14 mãos decepadas pingando sangue e 6 ataques.
- Segunda fase: vermelho-sangue, tremedeira, cachoeiras de sangue, arena inundada e 4 ataques novos
  (Lágrimas, Gêiseres, Maré de Sangue, Punhos da Crista).
- Aparece a cada 10 ondas e tem modo próprio no menu.

## Ceifadora

- Novo inimigo corpo a corpo com esqueleto de 24 ossos: andar de passarela com rebolado, asas vivas e
  4 golpes com o cajado-foice.

## Gabriel

- Asas articuladas em dois segmentos, entrada descendo do céu, morte em sequência.
- 4 ataques novos (Investida, Espada do Arcanjo, Selos do Paraíso, Auréola Cortante) e a segunda fase
  "Julgamento Final".

## Arsenal

- 6 armas novas (espadas aladas, lança-foguetes, pregadora, fuzil de raio, arpão e lança-granadas),
  cada uma com botão direito próprio.
- Terminal de arsenal na arena, 24 melhorias, teclas 1–8 e salvamento.

## Base

- Porte da versão de navegador para Godot 4.7: movimento completo, revólver com ricochete carregado,
  escopeta com recarga invertida, soco com aparar, ondas, treino, ranking de estilo e cura com sangue.
