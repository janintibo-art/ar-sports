# AR Sports v19 — personnages et ambiances

Base : v18, commit GitHub 4a0b2116f1d2400e7d94994df9e1632f14317d06.

## Nouveautés

- Personnages partagés : yeux avec blanc et pupilles, reflets en mode détaillé, clignements décalés, sourcils, bouche arrondie et dents pendant les réactions joyeuses. Cheveux remontés pour dégager le visage. Col, poche, boutons, ceinture et boucle en mode détaillé ; tissu procédural sur les vêtements.
- Les réactions déjà présentes (applaudir, joie, déception) commandent les nouvelles expressions. Aucun changement des décisions des adversaires.
- Bowling et fléchettes : jukebox décoratif rétro.
- Billard et baby-foot : meuble de pub, bouteilles stylisées et tabourets.
- Pétanque : façade provençale, volets et jardinières au fond du terrain.
- Palet, Mölkky et ping-pong : jardinières.
- Carabine et couteau : guirlandes de fête foraine derrière les cibles.
- Bouton « Décor : détaillé / léger » dans le menu, à côté de Quitter. Réglage mémorisé dans user://visual_style.cfg. Il s'applique aux jeux ouverts ensuite ; inutile de redémarrer l'application.

Le mode léger ne construit pas les nouveaux accessoires. Il réduit les touffes de feuillage, les feuilles des plantes, certains halos et les ampoules des enseignes Decor. Les détails de vêtement et les reflets des yeux sont omis. Les visages expressifs, terrains, cibles, matériel, scores et commandes restent disponibles. L'option Décor Oui/Non du bowling reste indépendante.

## Fichiers

- scripts/visual_style.gd : préférence graphique et sauvegarde, avec retour d'erreur.
- scripts/menu.gd : nouveau bouton et message en cas de sauvegarde impossible ; durée d'intro adaptée au onzième bouton.
- scripts/main.gd : chargement du choix avant la création du menu.
- scripts/bowling/spectator.gd : modèles et expressions de tous les personnages.
- scripts/decor.gd : accessoires thématiques et réduction des détails.
- scripts/bowling.gd, darts.gd, billard.gd, babyfoot.gd, petanque.gd, molkky.gd, palet.gd, pingpong.gd, tir/carabine.gd et tir/couteau.gd : placement des accessoires.
- tools/check_v19_style.gd : création des douze disciplines dans les deux profils, comparaison du nombre de nœuds et test d'expression.
- tools/shot_v19.gd : captures reproductibles du menu, personnage, pub et village.
- .github/workflows/build.yml : ajoute le test des profils graphiques.
- project.godot et export_presets.cfg : version 0.19.0 ; documents d'analyse et aperçus exclus de l'APK pour ne pas l'alourdir.
- CONTEXTE.md, ce document et docs/*v19.png : suivi et aperçus.

## Vérification

Godot 4.7.2, identique au workflow du dépôt. Les tests existants ont terminé avec score, darts, pingpong, petanque, molkky, palet, billard, babyfoot, arc, carabine, balltrap, couteau, tir et nav à OK, sans erreur de script. Le test d'interface de la v18 passe également.

Le test ajouté des profils graphiques termine à OK. Exemple de nœuds dans les scènes, détaillé → léger : bowling 403 → 368, pétanque 322 → 251, billard 250 → 206 et ball-trap 397 → 298. Ces chiffres comptent les nœuds, pas les appels de rendu et pas les images par seconde. Le gain de fluidité doit être mesuré au Quest.

Captures OpenGL contrôlées hors casque : menu, expressions et vêtements de Gégé, pub du billard et façade de pétanque. Leur apparence reste volontairement stylisée et en géométrie légère. Le réel ne s'affiche pas sur ces captures sans casque : le fond gris est le mode écran, pas un remplacement du passthrough.

Les avertissements OpenXR sans casque et les avertissements de ressources à la fermeture restent observables. Aucun APK v19 n'a été exporté ici ; la compilation Android se fera sur GitHub après application de l'archive. Vérifier ensuite dans le casque : bouton Décor, persistance du choix après redémarrage, expressions, confort avec les accessoires et fluidité.
