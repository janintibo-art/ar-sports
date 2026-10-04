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
- `scripts/menu.gd` : menu d'accueil (logo animé, 9 cartes en grille 3×3 ) ; intro au tout premier affichage.
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
- `scripts/palet.gd` : Palet (planche de bois, 3 variantes : Breton = rapprocher du maître, Planche à trous = 5 trous à 5/10/20 points, Cible = anneaux 1/2/3/5 comptés en fin de manche ; modes ordi / 2 joueurs / entraînement ; records `user://palet.cfg`). Dérivé de la pétanque, utilise PetBall.
- `scripts/billard.gd` : Billard (tapis 1,9 × 0,95 m, 8 boules et 9 boules, ordi Bob / 2 joueurs / entraînement ; physique maison des billes à plat ; queue tenue en main ; records `user://billard.cfg`).
- `scripts/billard/bill_ball.gd` : bille (position/vitesse 2D, texture pleines/rayées).
- `scripts/babyfoot.gd` : Baby-foot (table vue par le long côté, 8 barres / 22 joueurs, contre l'ordi ou défi 60 s ; records `user://babyfoot.cfg`).
- `scripts/babyfoot/bf_rod.gd` : une barre (position, joueurs, décalage, angle).
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

## Palet

- Planche 1,6 × 1,2 m à 3,5 ou 5 m. Un palet doit **atterrir sur la planche** (premier contact hors planche = mort ; un palet qui glisse hors de la planche est mort aussi).
- PetBall réglé pour un disque : `land_keep` 0,35, `roll_decel` 5,0, `ground_y`, `spin=false`. L'aide au lancer ramène l'arrêt dans `_rest_zone()` (le palet glisse ~0,4 m après l'atterrissage).
- Trous : capture si le centre passe à moins de 0,075 m (même en glissant). Cible : points selon la distance du centre.
- Auto-test : `--selftest-palet` ; captures : `tools/shot_palet.gd`.

## Billard

- Billes en 2D (Vector2) : 8 sous-pas par image, décélération 0,32 m/s², bandes 0,74, chocs 0,95, poches par distance (coin 0,075 / milieu 0,062).
- Queue : on l'attrape (gâchette/grip) près du support ; la pointe est à 0,6 m devant la main ; frappe détectée quand la pointe touche la blanche à plus de 0,45 m/s, tir dans l'axe horizontal de la queue (vitesse ×1,5). Guide de visée (ligne, bille fantôme, trajectoire de la bille touchée) sauf niveau Expert.
- Règles dans `resolve_shot()` (testables) : 8 boules (groupes, faute, noire), 9 boules (plus petite d'abord, le 9 gagne). Après faute, la blanche se replace à la main. Arbitre après 70 coups (pour que les parties finissent).
- Auto-test : `--selftest-billard` ; captures : `tools/shot_billard.gd`.

## Baby-foot

- Table 1,2 × 0,68 m, buts de 0,22 m ; la balle est en 2D (6 sous-pas), pieds et corps = cercles (la vitesse du pied vient de la différence d'angle d'une image à l'autre).
- Vous défendez à gauche (-x) et attaquez vers +x. On attrape une barre près de sa poignée (côté joueur), l'avancer/reculer la fait glisser, la vitesse de la main le long de la table (x) la fait tourner (`SPIN_GAIN` 30). Les barres libres suivent la balle (aide selon le niveau).
- L'ordi : suit la balle (vitesse/latence par niveau), frappe quand un joueur est aligné et que la balle est devant.
- Balle immobile 2,5 s = remise en jeu.
- Auto-test : `--selftest-babyfoot` ; captures : `tools/shot_babyfoot.gd`.


## Tir (groupe) et Tir à l'arc
- `scripts/tir.gd` (TirGame) : écran de choix de discipline ; chaque discipline = un script dans `scripts/tir/` listé dans `TirGame.DISCIPLINES` ({id, title, script}). Il relaie boutons, pause et selftest. Pour ajouter une discipline : nouveau script avec l'interface habituelle + une entrée dans DISCIPLINES.
- `scripts/tir/arc.gd` (ArcGame) + `arc_arrow.gd` : arc dans une main (réglage gauche/droite), l'autre main saisit la corde (gâchette/prise), on tire en arrière, relâcher = tir dans l'axe (arc − corde). Puissance selon l'allonge (0,25 à 0,7 m), tir à vide ignoré.
- Cible à 10/20/30 m, centre à 1,3 m ; points 10 − floor(10·r/R), botte de paille ; flèches plantées. Gravité, traînée 2 %, vent latéral.
- Modes : Concours vs Robin (3 ou 5 volées de 3 flèches), Entraînement (record de volée), Cible mobile (10 flèches, record). Niveaux : facile (pas de vent, trajectoire affichée), normal (vent 2), expert (vent 5).
- Sauvegarde `user://arc.cfg`. Selftest `--selftest-arc` / `--selftest-tir` (barème, visée balistique, chute, vent, tirs réels, concours ×3, mobile, entraînement).

## Carabine à plomb
- `scripts/tir/carabine.gd` (CarabineGame) : carabine dans la main de tir (réglage gauche/droite). Si l'autre main est devant (0,2–0,8 m, dans l'axe), on vise le long de la ligne main -> main (stable), sinon dans l'axe de la main. Gâchette de la main de tir = un plomb (cadence 0,3 s).
- Plomb : 150 m/s, gravité, canon relevé automatiquement pour toucher à la distance réglée (`zero_pitch`). Détection par franchissement du plan de la cible.
- Jeux : Concours contre Robin (3 ou 5 séries de 5 plombs, cible papier 10 zones, 10 ou 25 m), Entraînement (record de série), Stand de foire (60 s : boîtes 5 pts, canards mobiles 10 pts, étoile bonus 25 pts, record).
- Niveaux : facile (point rouge d'aide, cibles plus grandes/lentes), normal, expert (cibles petites/rapides, Robin plus précis).
- Sons ajoutés : `air_shot`, `can_ping` (générés par `tools/make_sounds.py`). Sauvegarde `user://carabine.cfg`.
- Selftest : barème, tir au centre à 10 et 25 m, cadence, hors cible, mi-rayon, boîte/canard, concours ×3, stand, entraînement.

## Ball-trap
- `scripts/tir/balltrap.gd` (BallTrapGame) : fusil dans la main de tir (même visée à deux mains que la carabine). Le plateau d'argile part après « Pull ! » ; 2 cartouches par plateau (touché au 1er coup 2 pts, au 2e 1 pt). On joue contre Robin (il tire chaque plateau avec une probabilité selon le niveau).
- Parcours : Fosse (machine devant, direction aléatoire), Skeet (deux maisons, traversées), Chasse (trois types : fuyant, traversant, plongeant). 10 ou 25 plateaux. Niveaux : facile (gerbe large, plateaux lents), normal, expert (gerbe serrée, rapides).
- Gerbe de plomb : tir « balayé » à 350 m/s ; touché si la distance plateau–trajectoire ≤ rayon du plateau + angle de gerbe × distance. `lead_point()` calcule l'anticipation (utilisé par le bot de test).
- Sons ajoutés : `shotgun`, `clay_break`. Sauvegarde `user://balltrap.cfg` (records par parcours).
- Selftest : touché 1er coup, anticipation, tir derrière, 2e cartouche et points, pas de tir sans plateau / 3e cartouche, 3 parties complètes.

## Lancer de couteau
- `scripts/tir/couteau.gd` (CouteauGame) : trois couteaux sur une table devant le joueur (`HOLDER_POS`) ; gâchette ou grip près d'un couteau = on le prend (il suit la main), on relâche pour lancer (vitesse de la main × 1,3, minimum 2,5 m/s, sinon le couteau revient).
- Le couteau tourne : un tour complet exactement jusqu'au plan de la cible (`omega = 2π / temps de vol`), plus une erreur d'angle aléatoire selon le niveau (12°/22°/34°). Il se plante si l'erreur ≤ 45°, sinon il rebondit (0 pt, « Pas planté ! »). Trop court = tombe au sol.
- Aide à la visée comme aux fléchettes (`_apply_assist`, 0,75/0,45/0,15 : rapproche la trajectoire du centre sans changer le temps de vol).
- Cible : rondin à 3, 4,5 ou 6 m, 10 zones de largeur égale. Jeux : Concours contre Robin (3 ou 5 manches de 3 couteaux), Entraînement (record de manche), Rondin mobile (9 couteaux, record).
- Sauvegarde `user://couteau.cfg`. Selftest : barème, planté à 3 et 6 m, rebond, lancer faible/court, aide, concours ×3, rondin mobile, entraînement.
- Groupe Tir terminé : arc, carabine à plomb, ball-trap, lancer de couteau.

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

## v18 — analyse et matériaux

Base v17 (82627ec), livraison différentielle ar_sports_v18.zip. Menu à coins arrondis, textes ajustés, matériaux partagés en cache et filet ajouré. Ombres de décor locales ; ancien jeu retiré avant création du suivant ; menu désactivé pendant les jeux. Version affichée 0.18.0. Régressions : tools/check_visual_ui.gd, lancé dans le CI. Voir ANALYSE_V18.md pour les constats, limites et priorités.

## v19 — personnages et ambiances

Base v18 (4a0b211). Personnages expressifs et vêtements détaillés dans Spectator. Accessoires par sport via Decor.sport_corner. VisualStyle (classe à préférence statique) mémorise Décor détaillé/léger ; bouton du menu, appliqué au prochain jeu. Test tools/check_v19_style.gd dans le CI, captures tools/shot_v19.gd. Voir NOTES_V19.md. Version affichée 0.19.0.

## v20 — aide au menu et célébrations

Base v19 (fd64003). Aide gestuelle au survol des neuf jeux, menu placé à 1,15 m. SuccessBurst : confettis groupés MultiMesh, un effet par tableau, durée limitée et réduction en qualité légère. Raccordé aux célébrations existantes des tableaux et de l’enseigne bowling. Test tools/check_v20_feedback.gd dans le CI. Captures tools/shot_v20.gd. Version 0.20.0 ; voir NOTES_V20.md.

## v21 — confort commun

Base v20 (08abce5). Bouton Confort à l’accueil : tailles 100/115/130 %, distance Proche/Normal/Éloigné. VisualStyle mémorise ces choix avec la qualité graphique sans les écraser. UiPanel applique les facteurs au placement ; menu également. Panneau géré dans main.gd ; Menu/BY ferme, AX recentre. Test tools/check_v21_comfort.gd ajouté au CI. Voir NOTES_V21.md. Version 0.21.0.

## v22 — réglages des gestes

Base v21 (46e6b39). Confort possède deux onglets Menus/Gestes. VisualStyle sauvegarde throw_gain, cue_gain et rod_gain ; valeurs par défaut 1.0. Hand.throw_velocity applique le facteur aux lancers humains. Billard ajuste la vitesse du coup humain ; baby-foot ajuste la rotation des barres tenues. Reset indépendant par onglet. Test tools/check_v22_gestures.gd dans le CI ; capture tools/shot_v22.gd. Voir NOTES_V22.md. Version 0.22.0.

## v23 — guide des commandes

Base v22 (6cf887a). Troisième onglet Guide dans Confort : 13 fiches (commandes communes et 12 disciplines) via QuickGuide.PAGES. Navigation circulaire, page gardée en session ; guide réservé au menu principal. UiPanel.add_text crée un texte informatif sans collision. Test tools/check_v23_guide.gd intégré au CI, captures tools/shot_v23.gd. Voir NOTES_V23.md. Version 0.23.0.

## v24 — réglages audio

Base v23 (ac0d936). Confort > Audio : général, musique, effets (muet/50/100 %) et test sonore. VisualStyle stocke les trois volumes, défaut 1. Sound crée des bus dédiés et route tous les lecteurs ; main applique au démarrage et au changement. Reset audio indépendant. Test tools/check_v24_audio.gd intégré au CI, test du guide adapté aux quatre onglets. Capture tools/shot_v24.gd. Voir NOTES_V24.md. Version 0.24.0.

## v25 — modèles de carabine et ball-trap

Base v24 (bf94a52). GunArt génère un habillage statique regroupé : crosse profilée, bois texturé, garde-main, métal, pontet, détente, détails selon qualité. Un mesh, 4/5 surfaces ; 1012/1264 triangles détaillés, 688/868 légers. _build_gun des deux disciplines remplacé sans modifier la visée ni les tirs. Test tools/check_v25_models.gd intégré au CI ; captures tools/shot_v25.gd. Voir NOTES_V25.md. Version 0.25.0.

## v26 — arc, flèches et couteaux

Base v25 (206d8ea). RangedArt génère les habillages statiques : arc profilé, empennages de flèche, lame et manche de couteau. Meshes partagés en cache, un nœud de rendu par modèle. GunArt.batch réutilisable ; métadonnées des fusils préservées. Remplacement des seules constructions visuelles dans arc.gd et couteau.gd ; corde et trajectoires inchangées. Test tools/check_v26_ranged.gd intégré au CI, captures tools/shot_v26.gd. Voir NOTES_V26.md. Version 0.26.0.

## v27 — fléchettes et cible

Base v26 (8ea0ad8). DartArt : corps métallique groupé et partagé par profil, ailettes profilées partagées, texture grain 128 × 128 en cache. Couleurs conservées par objet. Dart utilise ces habillages sans changement de pointe ni logique de vol ; Dartboard ajoute texture et UV sans changement de score. Test tools/check_v27_darts_art.gd dans le CI, captures tools/shot_v27.gd. Voir NOTES_V27.md. Version 0.27.0.

Livraison utilisateur : un seul ZIP différentiel ar_sports_vN.zip et deux commandes Termux séparées. L’application affiche souvent le nouveau ZIP sous forme de petit bouton qui ne télécharge pas ; le même lien renvoyé dans une réponse suivante apparaît souligné et fonctionne (confirmé le 4 octobre). La mise sur une ligne seule n’a pas corrigé le problème en v27. Reprendre la forme « Voici de nouveau le ZIP : [nom du ZIP](sandbox:/chemin/absolu) », sans promettre de contrôler le rendu de l’application.

## v28 — équipements de ping-pong

Base v27 (f0db98c). PingArt : raquette au manche arrondi, bois et revêtements texturés, détails selon profil. Mesh partagé par couleur et qualité ; émission AI conservée. Balle orange mate avec couture, tessellation selon qualité. Seules constructions visuelles modifiées ; rayons de collision, services et rebonds inchangés. Test tools/check_v28_ping_art.gd dans le CI, capture tools/shot_v28.gd. Voir NOTES_V28.md. Version 0.28.0.

## v50 — menus et tables

Base v49. `UiPanel.floor_clearance` empêche le panneau de descendre dans la table (ping-pong, baby-foot, billard) selon la hauteur de tête et la taille de menu. Test tools/check_v50_menu_clearance.gd intégré au CI. Voir NOTES_V50.md. Version 0.50.0.
