# v33 — correction du test d'intégration des billes

Base : v32, commit 087a083. Version 0.33.0.

Le test graphique v29 vérifiait le nombre de billes immédiatement après l'ouverture
du billard. Or `show_setup()` appelle volontairement `_drop_all()` pour que le menu
de configuration n'affiche aucune bille.

La valeur 0 à cet instant est donc normale.

Correction :
- le test vérifie maintenant que le menu ne contient aucune bille ;
- il lance ensuite une vraie partie d'entraînement en variante 8 boules ;
- il vérifie alors les 16 billes, leur rayon et leur texture mise en cache ;
- aucun changement au gameplay, aux règles, à la physique ou au rendu.
