# v40 — correction compilation habillage baby-foot

Base : v39. Version 0.40.0.

La cause réelle du rouge des v37 à v39 était une erreur de parsing dans
`scripts/babyfoot/art_polish.gd`, visible au début du journal :

- `Cannot infer the type of "gx" variable`
- `Cannot infer the type of "end_z" variable`

Le workflow continuait assez loin pour afficher les SELFTEST fonctionnels, mais
la présence de `SCRIPT ERROR` faisait ensuite échouer volontairement le job.

Correction :
- typage explicite de toutes les valeurs numériques de boucle et calculées ;
- `sx`, `sy`, `gx`, `iy`, `ih`, `z`, `y` et `end_z` sont maintenant déterministes ;
- aucun changement au gameplay, aux collisions, à la physique ou aux règles ;
- les graphismes v37 du baby-foot sont conservés.
