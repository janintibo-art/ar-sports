# v48 — finition du support de boules de pétanque

Base : v47, build vert. Version 0.48.0.

Améliorations purement visuelles du support :
- double socle plus travaillé ;
- trois bagues métalliques sur la colonne ;
- plateau supérieur en bois ;
- cerclage couleur laiton ;
- trois petits plots de maintien ;
- plaque frontale discrète.

Le module `scripts/petanque/stand_polish_v48.gd` s'applique directement lorsque
le nœud `_stand` est ajouté. Aucun `call_deferred()` n'est utilisé.

Aucun collider, rayon, masse, règle, lancer ou paramètre physique n'est modifié.
Le workflow GitHub Actions reste inchangé.
