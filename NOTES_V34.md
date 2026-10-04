# v34 — correction du chargement du test billard

Base : v33. Version 0.34.0.

La v33 échouait dans `tools/check_v29_billard_art.gd` avant le lancement normal
du billard. La cause était l'assertion `game is BillardGame`.

Dans un script lancé avec `godot -s`, cette référence de type force Godot à
compiler `BillardGame` trop tôt, avant l'initialisation normale des autoloads.
Le script `billard.gd` utilise l'autoload `Sound`, d'où l'erreur
`Identifier not found: Sound`.

Correction :
- suppression de toute référence de type explicite à `BillardGame` dans le test ;
- vérifications dynamiques avec `has_method()`, `get()` et `set()` ;
- lancement réel d'une partie d'entraînement avant le contrôle des 16 billes ;
- aucun changement au gameplay, au rendu, aux règles ou à la physique.
