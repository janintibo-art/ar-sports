# AR Sports — contexte du projet

Jeu en réalité augmentée pour **Meta Quest 3** : bowling, pétanque, ping-pong
et fléchettes, joués dans la vraie pièce grâce au passthrough.

## Pile technique

- **Godot 4.7.2**, rendu *GL Compatibility*, physique **Jolt** à 90 Hz.
- **OpenXR** + plugin **Godot OpenXR Vendors 5.1.0** (Meta) : passthrough,
  manifeste Quest. Le plugin n'est pas dans le dépôt : le CI le télécharge.
- Référence d'espace **stage** : le sol réel est à `y = 0`.
- Pas d'éditeur : tout est en GDScript et les nœuds sont créés par le code.

## Dépôt et compilation

- Dossier local `~/ar_sports`, dépôt GitHub `janintibo-art/ar-sports`.
- `.github/workflows/build.yml` : télécharge Godot + modèles Android + plugin
  (mis en cache), lance l'**auto-test**, exporte `build/ar_sports.apk` en
  Gradle, puis le publie dans la release `latest`.
- Clé de signature de debug fixe dans `keys/debug.keystore` (mot de passe
  `android`), pour que chaque nouvel APK s'installe par-dessus l'ancien.
- Auto-test : `godot --headless --fixed-fps 90 -- --selftest` joue une partie
  de bowling complète avec des lancers automatiques et affiche le score.

## Fichiers

- `scripts/main.gd` : démarrage XR, passthrough, sol, mains, menu, jeux.
- `scripts/hand.gd` : manette (laser, vibration, vitesse de lancer).
- `scripts/menu.gd` : menu flottant à 4 panneaux.
- `scripts/bowling.gd` : piste, quilles, boule, règles et score sur 10 frames.

## Commandes en jeu

- Menu : viser avec le laser, **gâchette** pour choisir. **A/X** replace le
  menu devant soi.
- Bowling : **gâchette ou poignée** pour prendre la boule (elle vient dans la
  main), mouvement de lancer, **relâcher** pour lancer. **A** rejoue en fin de
  partie, **B/Y** revient au menu. Recentrer le Quest (bouton Meta maintenu)
  replace la piste devant soi.

## À faire

- Pétanque, ping-pong, fléchettes.
- Sons (roulement, quilles).
- Détection des tables et murs (scène Meta) pour le ping-pong et les fléchettes.
