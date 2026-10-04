# v47 — boules et cochonnet de pétanque

Base : v46, build vert. Version 0.47.0.

Améliorations purement visuelles :
- boules davantage métalliques tout en conservant la couleur d'équipe ;
- fine strie centrale supplémentaire ;
- deux petits poinçons métalliques opposés ;
- cochonnet plus proche d'un bois verni ;
- nœuds sombres et fine bande pour mieux lire sa rotation.

Le module `scripts/petanque/art_polish_v47.gd` observe uniquement les
MeshInstance3D ajoutés sous `_balls_root`. Aucun `call_deferred()` n'est utilisé.

Constantes physiques inchangées :
- R_B = 0,0375 m ;
- R_J = 0,015 m ;
- masses, collisions, lancer et règles inchangés.

Le workflow GitHub Actions n'est pas modifié : l'autoload est chargé pendant les
auto-tests existants, qui détecteront toute erreur de parsing ou d'exécution.
