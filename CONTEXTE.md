# AR Sports — contexte du projet

Jeu en réalité augmentée pour **Meta Quest 3** : bowling, pétanque, ping-pong
et fléchettes, joués dans la vraie pièce grâce au passthrough.

## Pile technique

- **Godot 4.7.2**, rendu *GL Compatibility*, physique **Jolt** à 90 Hz.
- **OpenXR** + plugin **Godot OpenXR Vendors 5.1.0** (Meta) : passthrough,
  manifeste Quest. Le plugin n'est pas dans le dépôt : le CI le télécharge.
- Référence d'espace **stage** : le sol réel est à `y = 0`.
- Pas d'éditeur : tout est en GDScript et les nœuds sont créés par le code.
- Aucun fichier image : textures (bois, boule marbrée, ombres) et maillages
  (quille tournée) sont générés au lancement (`scripts/bowling/art.gd`).
- Sons et musique synthétisés par `tools/make_sounds.py` (numpy + ffmpeg) →
  `sounds/*.ogg`. Aucun droit d'auteur.

## Dépôt et compilation

- Dossier local `~/ar_sports`, dépôt GitHub `janintibo-art/ar-sports`.
- `.github/workflows/build.yml` : télécharge Godot + modèles Android + plugin
  (mis en cache), lance l'**auto-test**, exporte `build/ar_sports.apk` en
  Gradle, puis le publie dans la release `latest`.
- Clé de signature de debug fixe dans `keys/debug.keystore` (mot de passe
  `android`), pour que chaque nouvel APK s'installe par-dessus l'ancien.
- Auto-test : `godot --headless --fixed-fps 90 -- --selftest` joue une partie
  classique à 2, une rapide sans bumpers, un entraînement à 3, teste la bière,
  puis les fléchettes (tous les secteurs, 301/501, bust, sortie double, horloge,
  libre, aide à la visée) et la navigation entre jeux. `-- --selftest-darts`
  ne lance que les fléchettes.
- Captures hors casque : `xvfb-run godot --rendering-driver opengl3 -s
  tools/shot.gd -- <dossier>`.

## Fichiers

- `scripts/main.gd` : démarrage XR, passthrough, sol, mains, menu, jeux, panneau
  « Changer de jeu » (bouton Menu de la manette gauche), auto-tests enchaînés.
- `scripts/hand.gd` : manette (laser, vibration, vitesse de lancer).
- `scripts/menu.gd` : menu d'accueil (logo animé, 4 cartes de jeux avec
  pictogrammes, Quitter) ; intro au tout premier affichage.
- `scripts/logo.gd` : logo néon « AR SPORTS » (médaillons, ampoules, teinte animée).
- `scripts/game_icons.gd` : pictogrammes 3D des jeux (quille, cible, boules, raquette).
- `scripts/ui_panel.gd` : panneaux flottants à boutons (réglages, pause, fin).
- `scripts/sound.gd` : autoload `Sound` (bruitages 3D, musique, ambiance).
- `scripts/bowling.gd` : le jeu (états, joueurs, modes, score, physique).
- `scripts/bowling/art.gd` : textures et maillages procéduraux.
- `scripts/bowling/scoreboard.gd` : tableau des scores géant (dégradés, cadre
  chromé à ampoules, ligne du joueur actif qui pulse, annonces STRIKE/SPARE…,
  record affiché).
- `scripts/bowling/neon_sign.gd` : enseigne néon « BOWLING » (réagit aux
  strikes, spares, rigoles et à la victoire).
- `scripts/bowling/marquee.gd` : rangée d'ampoules animées (chenillard, arc-en-ciel).
- `scripts/bowling/spectator.gd` : personnages animés (Gégé, Sonia).
- `scripts/bowling/beer_mug.gd` : chopes de bière à boire.
- `scripts/darts.gd` : fléchettes (états, joueurs, modes, vol des fléchettes,
  aide à la visée, scores, records dans `user://darts.cfg`).
- `scripts/darts/dartboard.gd` : cible réglementaire en code + calcul du score.
- `scripts/darts/dart.gd` : fléchette (modèle, plantage, vibration).
- `scripts/darts/dart_scoreboard.gd` : tableau des scores des fléchettes.
- `scripts/darts/rules.gd` : conseil de sortie (301/501).

## Bowling

- Modes : **Classique** (10 frames), **Rapide** (5 frames), **Entraînement**
  (quilles remises à chaque lancer, statistiques).
- 1 à 4 joueurs à tour de rôle (une frame chacun), couleur de boule par joueur.
- Options : bumpers, décor, musique (mémorisées dans `user://bowling.cfg`,
  avec les records par mode).
- Sans bumpers, la boule qui sort de la piste file dans la rigole.

## Fléchettes

- Modes : **301**, **501** (sortie double en option), **Horloge** (1 à 20 puis
  bull), **Libre**. 1 à 4 joueurs, 3 fléchettes chacun, bust géré.
- Niveaux : Facile (cible x2, forte aide, 1,6 m), Normal (x1,5, aide légère,
  2 m), Pro (cible réelle, sans aide, 2,37 m).
- Pas de moteur physique : la fléchette vole avec une gravité simple et se plante
  au point où sa pointe traverse le plan de la cible.
- Prendre une fléchette dans le porte-fléchettes : **gâchette ou poignée** près
  d'elle, geste de lancer, **relâcher**.

## Commandes en jeu

- Menu : viser avec le laser, **gâchette** pour choisir. **A/X** replace le
  menu devant soi. Panneau **Quitter** ou bouton **Menu** (manette gauche)
  pour fermer l'application.
- En jeu : bouton **Menu** de la manette gauche = panneau **Changer de jeu**
  (jeux, menu principal, quitter, fermer). Aussi dans la pause (B/Y).
- Depuis le menu : bouton **Menu** de la manette gauche = quitter.
- Bowling : **gâchette ou poignée** pour prendre la boule, geste de lancer,
  **relâcher**. **B/Y** : pause (reprendre, recommencer, réglages, menu).
- Bière : **poignée** près d'une chope sur la table, la porter à la bouche en
  l'inclinant, relâcher pour la reposer. Trinquer avec Gégé en approchant sa
  chope de la sienne.
- Recentrer le Quest (bouton Meta maintenu) replace la piste devant soi.

## À faire

- Pétanque et ping-pong (cartes déjà au menu, marquées « bientôt »).
- Détection des tables et murs (scène Meta) pour le ping-pong et les fléchettes.
