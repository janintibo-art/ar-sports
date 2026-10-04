# v45 — finition du terrain du baby-foot

Base : v44, build vert. Version 0.45.0.

Ajouts purement visuels :
- contour complet du terrain ;
- point central ;
- repères discrets dans les quatre coins ;
- accents bleu et rouge devant les buts.

Le module `scripts/babyfoot/field_polish_v45.gd` ne crée aucun collider.

Constantes inchangées :
- L = 1,20 m ;
- W = 0,68 m ;
- GOAL_W = 0,22 m ;
- BR = 0,017 m ;
- BODY_R = 0,015 m ;
- FR = 0,018 m.

Validation ajoutée : `tools/check_v45_babyfoot_field.gd`.
