# AR Sports — contexte du projet

Jeu en réalité augmentée pour **Meta Quest 3** : bowling, fléchettes, pétanque, ping-pong
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
  libre, aide à la visée), le ping-pong (tirs calculés, règles, matchs complets
  aux 3 niveaux contre un joueur virtuel, table compacte, entraînement) et la
  la pétanque (solveur de pointage, chocs, boules mortes, règles, aide au
  lancer, parties complètes aux 3 niveaux, entraînement, lancer humain simulé)
  et la navigation entre jeux. `-- --selftest-darts` / `-- --selftest-pingpong`
  / `-- --selftest-petanque` ne lancent qu'un jeu.
- Captures hors casque : `xvfb-run godot --rendering-driver opengl3 -s
  tools/shot.gd -- <dossier>`.

## Fichiers

- `scripts/main.gd` : démarrage XR, passthrough, sol, mains, menu, jeux, panneau
  « Changer de jeu » (bouton Menu de la manette gauche), auto-tests enchaînés.
- `scripts/hand.gd` : manette (laser, vibration, vitesse de lancer).
- `scripts/menu.gd` : menu d'accueil (logo animé, 9 cartes en grille 3×3 ; palet, billard, baby-foot et tir sont « bientôt ») ; intro au tout premier affichage.
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
- `scripts/pingpong.gd` : ping-pong (physique maison de la balle, règles de
  points, adversaire robot, machine à balles, aide au renvoi, records dans
  `user://pingpong.cfg`).
- `scripts/pingpong/ping_table.gd` : table réglementaire (normale ou compacte).
- `scripts/pingpong/paddle.gd` : raquette (face rouge devant, noire derrière).
- `scripts/pingpong/ping_scoreboard.gd` : tableau Vous / Ordi (réutilisé par la pétanque).
- `scripts/petanque.gd` : pétanque (terrain, règles, adversaire Marcel, aide au
  lancer, records dans `user://petanque.cfg`).
- `scripts/decor.gd` : décor en code (arbres, bancs, lampadaires, plantes, enseignes néon), utilisé par la pétanque et le ping-pong.
- `scripts/ui_panel.gd` : panneaux de menu (cadre à ampoules, bandeau de titre, boutons bombés, couleur d'accent par jeu via `accent`).
- `scripts/molkky.gd` : Mölkky (quilles et bâton en corps rigides Jolt, règle des 50 / dépassement = retour à la moitié / 3 ratés = éliminé, modes Ordi / 2-4 joueurs / entraînement, records dans `user://molkky.cfg`).
- `scripts/molkky/mol_board.gd` : tableau des scores du Mölkky.
- `scripts/petanque/pet_ball.gd` : boule / cochonnet (gravité, rebond amorti,
  roulement, chocs). Constantes de réglage : `LAND_KEEP` (0,45) et
  `ROLL_DECEL` (3,2 m/s²).

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

## Ping-pong

- Modes : **Contre l'ordi** (premier à 7 ou 11, 2 points d'écart, service tous
  les 2 points) et **Entraînement** (machine à balles, série de renvois).
- Niveaux Facile / Normal / Expert : vitesse, réaction et erreurs du robot, et
  force de l'aide au renvoi. L'aide ne corrige que les tirs ratés (filet, dehors,
  dans son camp) ; un bon tir n'est jamais modifié.
- Raquette dans la main choisie (droite par défaut) : la face regarde dans la
  direction où pointe la manette. Service : **gâchette** lance la balle en l'air,
  on la frappe ensuite (un rebond chez soi est toléré). Volée autorisée.
- Table normale (2,74 m) ou compacte (x0,75) si la pièce est petite.
- Physique : pas de moteur, gravité simple, rebond table 0,9, raquette 0,55,
  test de traversée de la raquette (la balle ne passe jamais au travers).

## Pétanque

- Modes : **Contre l'ordi** (Marcel), **2 joueurs** (on se passe les manettes),
  **Entraînement** (3 boules, points selon la distance : <15 cm = 3, <40 cm = 2,
  <1 m = 1). Niveaux Facile / Normal / Expert, partie à 7 ou 13 points,
  terrain Normal (12 m, cochonnet à 6-10 m) ou Court (9 m, 4-7 m).
- Règles : celui qui lance le cochonnet joue la 1re boule ; la boule la plus
  éloignée du cochonnet rejoue (égalité : l'autre équipe) ; 3 boules chacun ;
  on marque un point par boule plus proche que la meilleure adverse. Boule
  sortie du terrain = morte. Cochonnet sorti = manche rejouée. Cochonnet non
  valable (hors repères) = on relance, puis l'arbitre le pose.
- En jeu : boule sur le support à droite ; **gâchette ou poignée** près d'elle
  pour la prendre, **relâcher** pour lancer. Distance affichée sur la boule qui
  tient le point.
- Geste amplifié (`THROW_GAIN_H` 2,1 / `THROW_GAIN_V` 1,45) : un lancer doux porte loin. L'aide simule où la boule s'arrêterait et la retient dans le terrain (niveaux Facile/Normal).
- « Changer de jeu » gèle et masque le jeu en cours (plus de balle qui traîne).
- Physique maison sans moteur : la même fonction sert au jeu et aux
  simulations de l'ordinateur (solveur de pointage par dichotomie, tir au fer).

## Mölkky

- Quilles 0,06 × 0,15 m, bâton 0,21 m ; couches de collision WORLD=1, PINS=4, STICK=8 ; sol d'herbe propre au jeu (friction 0,8).
- Après chaque lancer les quilles sont remises là où elles sont tombées (écartées de 0,068 m) et gelées jusqu'au lancer suivant.
- Limites Jolt dans `project.godot` (vitesses 25 / 60) pour éviter les quilles qui s'envolent.
- IA : vise la quille qui donne les points manquants, atterrit 0,3 m avant ; amortissement du bâton au sol 0,5 / 2,0. Réglage au casque à faire.
- Auto-test : `--selftest-molkky` (règles, parties complètes, entraînement, lancer humain simulé).
- Ordre prévu des ajouts : Palet (plusieurs variantes), Billard, Baby-foot, groupe Tir (ball-trap, carabine à plomb, pistolet, lancer de couteau).

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

- Pétanque : réglage fin du roulement au casque, mode équipes 2 contre 2.
- Ping-pong : mode à deux joueurs humains, effets (spin), détection d'une vraie table.
- Détection des tables et murs (scène Meta) pour le ping-pong et les fléchettes.
