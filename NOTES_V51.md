# v51 — optimisations et robustesse (0.51.0)

Suite du check-up v50 (carte blanche).

- Baby-foot : fusion des maillages fixes (figurines, barres, table) par matériau → 584 appels de rendu ramenés à environ 270 (mesures hors casque). Les barres gardent leur pivot : rotation et glissement inchangés. Nouveau `scripts/mesh_merge.gd` (MeshMerge) et autoload `scripts/babyfoot/merge_v51.gd` (inactif en `--selftest`, attend 12 frames que les habillages v37–v45 soient en place).
- Test CI `tools/check_v51_babyfoot_merge.gd` : moins de maillages, nombre de triangles identique, encombrement identique, la rotation du pivot déplace bien le maillage fusionné.
- `check_v50_menu_clearance` : sait lire les maillages fusionnés (test par sommets).
- Lampe du baby-foot remontée de 15 cm (ne touche plus le menu à 130 %).
- Fins de partie : après chaque `await create_timer`, on quitte si le jeu a été retiré de la scène (plus d'erreur si on sort du jeu dans les 2 s).
- Icônes du lanceur (`icons/`, générées depuis `icon.svg`) branchées dans `export_presets.cfg`.
- Non fait volontairement : export release signé et publication de la release sans suppression (non testables hors CI).
