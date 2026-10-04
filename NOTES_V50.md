# v50 — les menus n'entrent plus dans les tables

Base : v49. Version 0.50.0.

## Problème
Sur le ping-pong et le baby-foot, le panneau de menu se plaçait à hauteur de la tête moins 20 cm. Sa hauteur (environ 80 cm au ping-pong, plus en taille 130 %) le faisait descendre dans la table, surtout quand la tête est basse (assis) ou avec la taille de menu agrandie. Les boutons du bas disparaissaient dans la table et devenaient inutilisables.

## Correction
- `UiPanel.floor_clearance` : hauteur sous laquelle le bas du panneau ne doit pas descendre. `place_in_front_of` remonte le panneau si besoin (jamais plus de 50 cm au-dessus de la tête).
- Réglé pour le ping-pong (table + filet + 15 cm), le baby-foot et le billard (table + 35 cm). Les autres jeux n'ont pas de table à cet endroit.
- Le panneau reste à la même distance : il est seulement relevé.

## Test
`tools/check_v50_menu_clearance.gd` (ajouté au CI) : 3 jeux × 4 hauteurs de tête (1,7 / 1,5 / 1,3 / 1,1 m) × 2 tailles de menu × 3 pages (réglages, pause, fin) = 72 cas ; aucun ne doit croiser la table. Sans le correctif, le test détecte le défaut (menu jusqu'à 33 cm du sol à tête basse).

Les 19 contrôles existants et l'auto-test des jeux passent toujours. Option `-- --sans-correctif` pour voir le défaut.
