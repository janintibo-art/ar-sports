# v22 — réglages des gestes

Base : v21, commit 46e6b39. Version 0.22.0.

Depuis Confort, choisir l’onglet Gestes. Trois réglages indépendants :
- Lancers : Doux (80 %), Normal (100 %), Fort (120 %). Concerne bowling, fléchettes, pétanque, mölkky, palet et couteau.
- Billard : Doux (75 %), Normal (100 %), Fort (125 %), pour la puissance du coup de queue humain. Le seuil de contact et la vitesse maximale restent identiques.
- Barres de baby-foot : Calme (75 %), Normal (100 %), Vif (125 %), pour la rotation des barres tenues par le joueur.

Les valeurs sont mémorisées dans visual_style.cfg avec la taille, la distance et la qualité graphique. Les installations précédentes gardent le comportement Normal par défaut. Réinitialiser restaure uniquement l’onglet ouvert. Les tirs des adversaires et la translation des barres ne sont pas modifiés. Il s’agit de réglages manuels, pas d’un étalonnage automatique.

## Vérifications

check_v22_gestures.gd vérifie la navigation, la sauvegarde et le rechargement des préférences, les vitesses de lancer, la puissance progressive du billard, le rejet d’un contact trop lent, la rotation du baby-foot et la réinitialisation indépendante. Le test est intégré au workflow avant l’export APK.

Les tests d’interface, des profils graphiques, des effets et du confort sont relancés, ainsi que la suite complète des jeux. Capture écran : docs/gestes_v22.png (outil tools/shot_v22.gd). Les captures et outils sont exclus de l’APK.

Validation locale sans casque : OpenXR bascule en mode écran ; les avertissements existants de ressources à la fermeture subsistent. L’export APK et le ressenti des gestes sur Quest restent à vérifier après installation.
