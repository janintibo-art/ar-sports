# v26 — arc, flèches et couteaux

Base : v25, commit 206d8ea. Version 0.26.0.

Arc : branches en bois texturé, largeur réduite aux extrémités, poignée arrondie et garnitures. Profil Détaillé : 32 segments et ligatures sur la poignée ; profil Léger : 12 segments. Les deux extrémités et la corde dynamique gardent leurs repères d’origine.

Flèches : fût en bois, trois empennages profilés à 120 degrés, couleur du joueur ou de l’adversaire. En profil Détaillé, deux ligatures supplémentaires. La longueur, la pointe, l’origine de tir et les trajectoires restent celles du jeu.

Couteaux : lame métallique au profil effilé, manche arrondi en bois, garde et pommeau. En profil Détaillé : rivets et stries sous le manche. Les positions des couteaux, leur prise en main, la rotation, la trajectoire et les impacts conservent leur fonctionnement.

## Budget et partage

| Modèle | Détaillé | Léger |
|---|---:|---:|
| Arc, hors corde | 936 triangles | 588 triangles |
| Flèche | 210 triangles | 102 triangles |
| Couteau | 644 triangles | 464 triangles |

Un MeshInstance3D par habillage, quatre surfaces au maximum. Les géométries sont mises en cache par type, profil, longueur et couleur pertinente : les objets répétés partagent le même mesh. Pas de lumière, ombre dynamique ou collision ajoutée. La corde et les marqueurs de visée conservent leurs traitements existants. Les performances réelles restent à mesurer dans le Quest.

## Fichiers

- scripts/tir/ranged_art.gd : modèles, profils triangulés et cache.
- scripts/tir/gun_art.gd : regroupement par matériau rendu réutilisable via batch ; les carabines et fusils gardent leurs métadonnées.
- scripts/tir/arc.gd : habillages de l’arc et des flèches.
- scripts/tir/couteau.gd : habillage des couteaux.
- tools/check_v26_ranged.gd : budgets, faces indexées, cache partagé, bornes et intégration. Ajout au CI avant l’export.
- tools/shot_v26.gd et docs/*_v26.png : captures isolées, exclues de l’APK. Le couteau est grossi uniquement pour la capture.

## Validation

Test des nouveaux modèles, test des carabines/fusils et test des deux profils graphiques terminés OK. Suite des jeux et navigation relancée. Captures arc, flèche et couteau inspectées sous OpenGL.

Sans casque, OpenXR utilise le mode écran ; les avertissements existants de ressources à la fermeture subsistent. Le rendu stéréoscopique, les gestes réels et la fluidité restent à vérifier sur Quest. L’export APK sera effectué par GitHub après application de cette mise à jour.
