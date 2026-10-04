# v32 — correction du test graphique du billard

Base : v31, commit 76644cf. Version 0.32.0.

La compilation et l'auto-test principal passent désormais. Le blocage restant
venait uniquement de `tools/check_v29_billard_art.gd`.

Le test comparait seulement le canal rouge de la zone blanche et de la bande
jaune de la bille 9. Cette hypothèse était fausse : le jaune possède naturellement
un canal rouge très élevé.

Correction :
- comparaison de la distance entre couleurs RGB complètes ;
- vérification que le bord de la rayée est plus proche du blanc ;
- vérification que le centre est plus proche de la couleur réglementaire ;
- aucun changement du rendu, des billes, de la queue, des règles ou de la physique.
