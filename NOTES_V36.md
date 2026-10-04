# v36 — finition graphique de la table de billard

Base : v35, commit 60c67b6. Version 0.36.0.

Cette version ajoute un habillage visuel séparé à la table de billard :

- liseré sombre sous le cadre pour donner plus d'épaisseur ;
- renforts métalliques aux quatre coins ;
- incrustations décoratives sur les grands rails ;
- garnitures sombres autour des six poches ;
- petits boulons supplémentaires en qualité Détaillée.

L'habillage est ajouté par `scripts/billard/table_polish.gd`.
Il ne modifie pas `scripts/billard.gd`.

Les constantes physiques restent strictement identiques :
- PX = 0,95 m ;
- PZ = 0,475 m ;
- TABLE_Y = 0,80 m.

Les poches logiques, les bandes, les collisions, la physique des billes et les règles
8/9 boules sont inchangées.

Validation ajoutée : `tools/check_v36_billard_table.gd`.
