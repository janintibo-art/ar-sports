# v37 — finition graphique du baby-foot

Base : v36, commit 6fae244. Version 0.37.0.

Cette version améliore le rendu du baby-foot sans modifier sa logique :

- liserés métalliques sous la caisse ;
- renforts décoratifs aux quatre coins ;
- encadrement plus travaillé des deux buts ;
- petit effet de filet purement visuel ;
- embouts métalliques sur les huit barres ;
- poignées colorées selon l'équipe ;
- bague centrale décorative sur chaque barre.

L'habillage est séparé dans `scripts/babyfoot/art_polish.gd`.

Les valeurs de gameplay restent inchangées :
- L = 1,20 m ;
- W = 0,68 m ;
- GOAL_W = 0,22 m ;
- BR = 0,017 m ;
- TABLE_Y = 0,85 m.

Aucun collider, mouvement de barre, IA, règle de but ou physique de balle n'est modifié.

Validation ajoutée : `tools/check_v37_babyfoot_art.gd`.
