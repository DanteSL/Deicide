<div align="center">

# DEICIDE

**FPS de arena frenético no estilo ULTRAKILL — mate os anjos, depois mate Deus.**

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/linguagem-GDScript-355570)
![Plataforma](https://img.shields.io/badge/plataforma-Windows%20%7C%20Linux%20%7C%20macOS-555)

![Menu do jogo](docs/img/menu.jpg)

</div>

---

## Sobre

*Deicide* é um jogo de tiro em primeira pessoa rápido e violento, feito inteiro em **Godot 4.7** com GDScript.
Você corre, desliza, dá dash, pula nas paredes, gira as armas e devolve projéteis no soco enquanto enfrenta
ondas de servas aladas, os arcanjos **Gabriel** e **Miguel**, a rainha demônio **Lilith** e, por fim, o próprio **Deus** no seu trono de mármore, ouro e sangue.

**Sangue é munição.** Todas as armas de fogo bebem de um único frasco de sangue; cada inimigo que estoura é
arremessado longe, espirra sangue na tela e solta gotas que voam até você para encher o frasco.
Ficar sem sangue obriga a partir para o soco — que também cura e devolve projéteis.
Um ranking de heresia (de Devoto a Supremo Sacrilégio) recompensa variar as armas, acertar na cabeça e aparar ataques, e enche a barra de **Blasfêmia**: cheia, ela para o tempo e executa com raios todos os anjos na tela.

### Os chefes

| | |
|---|---|
| ![Miguel](docs/img/miguel_perto.jpg) | ![Miguel no eclipse](docs/img/miguel_eclipse.jpg) |
| **Miguel**, o Arcanjo Velado: quatro braços, asas cheias de olhos | Abaixo de 50% de vida vem o **Eclipse** e o céu sangra |
| ![Miguel, olhar das asas](docs/img/miguel_olhos.jpg) | ![Miguel, cruz de sangue](docs/img/miguel_cruz.jpg) |
| **Olhar das Asas**: rajadas dos seis olhos (dá para devolver no soco) | **Cruz de Sangue**: gêiseres em cruz sob seus pés |
| ![Lilith](docs/img/lilith.jpg) | ![Lilith, Beijo da Súcubo](docs/img/lilith_beijo.jpg) |
| **Lilith**, a Rainha do Abismo: asas de morcego, coroa de fogo e olhos em brasa | **Beijo da Súcubo**: ela te puxa e explode — dê dash para fora |
| ![Deus no trono](docs/img/deus_trono.jpg) | ![Cutscene de Deus](docs/img/cutscene_deus.jpg) |
| **Deus** espera no alto do altar da Sala do Trono | A cutscene de entrada, com a voz de Deus em língua estranha |
| ![Gabriel](docs/img/gabriel_luta.jpg) | ![Deus, segunda fase](docs/img/deus_fase2.jpg) |
| **Gabriel**, o Arauto de Muitos Olhos, no Átrio das Trombetas | **Deus** na segunda fase: a arena inundada de sangue |

### As arenas

| | |
|---|---|
| ![Pórtico da Balança](docs/img/portico_balanca.jpg) | ![Portão dourado](docs/img/portico_portao.jpg) |
| **Pórtico da Balança** — a entrada do Gabriel: mosaico rachado de sangue, a balança dourada e os anjos de espada | O portão dourado se abre quando você chega e leva ao Átrio |
| ![Átrio das Trombetas](docs/img/gabriel_arena.jpg) | ![Átrio visto de cima](docs/img/gabriel_arena_cima.jpg) |
| **Átrio das Trombetas** — a arena do Gabriel: praça de mármore acima das nuvens, ao amanhecer | Vista de cima: estrela de ouro no chão, 8 trombetas gigantes e plataformas suspensas |
| ![Trono do Abismo](docs/img/lilith_arena.jpg) | ![Inferno](docs/img/lilith_inferno.jpg) |
| **Trono do Abismo** — a arena da Lilith: ilha de rocha num lago de lava, pentagrama invertido e correntes | No **Inferno** (fase 2) a lava sobe e a caverna se acende |
| ![Arena de Miguel](docs/img/miguel.jpg) | ![Sala do Trono](docs/img/sala_do_trono.jpg) |
| **Santuário do Eclipse** — ruínas flutuando no vazio, selo de sangue no chão e um sol negro | **Sala do Trono** — mármore branco, ouro, cachoeiras e um córrego de sangue |
| ![Fontes de sangue](docs/img/fontes_de_sangue.jpg) | ![Barras dos chefes](docs/img/barras_chefes.jpg) |
| As fontes de sangue da Sala do Trono | Cada chefe tem a sua barra de vida (Gabriel, Miguel, Deus) |

### Sangue, armas e soco

| | |
|---|---|
| ![Sangue na tela](docs/img/sangue_na_tela.jpg) | ![Cadáver](docs/img/cadaver.jpg) |
| Inimigo estourado: sangue na tela e o **frasco de sangue** (munição) na HUD | Os corpos são arremessados e ficam no mapa |
| ![Jab](docs/img/jab.jpg) | ![Revólver](docs/img/revolver_recarga.jpg) |
| O **jab**: o braço inteiro estica com o punho fechado | O revólver de dois canos e a recarga com as duas mãos |
| ![Ceifadora](docs/img/ceifadora.jpg) | ![Menu](docs/img/menu.jpg) |
| A **Ceifadora**, com esqueleto animado por código | O menu principal |
| ![Pausa](docs/img/pausa.jpg) | ![Anjo Caído](docs/img/anjo_caido.jpg) |
| O menu de pausa, com o jogo borrado ao fundo | O **Anjo Caído** saltando com o cajado |
| ![Portão](docs/img/portao_ceu.jpg) | ![Gabriel no céu](docs/img/gabriel_ceu.jpg) |
| O portão do céu na entrada do Gabriel | O Átrio das Trombetas angelical |
| ![Gabriel corrompido](docs/img/gabriel_inferno.jpg) | ![Azazel](docs/img/azazel_chora.jpg) |
| Na metade da vida o Gabriel se corrompe e o céu vira inferno | **Azazel** chorando sangue no Lamento |
| ![Arena do Azazel](docs/img/azazel_arena.jpg) | ![Trono](docs/img/trono_marmore.jpg) |
| O Olho da Tempestade: raios caindo nas marcas | O salão do trono em mármore com veios de ouro e colunas jônicas |

## Habilidades dos chefes

![Habilidades](docs/img/habilidades.jpg)

Trombetas do Juízo (Gabriel), Sol Negro e Ceifa Carmesim (Miguel), Inferno e Coroa do Abismo (Lilith),
Mil Olhos e Tempestade Final (Azazel) e Sóis de Sangue (Deus).

## Como jogar

1. Baixe o **[Godot 4.7](https://godotengine.org/download)** (versão padrão, não precisa da .NET).
2. Clone ou baixe este repositório:
   ```bash
   git clone https://github.com/DanteSL/Deicide.git
   ```
3. Abra o Godot → **Importar** → escolha o arquivo `project.godot`.
4. Na primeira abertura o Godot importa modelos e sons (alguns segundos).
5. Aperte **F5**.

## Modos

| Modo | Descrição |
|---|---|
| **Ondas** | Hordas crescentes. A cada 5 ondas aparece Gabriel; a cada 10, Deus. |
| **Treino** | Alvos infinitos para testar armas e melhorias. |
| **Gabriel** | Suba o Pórtico da Balança, atravesse o portão dourado e lute contra o arcanjo no Átrio das Trombetas (8 ataques, segunda fase). |
| **Lilith** | Luta contra a Rainha do Abismo no Trono do Abismo, sobre um lago de lava (7 ataques + Inferno). |
| **Miguel** | Luta contra o Arcanjo Velado na arena dele, o Santuário do Eclipse (7 ataques + Eclipse). |
| **Deus** | Luta direta contra Deus (10 ataques, segunda fase com a arena inundada). |

## Controles

| Ação | Tecla |
|---|---|
| Mover | **W A S D** |
| Pular / pulo na parede | **Espaço** |
| Dash (3 cargas, invencível) | **Shift** |
| Deslizar / pisão no ar | **C** |
| Atirar | **Clique esquerdo** |
| Especial da arma | **Clique direito** |
| Trocar arma | **Q** (anterior) · **1–8** · **roda do mouse** |
| Girar / recarregar (gasta sangue) | **R** |
| Soco (jab) e rebater projéteis | **F** |
| Blasfêmia (com a barra cheia) | **G** |
| Terminal de arsenal (perto dele) | **E** |
| Pausar / configurações | **ESC** |

No menu de pausa dá para ajustar sensibilidade, campo de visão, volume geral, volume da música
e o visual retrô pixelado. Tudo fica salvo.

## Documentação

| Documento | Conteúdo |
|---|---|
| [Jogabilidade](docs/JOGABILIDADE.md) | Movimento, estilo, cura com sangue, aparar projéteis |
| [Armas](docs/ARMAS.md) | As 8 armas, botão direito de cada uma e as 24 melhorias |
| [Inimigos e chefes](docs/INIMIGOS.md) | Servas, brutamontes, drones, Gabriel e Deus — todos os ataques |
| [Arquitetura](docs/ARQUITETURA.md) | Como o código está organizado, como adicionar armas e inimigos, testes |
| [Histórico de mudanças](CHANGELOG.md) | O que foi feito em cada etapa |

## Estrutura do projeto

```
Deicide/
├── project.godot          # configuração do projeto Godot
├── main.tscn              # cena principal (tudo é montado por código)
├── scripts/
│   ├── g.gd               # autoload: estado global, sons, partículas, dano, salvamento
│   ├── main.gd            # arena, HUD, menus, ondas, projéteis, terminal de arsenal
│   ├── player.gd          # movimento e câmera
│   ├── weapons.gd         # revólver, escopeta, soco e troca de armas
│   ├── extra_weapons.gd   # espadas, foguetes, pregadora, raio, arpão e granadas
│   ├── enemy.gd           # inimigos comuns
│   ├── ceifadora.gd       # esqueleto e animação procedural da Ceifadora
│   ├── gabriel.gd         # chefe Gabriel
│   ├── lilith.gd          # chefe Lilith (partes animadas por código, 7 ataques, Inferno)
│   ├── lilith_arena.gd    # Trono do Abismo, a arena da Lilith
│   ├── miguel.gd          # chefe Miguel (partes animadas por código, 7 ataques, Eclipse)
│   ├── miguel_arena.gd    # Santuário do Eclipse, a arena do Miguel
│   ├── gabriel_arena.gd   # Pórtico da Balança (entrada) e Átrio das Trombetas, a arena do Gabriel
│   ├── deus.gd            # chefe Deus
│   ├── trono.gd           # Sala do Trono e cutscene de Deus
│   ├── hud2.gd            # HUD: vida, estamina, dash, arma em 3D, munição e frasco de sangue
│   ├── boss_bar.gd        # barras de vida estilizadas de cada chefe
│   ├── blood_screen.gd    # sangue espirrado na tela
│   ├── gibs.gd            # mortes: cadáveres arremessados, manchas e gotas de sangue (munição)
│   ├── fp_ik.gd           # braços em primeira pessoa: IK, punho fechado, giro da arma
│   └── menu_ui.gd         # menu principal e de pausa
├── gabriel.glb            # modelo do Gabriel (asas em duas partes, auréolas, mãos)
├── gabriel_tex.jpg        # textura do Gabriel
├── ceifadora.glb          # modelo da Ceifadora com esqueleto de 24 ossos
├── deus/                  # modelo animado de Deus, mão decepada e texturas
├── lilith/                # modelo e textura da Lilith
├── miguel/                # modelo e texturas do Arcanjo Miguel
├── maos/                  # braços animados em primeira pessoa
├── revolver/              # revólver de dois canos
├── fonte/                 # fonte de sangue da Sala do Trono
├── anjo/                  # estátua de anjo do corredor
├── fontes_ui/             # fontes de texto (Cinzel, licença OFL)
├── musica/                # trilhas sonoras
├── sfx/                   # efeitos sonoros e música (gerados por código)
└── docs/                  # documentação e imagens
```

## Créditos

- Efeitos de partículas: [Kenney Particle Pack](https://kenney.nl) (CC0).

- Estátuas do corredor da Sala do Trono: modelo **"AngelStatue"**, de Zsky.
- Lilith: modelo enviado pelo autor (`Lilith.zip`, gerado no Tripo).
- Arcanjo Miguel: modelo enviado pelo autor (`Miguel.zip`, gerado no Tripo).
- Fontes da Sala do Trono: modelo de fonte enviado pelo autor (`fonte.zip`).
- Fontes de texto da barra dos chefes: Cinzel e Cinzel Decorative (SIL Open Font License, em `fontes_ui/OFL.txt`).
- Braços do jogador e animação de respiração/pegada: arquivo `fps_test` enviado pelo autor (esqueleto no padrão do manequim da Unreal). Confira a licença do modelo antes de publicar.

- **"Throne of Ash and Gold"** (batalha final contra Deus): composta por DanteSL.

- Design, direção e modelos 3D de origem: **DanteSL**
- Código, animações procedurais, rigging e sons: feitos em conjunto com **Claude** (Anthropic)
- Inspiração: *ULTRAKILL* (New Blood Interactive)
