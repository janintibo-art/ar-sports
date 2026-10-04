# v30 — queue de billard

Base : v29, commit b25c141. Version 0.30.0.

Cette version améliore uniquement l'habillage visuel de la queue de billard.

- procédé bleu plus propre ;
- virole ivoire ;
- fût en bois texturé et légèrement conique ;
- collier décoratif ;
- poignée sombre ;
- talon en bois foncé ;
- bagues incrustées supplémentaires en qualité Détaillée ;
- ombres dynamiques désactivées sur les petites pièces.

La transformation du nœud `_cue` n'est pas remplacée. Les constantes de gameplay restent
`CUE_TIP = 0,60 m` et `CUE_BACK = 0,40 m`, soit une longueur logique totale inchangée de 1 m.
La détection de frappe, la vitesse du coup, les règles 8/9 boules, l'IA et la physique des billes
ne sont pas modifiées.

L'habillage est appliqué par `scripts/billard/cue_polish.gd`, isolé de la logique principale.
Le test `tools/check_v30_billard_cue.gd` vérifie l'intégration et les distances de référence.
