# v35 — stabilisation complète des tests billard

Base : v34, commit eddae81. Version 0.35.0.

Deux faux négatifs restaient dans les tests graphiques du billard.

1. `check_v29_billard_art.gd` comparait le rayon d'un `SphereMesh` avec `==`.
   Le rayon est un flottant ; la comparaison exacte peut échouer pour 0,0285.
   Le test utilise maintenant `is_equal_approx()`.

2. `check_v30_billard_cue.gd` contenait encore `game is BillardGame`.
   Cette référence directe peut forcer la compilation du script de billard trop
   tôt dans un test lancé avec `godot -s`. Le test utilise désormais uniquement
   des accès dynamiques et des types Godot intégrés.

Le test v29 vérifie aussi explicitement la présence du matériau avant de vérifier
la texture.

Aucun changement au gameplay, aux règles, au rendu, aux collisions ou à la physique.
