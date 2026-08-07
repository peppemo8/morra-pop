# Cowboy Runner (Godot)

Template runner 3D stile Temple Run in Godot 4.

## Cosa include

- Selezione personaggio (3 cowboy)
- Runner a 3 corsie
- Stato cavallo / corsa a piedi
- Skill fuoco (10s): velocita + distruzione ostacoli
- Skill unicorno volante (10s): volo e superamento ostacoli
- Sistema vite (max 5)
- Frase `GALOPPO` da completare con lettere per guadagnare vite
- Quando arrivi a 1 vita perdi il cavallo e corri a piedi
- Se torni a 2+ vite e trovi token cavallo risali in sella

## Avvio

1. Apri Godot 4.x.
2. Importa la cartella `godot-runner`.
3. Apri il progetto e premi Play.

## Controlli

- Tap/click sinistra: corsia sinistra
- Tap/click destra: corsia destra
- Tastiera: frecce sinistra/destra
- Invio: restart (game over)

## File principali

- `project.godot`
- `scenes/Main.tscn`
- `scripts/main.gd`
