# v24 — réglages audio communs

Base : v23, commit ac0d936. Version 0.24.0.

Confort contient un onglet Audio : volume général, musique, effets. Chaque ligne propose Muet, 50 % et 100 %. Le volume général multiplie les deux autres. Effets inclut les bruitages, les annonces, les clics et l’ambiance. Le bouton Tester un son joue un tintement au niveau choisi. Il reste silencieux si Général ou Effets est muet.

Les changements s’appliquent immédiatement, y compris aux boucles déjà en cours, puis sont mémorisés avec les autres préférences. À 100 %, les volumes antérieurs du jeu sont conservés ; la v24 n’amplifie pas les sons au-delà de leurs niveaux existants. Réinitialiser dans Audio restaure uniquement les trois volumes. Les choix musicaux de chaque jeu restent respectés : régler le volume ne force pas une musique désactivée.

## Architecture et fichiers

- scripts/sound.gd : trois bus ARGeneral, ARMusic, AREffects. Les deux derniers passent par ARGeneral, puis Master. Tous les lecteurs sont routés, dont les lecteurs temporaires et les boucles attachées aux objets. Les niveaux individuels et la spatialisation sont conservés.
- scripts/visual_style.gd : section audio dans la sauvegarde existante, valeurs bornées entre 0 et 1, défaut 1 pour les anciens profils.
- scripts/main.gd : application au démarrage et onglet Audio, test sonore, réinitialisation indépendante.
- scripts/menu.gd, scripts/quick_guide.gd : descriptions actualisées.
- tools/check_v24_audio.gd : routage, absence de bus dupliqués, application aux boucles actives, mute indépendant, conversion du niveau, sauvegarde/rechargement, préservation des autres réglages et réinitialisation. Ajout au CI.
- tools/check_v23_guide.gd : adapté au quatrième onglet.
- tools/shot_v24.gd, docs/audio_v24.png : capture de l’interface, exclue de l’APK.

## Validation

Tests audio, guide, interface, confort et gestes relancés ; suite des jeux et navigation relancée. Capture OpenGL inspectée. Les vérifications audio contrôlent le routage et les niveaux du moteur : l’écoute et le confort sonore restent à vérifier dans le Quest.

Sans casque, OpenXR utilise le mode écran. Les avertissements existants de ressources à la fermeture subsistent. L’export APK sera effectué par GitHub après application de cette mise à jour.
