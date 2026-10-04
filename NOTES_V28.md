# v28 — raquettes et balle de ping-pong

Base : v27, commit f0db98c. Version 0.28.0.

Raquettes : manche arrondi en bois texturé, revêtement au grain discret, face arrière noire. En Détaillé : cercle plus lisse, tranche stratifiée, bandes sur le manche et finition au talon. Le profil Léger conserve le bois et les revêtements, avec moins de segments et sans les détails du manche. La raquette de l’adversaire conserve sa couleur bleue et son émission lumineuse existante.

Balle : orange conservé, matière plus mate et couture équatoriale discrète. Maillage plus lisse en Détaillé. Le rayon, l’animation de service et les rebonds conservent leur fonctionnement.

## Dimensions et coût

Le rayon de collision de la raquette reste 0,095 m et celui de la balle 0,028 m. Le centre et l’orientation des palettes restent identiques. L’habillage de raquette est regroupé en un mesh à quatre surfaces maximum et partagé par couleur, profil et luminosité. Détaillé : 1 428 triangles ; Léger : 864. Texture de revêtement 64 × 64 et texture de balle 128 × 64, mises en cache et munies de mipmaps. Aucune lumière ni collision ajoutée ; ombres dynamiques désactivées sur l’habillage. Ces budgets ne prouvent pas une cadence sur Quest.

## Fichiers

- scripts/pingpong/ping_art.gd : modèles et matériaux en cache.
- scripts/pingpong/paddle.gd : habillage de raquette.
- scripts/pingpong.gd : matériau et tessellation visuelle de la balle uniquement.
- tools/check_v28_ping_art.gd : profils, budgets, bornes, partage, couleur, émission, mipmaps et intégration. Ajout au CI.
- tools/shot_v28.gd et docs/equipement_pingpong_v28.png : aperçu hors casque, exclu de l’APK.

## Validation

Test des équipements terminé OK. Test des profils graphiques et suite des jeux relancés. Capture OpenGL inspectée. Le solveur, les contacts de raquette, les services, les scores et les paramètres de table ne sont pas modifiés.

Sans casque, OpenXR utilise le mode écran ; les avertissements existants de ressources à la fermeture subsistent. Le rendu stéréoscopique, la prise en main et la fluidité restent à vérifier sur Quest. L’export APK sera exécuté par GitHub après application de la mise à jour.
