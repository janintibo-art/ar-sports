# v44 — correction du test des figurines baby-foot

Base : v43. Version 0.44.0.

Le test v43 attendait `BODY_R = 0,021 m`, alors que la constante réelle du jeu
dans `scripts/babyfoot.gd` est `BODY_R = 0,015 m`.

Correction :
- attente du test alignée sur la constante réelle 0,015 m ;
- BR reste 0,017 m ;
- FR reste 0,018 m ;
- aucun changement au gameplay, aux collisions, aux graphismes ou à la physique.
