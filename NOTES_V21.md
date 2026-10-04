# AR Sports v21 — confort des menus

Base : v20, commit 08abce5 (branche main vérifiée avant modification).

## Utilisation

Dans l'accueil, viser « Confort », puis choisir une taille de menu : 100 %, 115 % ou 130 %. Choisir une distance : Proche, Normal ou Éloigné. La taille augmente l'interface entière, y compris textes, boutons et zones de visée.

Le panneau de confort s'adapte immédiatement. « Retour au menu » affiche l'accueil avec les nouvelles valeurs. Les panneaux communs de réglages, pause, fin et changement de jeu appliquent ces valeurs lorsqu'ils sont placés devant la tête. Les tableaux de score et les objets de jeu ne sont pas redimensionnés.

Les deux valeurs sont mémorisées dans user://visual_style.cfg avec le choix Décor léger/détaillé. Modifier l'une conserve les autres. « Réinitialiser » remet uniquement taille et distance à leur valeur normale. Si une sauvegarde échoue, le panneau l'indique : le réglage reste actif pour la session.

Bouton Menu ou B/Y : retour à l'accueil depuis Confort. A/X : replace le panneau devant soi. Le menu masqué ne peut pas être cliqué derrière les réglages.

## Fichiers modifiés

- scripts/visual_style.gd : valeurs de confort, bornes, chargement et sauvegarde commune conservant la qualité graphique.
- scripts/menu.gd : bouton Confort, aide au survol, rangée de trois boutons, intro adaptée à douze cartes/boutons, taille et distance mémorisées.
- scripts/main.gd : ouverture, reconstruction et fermeture du panneau ; navigation et boutons des manettes.
- scripts/ui_panel.gd : application du confort aux panneaux communs.
- project.godot, export_presets.cfg : version affichée 0.21.0.
- tools/check_v21_comfort.gd et .github/workflows/build.yml : test automatique supplémentaire.
- tools/shot_v21.gd : captures reproductibles.
- CONTEXTE.md, ce document et docs/confort_v21.png : documentation, exclue de l'APK.

## Vérification

Godot 4.7.2 utilisé. Test de confort : ouverture depuis l'accueil, collisions désactivées derrière le panneau, sélection, changement d'échelle, distance du panneau, persistance dans le fichier de configuration, maintien du confort après changement de qualité, fermeture, réinitialisation et limites des valeurs.

Les contrôles d'interface v18, des profils graphiques v19, des aides/effets v20 et la suite des jeux/navigation sont également exécutés. Captures du menu, du confort par défaut et de 130 % avec distance Éloigné inspectées hors casque. Ce contrôle à plat ne remplace pas la vérification de lisibilité en stéréoscopie dans le Quest.

Aucun APK v21 n'est exporté dans cet environnement : compilation Android sur GitHub après application du ZIP. Les avertissements OpenXR sans casque et de ressources à la fermeture restent observables. Vérifier au casque la combinaison taille/distance préférée et la conservation du choix après redémarrage.
