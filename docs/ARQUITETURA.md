# Arquitetura

O projeto é montado quase todo **por código**: a cena `main.tscn` tem só um nó com `scripts/main.gd`, que
cria a arena, as luzes, o HUD, os menus e o jogador. Isso facilita mudar tudo pelo texto, sem editor visual.

## Scripts

| Arquivo | Papel |
|---|---|
| `g.gd` (autoload `G`) | Estado global (modo, estado, inimigos, projéteis, chefe), sons (`G.snd`), partículas (`G.emit`), traçantes, dano (`G.hurt_enemy`, `G.hurt_player`, `G.blast`), estilo, temporizadores de jogo (`G.later`), armas/melhorias e salvamento. |
| `main.gd` | Arena e materiais, dois viewports (mundo e arma em primeira pessoa), HUD, menus, ondas, projéteis inimigos, terminal de arsenal, música e os modos de teste automático. |
| `player.gd` | `CharacterBody3D` do jogador: movimento, dash, deslize, pisão, pulo na parede, câmera e repasse da entrada para as armas. |
| `weapons.gd` | Viewmodel e lógica do revólver, escopeta e soco/aparar; troca de armas, recargas e animações (giro, recuo, balanço). |
| `extra_weapons.gd` | As outras 6 armas: modelos, projéteis no mundo e botão direito de cada uma. |
| `enemy.gd` | Inimigos comuns (`CharacterBody3D`): IA, dano, morte, e a IA corpo a corpo da Ceifadora. |
| `ceifadora.gd` | Esqueleto da Ceifadora animado por código: andar de passarela, asas, poses-chave dos golpes e cinemática inversa dos braços. |
| `gabriel.gd` | Chefe Gabriel: modelo, asas em dois segmentos, máquina de estados dos ataques e efeitos. |
| `deus.gd` | Chefe Deus: animação original tocada em trechos, crista de mãos, fases, sangue/inundação e ataques. |

## Camadas de física

| Camada | Uso |
|---|---|
| 1 | Mundo (chão, paredes, pilares, terminal) |
| 2 | Inimigos (inclusive as áreas de acerto dos chefes) |
| 3 (valor 4) | Jogador |

Os tiros instantâneos usam `PhysicsRayQueryParameters3D` contra as camadas 1 e 2. Os inimigos guardam
uma referência a si mesmos em `set_meta("enemy", self)` na área de acerto.

## Renderização

- Dois `SubViewportContainer`: um para o mundo e outro (fundo transparente, mundo próprio) para a arma em
  primeira pessoa, que nunca atravessa paredes.
- O **visual retrô** reduz a resolução interna (`stretch_shrink = 3`) com filtro *nearest*.
- Texturas da arena são geradas por código e aplicadas em projeção triplanar.

## Tempo e pausa

- `G.later(segundos, função)` agenda ações que só avançam com o jogo rodando (pausar congela tudo).
- O *hitstop* (aparar, abates fortes) usa `Engine.time_scale` com um temporizador que ignora a escala.

## Como adicionar uma arma

1. Em `g.gd`, acrescente a arma em `WEAP` (id, nome, sigla, descrição) e as 3 melhorias em `UPG`.
2. Em `extra_weapons.gd`: monte o modelo em `build()`, trate `fire()`, `alt_press()` e `alt_release()`,
   e a animação em `pose()`.
3. Em `weapons.gd`, acrescente o id em `IDS`.
4. Se quiser um rótulo de abate próprio, acrescente em `G.KILL_LABEL`.

## Como adicionar um inimigo

Inimigos comuns ficam em `enemy.gd` (`setup()` escolhe vida, tamanho e modelo pelo tipo).
Chefes são scripts separados com a mesma "interface" usada pelo resto do jogo:
`alive`, `hp`, `max_hp`, `r`, `h`, `spawn_t`, `is_boss`, `center()`, `is_head(p)`, `take_damage(dmg, src, head)`
e `die(src, head)`. Depois é só criá-lo em `main.gd → spawn_enemy()`.

## Testes automáticos

O jogo tem modos de teste que jogam sozinhos, tiram capturas em `/tmp` e fecham:

```bash
godot --path . -- --autotest=train    # treino: atira, troca armas, abre o terminal
godot --path . -- --autotest=waves    # ondas
godot --path . -- --autotest=boss     # luta contra Gabriel
godot --path . -- --autotest=gab      # força cada ataque de Gabriel, fase 2 e morte
godot --path . -- --autotest=deus     # força cada ataque de Deus, fase 2 e morte
godot --path . -- --autotest=rage     # segunda fase de Deus e os ataques novos
godot --path . -- --autotest=ceif     # Ceifadora andando e cada golpe
godot --path . -- --autotest=gun      # revólver: tiro, recarga, carga e giro
```

Ao terminar, o teste imprime uma linha `... OK ...` no console.

## Origem dos modelos

Os modelos de Gabriel, da Ceifadora e de Deus vieram de modelos 3D enviados pelo autor e foram preparados no
Blender (redução de polígonos, separação de partes, esqueleto e pesos da Ceifadora, crista de mãos de Deus).
Os sons e a música foram sintetizados por código.
