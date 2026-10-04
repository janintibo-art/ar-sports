# v43 — détails des figurines du baby-foot

Base : v42, build vert. Version 0.43.0.

Ajouts purement visuels sur les 22 figurines :
- ceinture fine entre maillot et short ;
- semelle plus nette ;
- deux yeux minimalistes orientés dans le sens de l'équipe ;
- petite bande claire au dos du maillot.

Le nouveau module `scripts/babyfoot/player_detail_v43.gd` n'ajoute aucun collider.
Les constantes physiques restent inchangées :
- BR = 0,017 m ;
- BODY_R = 0,021 m ;
- FR = 0,018 m.

Validation :
- `tools/check_v43_babyfoot_players.gd`
- vérifie les 22 figurines et les constantes physiques.
