# v27 — fléchettes et cible

Base : v26, commit 8ea0ad8. Version 0.27.0.

Fléchettes : corps métallique légèrement effilé, anneaux de prise plus fins et ailettes au profil découpé. Les matériaux colorés restent propres à chaque fléchette : un changement de joueur ne recolore pas les objets déjà lancés. La position de la pointe, la taille, les transformations de prise en main et la vibration après impact conservent leurs repères.

Cible : grain discret sur les secteurs, avec mipmaps pour la distance, et entourage en bois texturé. Les chiffres, fils, couleurs, rayons et règles de score conservent leurs valeurs. Le grain ne décale pas les limites des zones.

## Coût graphique

Le corps métallique est un seul mesh à trois surfaces, partagé entre les fléchettes d’un même profil : 552 triangles en Détaillé, 240 en Léger. Les ailettes partagent leur géométrie, avec leurs propres matériaux colorés. Chaque fléchette comporte quatre éléments sous son modèle (corps groupé, tige et deux ailettes). La texture de grain 128 × 128 est générée une fois et partagée. Pas de lumière, d’effet par image ou de collision supplémentaire.

## Fichiers

- scripts/darts/dart_art.gd : corps groupés, ailettes partagées et texture de grain déterministe.
- scripts/darts/dart.gd : habillage ; logique de vol et d’impact conservée.
- scripts/darts/dartboard.gd : matériaux et coordonnées UV ; fonctions de score conservées.
- tools/check_v27_darts_art.gd : profils, partage de géométrie, indépendance des couleurs, position de pointe, vibration, texture et score des soixante secteurs. Ajout au CI.
- tools/shot_v27.gd et docs/*_v27.png : captures hors casque, exclues de l’APK ; la fléchette est grossie uniquement pour la capture.

## Validation

Test des graphismes des fléchettes terminé OK. Suite des jeux et navigation relancée ; profils graphiques et modèles de tir également vérifiés. Captures fléchette et cible inspectées sous OpenGL.

Sans casque, OpenXR utilise le mode écran ; les avertissements existants de ressources à la fermeture subsistent. La lisibilité des zones, le rendu en main et la fluidité restent à vérifier sur Quest. L’export APK sera exécuté par GitHub après application de la mise à jour.
