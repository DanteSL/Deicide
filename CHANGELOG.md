# Histórico de mudanças

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
