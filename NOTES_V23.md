# v23 — guide des commandes

Base : v22, commit 6cf887a. Version 0.23.0.

Confort comporte maintenant un troisième onglet : Guide. Il contient une fiche de commandes communes et douze fiches de disciplines, dont les quatre jeux du groupe Tir. Chaque fiche affiche cinq lignes, un numéro de page, Précédent, Suivant et Retour au menu. La navigation boucle entre la première et la dernière page. La dernière page consultée reste sélectionnée pendant la session.

Les textes reprennent les rappels existants des jeux et proposent un premier conseil de pratique. Les réglages de gestes sont rappelés sur les disciplines concernées. Le guide est consultable depuis l’accueil, avant de lancer un jeu ; il ne s’ouvre pas pendant une partie.

## Fichiers

- scripts/quick_guide.gd : contenu des treize fiches.
- scripts/main.gd : onglet, pagination et retour au menu.
- scripts/ui_panel.gd : lignes de texte informatives, sans collision ni bouton. Largeur ajustée au panneau ; alignement supérieur pour éviter les chevauchements.
- scripts/menu.gd : description de Confort au survol.
- tools/check_v23_guide.gd : test de toutes les pages, boucle de pagination, collisions, fermeture, conservation des réglages et refus pendant un jeu. Ajouté au CI avant l’export.
- tools/shot_v23.gd et docs/guide_v23.png : capture du guide, exclue de l’APK.

## Validation

Tests locaux du guide, de l’interface, du confort et des gestes. Suite complète des jeux relancée. Captures des commandes communes et de l’arc inspectées sous OpenGL. Aucun changement des règles, scores, commandes physiques ou préférences sauvegardées.

Sans casque, OpenXR bascule en mode écran. Les avertissements existants de ressources à la fermeture subsistent. La lisibilité stéréoscopique reste à vérifier sur Quest ; l’APK sera exporté par GitHub après application de la mise à jour.
