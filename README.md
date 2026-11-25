# Deicide

FPS frenético no estilo ULTRAKILL, feito em **Godot 4.7** (GDScript).

## Como jogar

1. Instale o [Godot 4.7](https://godotengine.org/download).
2. Abra o Godot → **Importar** → escolha o `project.godot` desta pasta.
3. Aperte **F5**.

## Modos

- **Ondas**: hordas crescentes. A cada 5 ondas aparece **Gabriel** e a cada 10 aparece **Deus**.
- **Treino**: alvos infinitos para testar as armas.
- **Gabriel**: chefe anjo com asas articuladas, 8 ataques e segunda fase.
- **Deus**: chefe colossal com crista de mãos decepadas, cachoeiras de sangue, arena inundada e segunda fase.

## Controles

| Ação | Tecla |
|---|---|
| Mover / pular | WASD / Espaço |
| Dash / deslizar / pancada no chão | Shift / C / C no ar |
| Atirar / especial da arma | Clique esquerdo / direito |
| Trocar arma | Q · 1–8 · roda do mouse |
| Girar / recarregar | R |
| Soco e rebater projéteis | F |
| Terminal de arsenal (perto dele) | E |
| Pausar | ESC |

## Armas

Revólver (ricochete carregado), escopeta (rajada dupla), espadas aladas, lança-foguetes,
pregadora, fuzil de raio, arpão e lança-granadas — cada uma com 3 melhorias no terminal da arena.

## Estrutura

- `scripts/main.gd` — arena, HUD, menus, ondas e terminal
- `scripts/player.gd` — movimento (dash, slide, slam, pulo na parede)
- `scripts/weapons.gd` / `scripts/extra_weapons.gd` — armas em primeira pessoa
- `scripts/enemy.gd` / `scripts/ceifadora.gd` — inimigos (a Ceifadora tem esqueleto animado por código)
- `scripts/gabriel.gd` / `scripts/deus.gd` — chefes
- `scripts/g.gd` — estado global, sons, partículas, salvamento
- `sfx/` — sons e música
