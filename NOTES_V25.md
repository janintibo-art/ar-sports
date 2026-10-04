# v25 — carabine et fusil de ball-trap

Base : v24, commit bf94a52. Version 0.25.0.

Les deux modèles sont enrichis : crosse profilée en bois texturé, plaque de couche, garde-main arrondi, boîtier métallique, raccord de canon, pontet et détente. En profil Détaillé : plaques latérales, vis, stries sous le garde-main et petit levier supérieur. Le canon de la carabine et les deux canons du ball-trap conservent leurs positions et leurs repères de visée. Les extrémités reçoivent un disque sombre décoratif.

Ces éléments sont uniquement visuels. Les réglages gaucher/droitier, l’aide à la visée, les distances, la physique des tirs, le point de visée de la carabine et le flash du ball-trap conservent leur fonctionnement.

## Budget graphique

| Modèle | Profil Détaillé | Profil Léger | Surfaces |
|---|---:|---:|---:|
| Carabine | 1 012 triangles | 688 triangles | 4 |
| Ball-trap | 1 264 triangles | 868 triangles | 5 |

Chaque modèle est un seul MeshInstance3D, regroupé par matériau. Cinq matériaux partagés au maximum, texture bois commune en cache. Aucun éclairage, traitement par image, collision ou ombre dynamique supplémentaire. Les vis et détails fins sont omis en profil Léger. Ces budgets ne constituent pas une mesure des performances sur Quest.

## Fichiers

- scripts/tir/gun_art.gd : générateur partagé, crosse triangulée et regroupement par matériau.
- scripts/tir/carabine.gd et balltrap.gd : remplacement de l’habillage dans _build_gun seulement.
- tools/check_v25_models.gd : budget, bornes, normales, indices des faces de crosse, absence d’ombres, intégration dans les deux profils, repères de tir et visibilité initiale. Ajout au CI.
- tools/shot_v25.gd : captures isolées, Détaillé et Léger.
- docs/carabine_v25.png et balltrap_v25.png : aperçus hors casque, exclus de l’APK.

## Validation

Suite des jeux et navigation terminée avec tous les marqueurs OK. Test des profils graphiques et test des modèles terminés OK. Captures inspectées sous OpenGL ; le regroupement de la crosse a été corrigé après inspection et couvert par une assertion sur les indices dessinés.

Le rendu en main, la visée stéréoscopique et la fluidité restent à vérifier dans le Quest. Sans casque, OpenXR utilise le mode écran ; les avertissements existants de ressources à la fermeture subsistent. L’export APK sera exécuté par GitHub après application de la mise à jour.
