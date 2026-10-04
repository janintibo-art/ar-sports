# v49 — finition graphique du terrain de pétanque

Base : v48, build vert. Version 0.49.0.

Ajouts purement visuels :
- renforts sombres sous les quatre bordures en bois ;
- petits renforts métalliques aux quatre coins ;
- ligne de départ derrière le cercle de lancer ;
- repères centraux aux distances minimale et maximale du cochonnet ;
- petites zones de gravier plus sombre pour casser l'aspect trop uniforme.

Le module `scripts/petanque/terrain_polish_v49.gd` surveille le terrain actif
sans `call_deferred()`. Si le joueur change entre terrain Normal et Court et que
`_build_terrain()` reconstruit ses enfants, l'habillage v49 est recréé
automatiquement au frame suivant.

Aucune limite physique, collision, masse, règle ou paramètre de lancer n'est modifié.
Le workflow GitHub Actions reste inchangé.
