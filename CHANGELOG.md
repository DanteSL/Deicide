# Histórico de mudanças

## Texturas novas: mármore com veios de ouro, folha de ouro e colunas jônicas

- Texturas enviadas pelo jogador: mármore branco com veios de ouro (paredes, piso, colunas) e folha de ouro
  (trombetas, frisos, portão, estrela do piso). Viraram texturas sem emenda com mapa de relevo, e o mármore usa um
  shader de "ladrilho hexagonal aleatório" (cada pedaço do chão pega uma parte sorteada da foto: a repetição some).
  Os veios de ouro ficam metálicos e brilham.
- Coluna jônica modelada a partir da imagem de inspiração: base com anéis, fuste canelado (24 caneluras, com êntase),
  capitel com óvulos, cordão e volutas em espiral douradas e ábaco.
- Átrio das Trombetas: piso e plataformas no mármore novo, ouro texturizado e uma colunata jônica de 15 colunas em
  volta da praça com arquitrave, friso de ouro e cornija (vão aberto para o lado do portão). A entrada também usa o mármore.
- Gabriel corrompido: o mármore vira uma pintura fluida vermelha, preta e dourada (paleta da imagem enviada, gerada no
  shader, sem marca d'água) que se espalha a partir do Gabriel com uma borda em brasa.
- Trono de Deus: mesmo mármore com veios de ouro e folha de ouro, e as colunas das paredes viraram colunas jônicas.

## Azazel: olhos de verdade nas torres e auréola parada

- Os olhos das torres eram um quadrado com um olho desenhado. Agora são globos oculares 3D numa órbita de pedra:
  íris tirada do olho do próprio Azazel, esclera úmida com veias, brilho molhado e pálpebras que piscam.
- Durante a luta todos os olhos giram e ficam encarando o jogador.
- De tempos em tempos um olho brilha, mira (traço fino) e dispara um raio em você (dois ao mesmo tempo na segunda fase).
- Na segunda fase os olhos ficam injetados de sangue, vermelhos, e choram sangue pela torre.
- A auréola azul atrás do Azazel ficou parada (antes girava).

## Novo chefe: AZAZEL, o Vigia da Tempestade

- Um olho gigante cercado de asas cobertas de olhos, sob uma coroa de anéis (6200 de vida, novo modo no menu).
- Animação por shader no modelo inteiro: as asas batem presas ao corpo (raiz parada, ponta forte, descida rápida e
  subida lenta), as penas compridas de baixo balançam como um véu, o olho central pisca com pálpebra de verdade e os
  olhinhos das asas piscam cada um no seu ritmo. A pupila acende quando ele carrega um raio.
- O olho é o ponto fraco (dano maior), mas fechado ele protege; tiros fortes fazem ele piscar.
- Ataques de raio: Raios do Céu (marcas no chão e o raio cai), Olhar Fulminante (raio direto do olho que se divide no
  chão), Varredura (raio rasteiro varrendo a arena, pule), Descarga (anéis elétricos pelo chão), Gaiola de Raios
  (pilares que fecham em volta de você) e Olhos das Asas (leques de esferas).
- LAMENTO (abaixo de 50%): fecha o olho, treme e abre chorando sangue — fios de sangue escorrem do olho e das asas,
  ele fica avermelhado, os raios ficam vermelhos e ele ataca mais rápido.
- Arena O OLHO DA TEMPESTADE: templo de pedra molhada flutuando sobre nuvens de tempestade, piso de lajes com rejunte,
  poças, três anéis de runas que brilham e um olho em mosaico no centro, oito torres-para-raio de obsidiana com coroas
  de cobre e olhos de pedra que piscam, pilares quebrados, ilhas de rocha flutuando, chuva e relâmpagos ao longe que
  iluminam as nuvens. No Lamento a tempestade vira sangue: céu vermelho, chuva de sangue, runas e juntas cheias de
  sangue, e os olhos das torres choram.
- Barra de vida própria com ornamento de olho que pisca (e chora na segunda fase).

## Portão do céu e Gabriel corrompido

- Portão novo na entrada do Gabriel, inspirado nos portões do céu: pares de colunas brancas caneladas com capitéis
  coríntios dourados, entablamentos com friso de ouro, arco duplo dourado com brasão radiante e coroa, folhas de grade
  em forma de harpa com arabescos, anjos no topo das colunas, dois anjos voando e nuvens na base.
- O portão agora é aberto (sem parede atrás): pelo vão dá para ver o Átrio das Trombetas lá no fundo, ligado por uma
  ponte de mármore e nuvens. A entrada foi aproximada da arena e a névoa ficou mais longa.
- Átrio das Trombetas angelical: céu azul claro, mármore branco, ouro, feixes de luz descendo e estátuas de anjo nas plataformas.
- Na metade da vida o Gabriel se corrompe (fica cor de sangue, olhos vermelhos) e o céu vira inferno: mármore cor de sangue,
  ouro escurecido, nuvens e céu vermelhos, fogo saindo das trombetas, chuva de sangue, poças de sangue se espalhando,
  sangue escorrendo das plataformas e corpos de anjos caídos jogados pela arena. Ao renascer, a arena volta a ser celestial.

## Entrada do Gabriel: degraus da praça, anjos chorando sangue

- Os três degraus da chegada (entre os braseiros verdes) também ganharam rampa de colisão: dá para subir andando.
- As estátuas de anjo choram sangue: dois fios escorrem dos olhos pelo rosto até o pescoço e pingam no pedestal.
- Removidas as placas vermelhas (antigas "asas") que ficavam atrás das estátuas.

## Escadas sem pulo e anjos novos na entrada do Gabriel

- Escadaria do Pórtico da Balança (entrada do Gabriel): cada degrau tinha 40 cm e o jogador só sobe ~35 cm sozinho,
  então era preciso ir pulando. Agora há uma rampa de colisão invisível por cima dos degraus e dá para subir andando.
- Trono de Deus: o altar era feito de blocos de 1,6 m. Ganhou duas escadarias de mármore com frisos dourados
  (20 degraus cada), uma de cada lado do rio de sangue, também com rampa de colisão.
- Os dois anjos ajoelhados da entrada do Gabriel foram trocados por uma estátua de anjo de pé com as asas abertas
  (malha simplificada de ~1 milhão para 70 mil vértices, em mármore fosco).

## Anjo Caído: braço direito separado de vez

- Na caminhada o cotovelo ficava colado na cintura e o antebraço saía do quadril, parecendo grudado na coxa.
  Agora o braço sai do ombro, com o cotovelo afastado do corpo e a mão segurando o cajado na altura do peito.
- Os pontos da junção braço/quadril não misturam mais peso (ou são braço ou são corpo) e as faces que
  fundiam os dois foram cortadas, então não sobra nenhuma "tira" esticada.

## Anjo Caído: braço solto da coxa

- A pele da coxa e a placa do quadril estavam presas ao braço direito (a mão encostava na coxa na pose original)
  e esticavam como uma membrana quando ela movia o braço. Agora ficam presas à perna e ao quadril,
  e as poucas faces que fundiam o braço ao corpo foram cortadas.

## Anjo Caído vira a inimiga padrão

- O Anjo Caído substitui a Ceifadora em todo lugar (ondas, ondas de boss e treino).
- Ajustado para inimigo comum: 90 de vida, golpe de 14 e salto de 18 de dano, salta com menos frequência.

## Nova inimiga: Anjo Caído

- Inimiga de elite com modelo e esqueleto próprios (Mixamo) e três animações feitas no Blender:
  desfile (caminhada de passarela apoiando o cajado no chão a cada passo), ataque com o cajado e salto.
- Comportamento: anda até o jogador, golpeia de perto com o cajado e, de média distância,
  salta até o jogador e crava o cajado no chão (dano em área, poeira, faíscas e tremor de tela).
- 320 de vida; aparece nas ondas a partir da onda 3 (uma a mais a cada 3 ondas) e como alvo no treino.
- Ao morrer, explode em sangue como os outros e rende mais munição de sangue.

## Título novo e menu de pausa transparente

- Menu principal: o título virou só "DEICIDE", sem a descrição embaixo, em letras góticas douradas com brilho de brasa
  pulsando, reflexo passando pelas letras, gotas de sangue escorrendo e um filete com cruz invertida.
- Menu de pausa (ESC) redesenhado: o jogo continua visível atrás, borrado e escurecido com vinheta;
  "PAUSA" no centro com modo, tempo e abates, coluna centralizada entre molduras douradas e cinzas caindo.
  Configurações e controles abrem num painel à direita e a coluna desliza para o lado.
- Animações do menu não travam mais com câmera lenta (ignoram a escala de tempo).

## Lilith mais viva

- Pernas e saia balançam de leve, como quem flutua (cada perna num ritmo, sem rasgar a malha).
- Braços se mexem mais: a mão erguida gira a cruz conjurando, a garra abre e fecha e o braço sobe e desce.
- Asas batem o tempo todo, mais largas e um pouco mais rápidas.
- A cabeça ficou firme e acompanha o jogador (vira e inclina na sua direção, com limite).

## Asas da Lilith presas ao corpo

- As asas deixaram de ser peças soltas giradas (que pareciam flutuar e levavam junto pedaços de fumaça e enfeites).
  Agora fazem parte do corpo e um shader dobra os vértices das costas: nada se mexe na raiz, a ponta bate mais forte,
  para trás e para a frente e subindo/descendo; recolhidas, ficam para trás.

## Chão de lava na arena da Lilith

- O lago em volta da ilha (e as cachoeiras das paredes) usam a textura de lava derretida enviada pelo autor:
  duas camadas correndo em direções diferentes, distorcidas por ruído, com brilho pulsando e mais quentes no Inferno.
- O chão da ilha, os rochedos e a base do trono usam a textura de rocha de lava enviada pelo autor (tornada contínua para repetir sem emendas).
- Um shader próprio faz as rachaduras vermelhas da textura brilharem e pulsarem; no Inferno elas ficam muito mais fortes.

## Nova chefe: Lilith, a Rainha do Abismo

- Modelo enviado pelo autor separado em partes (2 asas, 2 braços, cabeça) e animado por código: asas de morcego batendo,
  garra que rasga, braço erguido que conjura, cabeça; flutua em zigue-zague e entra subindo do chão em chamas.
- Visual mais demoníaco: coroa de fogo atrás da cabeça, olhos em brasa, brasas e fumaça, selo de fogo sob os pés.
- 5 800 de vida, sete ataques próprios e a fase **Inferno**. Acertá-la rende um pouco de sangue.
- **Arena própria** (`scripts/lilith_arena.gd`): o Trono do Abismo, ilha num lago de lava animado.
- Entrada **LILITH** no menu e modelo próprio na barra dos chefes (asas de morcego, chifres, olhos e chamas).
- Projéteis inimigos agora podem cair em arco (usado pela Chuva de Enxofre).

## Entrada do Gabriel: o Pórtico da Balança

- No modo **Gabriel** o jogador começa nas ruínas de uma entrada inspirada na arte enviada pelo autor:
  mosaico circular rachado de sangue, balança dourada com águia e gema verde (os pratos balançam),
  escadaria de 6 m com sangue escorrendo, dois blocos de mármore com faixas vermelhas, anjos ajoelhados de espada
  diante de asas vermelhas, selos em ferradura com gemas verdes, braseiros de fogo verde, colunas caneladas
  e um portão dourado em arco com luz do outro lado. Céu e neblina vermelhos.
- O portão abre quando você chega no alto; ao atravessar, um clarão leva ao Átrio das Trombetas e Gabriel aparece.

## Arena do Gabriel: o Átrio das Trombetas

- Nova arena só do Gabriel (`scripts/gabriel_arena.gd`), usada no modo **Gabriel**: praça octogonal de mármore acima das
  nuvens, céu de amanhecer em degradê, sol nascente com raios, mar de nuvens animado e nuvens fofas girando em volta.
- Estrela de 8 pontas e anéis de ouro no chão, estrado central com um sol dourado, balaustrada na borda.
- Oito trombetas gigantes de ouro inclinadas para o céu, com luz dentro da campana (mais forte na segunda fase do Gabriel).
- Quatro plataformas suspensas (5 m e 7 m) com escadas flutuantes, para lutar contra o arcanjo no alto.
- Penas caindo e um olho gigante no céu que segue o jogador e pisca.
- Correção: a arena do Miguel montava as linhas do selo antes de entrar no mundo; agora ficam na direção certa.

## Munição de sangue, cadáveres e jab

- **Revólver de dois canos** (modelo enviado pelo autor) no lugar da pistola.
- **Munição de sangue**: todas as armas de fogo bebem de um reservatório único (máx. 200, começa com 120).
  Recarregar a pistola custa 2 por bala, a escopeta 4 por cartucho; foguete 14, prego 0,7, raio 12, arpão 6, granada 8.
  As espadas e o soco são de graça. Sem sangue: clique seco e aviso "SEM SANGUE".
- Ao estourar, o inimigo solta **gotas de sangue** que voam até você e enchem o reservatório
  (casca 22, bruto 55, drone 12; morte no soco vale 1,5×).
- **Frasco de sangue** na HUD: ampola de vidro com tampa de espinhos e cruz invertida, líquido que balança com o movimento,
  bolhas, gotas caindo pelo gargalo ao coletar e alerta piscando quando acaba. As armas sem pente mostram quantos tiros ainda dá.
- **Mortes**: o corpo inteiro é arremessado longe, quica, escorrega nas paredes deixando manchas e fica caído no mapa
  (até 28 cadáveres); sangue espirra **na tela** e escorre. Novo som de impacto pesado (**porradão**).
- **Soco em jab**: o braço inteiro sobe, estica com o punho fechado, recolhe para a guarda perto do rosto, segura um instante
  e desce. Socar de novo na guarda sai direto de lá.

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
