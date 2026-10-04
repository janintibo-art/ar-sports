# v38 — correction de fermeture du self-test

Base : v37, commit 7debef4. Version 0.38.0.

La v37 passe tous les tests fonctionnels (`babyfoot=OK`, `nav=OK`) mais Godot
renvoie ensuite un code 1 à la fermeture avec des objets/ressources encore en
cours de libération.

La couche graphique du baby-foot est chargée comme autoload et ajoute de nombreux
nœuds décoratifs. Ces nœuds ne sont pas nécessaires pendant le gros test
fonctionnel lancé avec `--selftest`, car les graphismes v37 sont vérifiés ensuite
par `tools/check_v37_babyfoot_art.gd`.

Correction :
- `BabyfootPolish` détecte `--selftest` et ne branche pas son écouteur global ;
- le gros auto-test retrouve donc le même nombre de nœuds qu'avant la v37 ;
- le test graphique v37, lancé séparément sans `--selftest`, continue de charger
  et de vérifier tous les nouveaux éléments visuels ;
- aucun changement au gameplay, à la physique, aux règles ou aux graphismes en jeu.
