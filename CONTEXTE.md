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
  classique à 2, une rapide sans bumpers, un entraînement à 3, puis teste la
  bière (prendre, boire, reposer, remplissage).
- Captures hors casque : `xvfb-run godot --rendering-driver opengl3 -s
  tools/shot.gd -- <dossier>`.

## Fichiers

- `scripts/main.gd` : démarrage XR, passthrough, sol, mains, menu, jeux.
- `scripts/hand.gd` : manette (laser, vibration, vitesse de lancer).
- `scripts/menu.gd` : menu principal (4 jeux + Quitter).
- `scripts/ui_panel.gd` : panneaux flottants à boutons (réglages, pause, fin).
- `scripts/sound.gd` : autoload `Sound` (bruitages 3D, musique, ambiance).
- `scripts/bowling.gd` : le jeu (états, joueurs, modes, score, physique).
- `scripts/bowling/art.gd` : textures et maillages procéduraux.
- `scripts/bowling/scoreboard.gd` : tableau des scores géant.
- `scripts/bowling/spectator.gd` : personnages animés (Gégé, Sonia).
- `scripts/bowling/beer_mug.gd` : chopes de bière à boire.

## Bowling

- Modes : **Classique** (10 frames), **Rapide** (5 frames), **Entraînement**
  (quilles remises à chaque lancer, statistiques).
- 1 à 4 joueurs à tour de rôle (une frame chacun), couleur de boule par joueur.
- Options : bumpers, décor, musique (mémorisées dans `user://bowling.cfg`,
  avec les records par mode).
- Sans bumpers, la boule qui sort de la piste file dans la rigole.

## Commandes en jeu

- Menu : viser avec le laser, **gâchette** pour choisir. **A/X** replace le
  menu devant soi. Panneau **Quitter** ou bouton **Menu** (manette gauche)
  pour fermer l'application.
- Partout : bouton **Menu** de la manette gauche = retour au menu (en jeu) ou
  quitter (depuis le menu).
- Bowling : **gâchette ou poignée** pour prendre la boule, geste de lancer,
  **relâcher**. **B/Y** : pause (reprendre, recommencer, réglages, menu).
- Bière : **poignée** près d'une chope sur la table, la porter à la bouche en
  l'inclinant, relâcher pour la reposer. Trinquer avec Gégé en approchant sa
  chope de la sienne.
- Recentrer le Quest (bouton Meta maintenu) replace la piste devant soi.

## À faire

- Pétanque, ping-pong, fléchettes.
- Détection des tables et murs (scène Meta) pour le ping-pong et les fléchettes.
