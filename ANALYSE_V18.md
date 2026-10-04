# AR Sports — analyse et améliorations v18

Analyse du 4 octobre 2026. Base : commit 82627ec812425dbb6d160f06814302df2b14f7d9 (v17). La dernière compilation GitHub observée, run 37186479053, est réussie. La v18 n'a pas encore été poussée ou exportée en APK dans cet environnement.

## Bilan

Le projet comporte neuf entrées dans le menu et douze disciplines jouables en comptant séparément les quatre jeux du groupe Tir. La structure est cohérente : lancement central, interface partagée, matériaux procéduraux, physique adaptée à chaque jeu, sauvegardes séparées, tests intégrés. Les tests permettent de vérifier les règles et des parties simulées ; ils ne prouvent ni la précision des gestes réels, ni le confort visuel, ni une cadence de 90 images par seconde dans le Quest.

## Défauts constatés et corrigés

| Sujet | Cause dans la v17 | Correction v18 |
|---|---|---|
| Intro du menu | INTRO_END=3,2 s ; la dixième carte commence à 3,36 s et termine vers 3,76 s | Fin à 3,8 s, blocage explicite des clics pendant l'intro |
| Sous-titre Tir | Quatre noms dans une carte de 29 cm | « 4 disciplines », ajustement de la largeur réelle des textes |
| Textes des boutons | Taille fixe même pour les intitulés longs | Mesure avec la police et réduction de pixel_size si nécessaire |
| Ancien panneau | queue_free attend la fin d'image : anciens éléments restent présents jusque-là | Retrait immédiat des anciens nœuds avant destruction différée |
| Navigation | _exit_tree des anciens jeux réactive les lasers / coupe la musique après création du suivant | Retrait immédiat de l'ancien jeu avant création du nouveau |
| Retour au menu | Le menu invisible continue à animer ses icônes | Désactivation de son traitement pendant le jeu, restauration au retour |
| Relâchement en pause de changement | Évènement relayé au jeu suspendu | Relâchements non transmis quand le sélecteur de jeux est ouvert |
| Ombres des arbres, bancs, buissons, plantes | make_blob utilise top_level=true, adapté aux balles suivies mais pas aux décors fixes | Ombres statiques en coordonnées locales, elles suivent placement et recentrage |
| Textures des terrains | Générées de nouveau lors de chaque reconstruction | Cache partagé déterministe de textures, mipmaps et filtrage anisotrope |
| Vérification CI | Présence de score=OK du bowling seulement, sans exiger chaque résultat final | Exige les marqueurs de chaque jeu et de la navigation, ajoute le test d'interface |
| Numéro affiché | Version du projet et APK restée à 0.14.0 | Alignement à 0.18.0 |

## Graphismes livrés

Menu : fonds bleu nuit opaques pour isoler le texte du passthrough, coins arrondis en géométrie, cadre dégradé de la couleur du sport, liseré discret, pictogrammes 3D conservés. Les libellés longs tiennent dans les cartes. Les panneaux de réglages utilisent des boutons arrondis et la couleur du jeu pour la sélection.

Jeux : bois veiné sur les cadres du billard et du baby-foot, les planches de palet, les quilles de Mölkky, les flèches de l'arc et la table de couteaux ; grain fin sur le tapis de billard et les tapis de décor ; herbe détaillée sur le terrain du Mölkky et le baby-foot ; gravier partagé pour pétanque et palet ; surface détaillée sur la table de ping-pong et filet ajouré par texture à découpe alpha. Aucun changement des dimensions, collisions, scores ou gestes de lancer.

Le bowling possède déjà bois de piste, boules marbrées et quilles tournées : ses modèles sont conservés. Fléchettes, carabine et ball-trap bénéficient surtout de l'interface commune ; leurs modèles n'ont pas été refaits. Cette version est une amélioration de matériaux et d'interface, pas une refonte de tous les modèles 3D.

Coût : textures de 128×128 mises en cache par famille, filet de 32×32, pas de lumières supplémentaires, pas d'ombres dynamiques ni de post-traitement lourd. Les panneaux arrondis ajoutent peu de triangles. L'effet réel sur les performances doit être mesuré au casque.

## Revue par jeu et priorités restantes

| Jeu | Éléments vérifiés par les tests existants | Limites / suite proposée |
|---|---|---|
| Bowling | Parties classique/rapide/entraînement et manipulation des chopes | score=OK est imprimé inconditionnellement en fin de test : renforcer ensuite les assertions sur le score réglementaire ; collision de quille cylindrique plus simple que son modèle |
| Fléchettes | Secteurs, doubles/triples/bull, 301/501, bust, sortie double, horloge, libre, aide | Comparer la trajectoire au geste réel ; grosses cibles en Facile/Normal assumées |
| Ping-pong | Trajectoires, points, matchs aux trois niveaux, table compacte, entraînement | Volée autorisée : comportement arcade ; pas de spin ni multijoueur humain ; calibrer contact raquette en VR |
| Pétanque | Solveur, contacts, boules mortes, règles, parties, entraînement | Terrain long : espace virtuel au-delà de la pièce ; roulement et puissance à calibrer au casque ; équipes 2 contre 2 absentes |
| Mölkky | Règle de 50, dépassement, élimination, matchs et lancers | Contact cylindre/quille et dispersion Jolt à comparer au réel ; matière bois améliorée |
| Palet | Variantes, capture des trous, points, terrain, matchs | Modèle physique hérité de boule mais paramètres adaptés au disque ; vérifier glissement et bords au casque |
| Billard | Fautes, groupes, noire/9, collisions, parties, entraînement | Résolution à plat et arbitre après 70 coups : approximation arcade ; geste de queue et placement de blanche à vérifier |
| Baby-foot | Buts, rebonds, barres, parties et défi | Joueurs en collisions simplifiées, vitesse de main convertie en rotation ; ajouter à terme des réglages de sensibilité |
| Arc | Barème, chute, vent, visée, matchs et cible mobile | Flèches et corde à tester en gaucher/droitier, cibles éloignées |
| Carabine | Barème, tirs 10/25 m, cadence, cibles de foire, matchs | Stabilisation à deux mains et orientation réelle à valider ; modèle peut être enrichi sans toucher les règles |
| Ball-trap | Anticipation, gerbe, cartouches et parties | Pas de simulation individuelle de chaque plomb ; choix raisonnable pour la performance mobile |
| Couteau | Barème, plantage, rebond, lancers faibles, assistance, modes | Un tour calculé pour arriver à la cible + erreur aléatoire : arcade, pas une simulation physique complète |

## Architecture, XR, sauvegardes et compilation

- OpenXR, passthrough alpha et espace stage sont configurés. En absence de runtime XR, le programme passe en mode écran. Impossible de valider ici la session Meta, les manettes ou le passthrough : aucun casque connecté.
- Le recentrage replace le jeu. Un recalage automatique sur les murs / une table réelle n'est pas implémenté ; CONTEXTE.md l'identifie déjà comme tâche future.
- La physique vise 90 Hz et suit la fréquence disponible du casque. Les sous-pas maison du billard/baby-foot et les trajectoires du ping-pong évitent de dépendre d'une seule méthode de physique.
- Sauvegardes ConfigFile par jeu dans user://. Les valeurs de retour de save() ne sont généralement pas traitées : ajouter un avertissement discret si une écriture échoue. Aucun problème d'écriture observé ici, mais les tests peuvent écrire dans le profil de test.
- Le menu et les jeux partagent les manettes et l'autoload Sound : l'ordre de destruction était donc sensible. La v18 règle ce point, sans changer les identifiants des jeux.
- Les scripts de jeu mélangent règles, UI, physique et tests dans de gros fichiers. Extraire progressivement les règles pures et les matériaux partagés faciliterait l'évolution ; une réécriture globale maintenant serait risquée.
- Release latest : le workflow supprime puis recrée la release. Si la publication échoue entre les deux, latest peut disparaître temporairement. Préférer à terme un remplacement des assets d'une release existante.
- Export debug signé, cohérent pour une application personnelle. Aucune démarche de publication magasin nécessaire.
- Le projet utilise le moteur 4.7.2 et le plugin Vendors 5.1.0 définis dans son propre workflow ; moteur identique utilisé pour les vérifications de cette version.

## Fichiers de la mise à jour

- scripts/menu.gd : cartes, intro, textes, clics.
- scripts/ui_panel.gd : boutons, sélection, largeur des textes, reconstruction.
- scripts/bowling/art.gd : panneaux arrondis, matériaux partagés, filet, ajustement des textes.
- scripts/decor.gd : ombres locales et tapis texturés.
- scripts/main.gd : ordre de changement de jeu, menu inactif, relâchements.
- scripts/billard.gd, scripts/babyfoot.gd : bois et surfaces.
- scripts/pingpong/ping_table.gd : surface de table et filet.
- scripts/petanque.gd, scripts/palet.gd, scripts/molkky.gd : matériaux mis en cache ; suppression des anciens générateurs devenus inutilisés.
- scripts/tir/arc.gd, scripts/tir/couteau.gd : bois et tapis.
- project.godot, export_presets.cfg : version affichée.
- tools/check_visual_ui.gd, .github/workflows/build.yml : contrôles de régression et marqueurs de réussite.
- CONTEXTE.md et ce rapport : état et documentation de reprise.

## Validation et limites

La suite existante a terminé avec les marqueurs OK de tous les jeux et de la navigation, sans SCRIPT ERROR ni Parse Error. Le test ajouté visual_ui a terminé OK : intro, clic bloqué pendant l'intro, largeur de texte, suppression des boutons, ombre locale et absence de réactivation tardive du laser.

Le lancement sans casque produit les avertissements OpenXR attendus. Des avertissements de ressources encore en usage à la fermeture ont été observés ; ils ne sont pas la preuve d'une fuite pendant le jeu et nécessitent un examen séparé. L'export APK Android reste à exécuter sur GitHub après application du ZIP. Aucun succès d'export v18 n'est affirmé.

Les captures hors casque ont finalement été générées sous OpenGL. Le menu, les réglages du bowling, la table et le filet du ping-pong, ainsi que le terrain de pétanque ont été inspectés visuellement. Les icônes du menu ont été réduites après inspection pour dégager les titres. Un aperçu du menu se trouve dans docs/menu_v18.png. Ces captures ne remplacent pas une vérification stéréoscopique dans le Quest. À vérifier dans le Quest : lisibilité des cartes, filet à distance, contours au survol, ombres après recentrage, précision des gestes et fluidité pendant les impacts.

## Prochaines améliorations recommandées

1. Vérifier cette version au casque, en commençant par menu, ping-pong, billard et Mölkky.
2. Ajouter des réglages communs : taille d'interface, distance des panneaux, qualité du décor, volume et main dominante.
3. Enrichir les modèles de personnages et les équipements des jeux de tir, avec un budget de triangles fixé au préalable.
4. Renforcer le test de score du bowling et traiter les erreurs de sauvegarde.
5. Ajouter diagnostic de performance au casque : temps CPU/GPU, images par seconde et nombre d'objets dessinés.
