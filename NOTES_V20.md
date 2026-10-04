# AR Sports v20 — aide au survol et effets de réussite

Base : v19, commit fd640037f0d0bc0af65cd8374b6583a402122b26.

## Nouveautés

- Menu : le survol de chaque carte affiche le nom du jeu et deux lignes indiquant les gestes principaux. Le groupe Tir présente ses quatre disciplines. Le bouton Décor explique les deux qualités. Sans carte survolée, les instructions de sélection sont affichées.
- Le panneau d'aide n'apparaît qu'une fois l'intro terminée. Le menu se place à 1,15 m et légèrement moins bas, pour dégager la partie inférieure.
- Confettis courts autour des tableaux et de l'enseigne du bowling pour les événements de réussite déjà présents. Bowling : strike, spare et victoire. Fléchettes : bon tir, grande réussite et victoire. Tableau commun au ping-pong, pétanque, palet, billard, baby-foot et jeux de tir : événements point et win quand le jeu les déclenche. Mölkky : point et victoire. Les défaites, bust et rigoles ne déclenchent pas de confettis.
- Un seul effet actif par tableau : le suivant remplace le précédent. Destruction automatique après 0,8 s pour un petit événement ou 1,7 s pour un grand. Effet groupé dans un MultiMesh, sans lumières, collisions ni simulation de particules physiques. Qualité détaillée : 16 ou 40 confettis ; qualité légère : 6 ou 12.
- Les effets héritent de la pause et de la transformation du tableau : ils s'arrêtent avec le jeu suspendu et suivent le recentrage.

## Fichiers

scripts/menu.gd : panneau d'aide et placement du menu.
scripts/success_burst.gd : effet visuel partagé.
scripts/bowling/neon_sign.gd, scripts/darts/dart_scoreboard.gd, scripts/pingpong/ping_scoreboard.gd et scripts/molkky/mol_board.gd : raccordement aux célébrations existantes.
tools/check_v20_feedback.gd : contrôle des aides, largeurs, intro, nombre de confettis, remplacement, destruction et pause.
tools/shot_v20.gd : captures du menu et du bowling.
.github/workflows/build.yml : test supplémentaire avant l'export APK.
project.godot et export_presets.cfg : version affichée 0.20.0.
CONTEXTE.md, ce document et docs/*v20.png : suivi et aperçus, exclus de l'APK.

## Vérification

Godot 4.7.2 : suite complète des jeux et navigation terminée à OK, sans SCRIPT ERROR ni Parse Error. Tests d'interface v18, profils détaillé/léger v19 et nouveau test feedback_v20 terminés à OK. Les textes des neuf jeux ont été contrôlés, ainsi que le remplacement d'un effet, sa fin de vie et sa suspension.

Captures OpenGL inspectées : aide du ping-pong visible dans le menu et confettis autour de l'enseigne du bowling. Le fond gris correspond au mode écran sans casque. Les avertissements OpenXR sans casque et les avertissements de ressources à la fermeture restent présents ; ils ne sont pas présentés comme corrigés.

L'APK v20 n'a pas été exporté ici. GitHub doit compiler après application de la mise à jour. À vérifier dans le Quest : lisibilité du panneau d'aide, confort du nouveau placement du menu, effets lors d'un beau coup et fluidité. Aucun gain d'images par seconde n'a été mesuré au casque.
