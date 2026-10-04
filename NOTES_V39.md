# v39 — nettoyage propre de la fin des auto-tests

Base : v38. Version 0.39.0.

Tous les tests fonctionnels de la v38 passent (`babyfoot=OK`, `tir=OK`, `nav=OK`),
mais Godot quitte immédiatement alors qu'un dernier jeu est encore attaché à la
scène. Les `queue_free()` précédents sont également différés jusqu'à la fin de frame.

Correction :
- ajout de `_finish_selftest(code)` dans `scripts/main.gd` ;
- le jeu courant est retiré de l'arbre puis `queue_free()` ;
- la référence `game` est mise à `null` ;
- deux frames sont attendues avant `get_tree().quit()` ;
- toutes les sorties anticipées des auto-tests utilisent le même nettoyage.

Aucun changement au gameplay, aux graphismes, à la physique ou aux règles.
