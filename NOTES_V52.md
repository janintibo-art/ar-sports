# v52 — La Grenouille (0.52.0)

Nouveau jeu : le jeu de la grenouille (jeu de lancer de palets sur un meuble à trous).

- Meuble en bois à 8 trous : grenouille 500, moulin 200, pont 200, cloche 100, chapeau 100, deux tiroirs 50, bac 25. Obstacles décoratifs avec collision derrière certains trous, grenouille animée quand elle avale un palet.
- Palet physique (Jolt) : il colle au bois à l'atterrissage puis glisse et s'arrête ; un trou l'avale si son centre passe dessus à vitesse raisonnable.
- Deux distances : Bar (1,5 m) et Classique (3 m). Modes : contre l'ordi (Gaston, facile / normal / expert), 2 à 4 joueurs, entraînement (10 lancers). Manches : 1, 3 ou 5 de 5 palets chacune, un palet chacun à tour de rôle.
- Aide au lancer comme pour le Mölkky (le palet est ramené vers le plateau, et en Facile guidé vers le centre).
- Records enregistrés : victoires, grenouilles, meilleure série.
- Menu : grille de 4 colonnes (10 cartes), dernière rangée centrée ; sélecteur de jeux sur 4 colonnes. Aide, guide rapide et icône 3D ajoutés.
- Fichiers : scripts/grenouille.gd, scripts/menu.gd, scripts/main.gd, scripts/game_icons.gd, scripts/quick_guide.gd, tools/check_v52_grenouille.gd, tools/shot_grenouille.gd, workflow.
- Auto-test `--selftest-grenouille` (trous, lancers, parties complètes, adresse de l'ordi) ; contrôle CI `check_v52_grenouille` (menu sans chevauchement, sélecteur, guide, icône).
