# v29 — billes de billard

Base : v28, commit 8ddd29f. Version 0.29.0.

Cette version améliore uniquement le rendu procédural des billes de billard.

- Les textures des 16 billes sont désormais mises en cache et réutilisées au lieu d'être régénérées à chaque rack.
- Les textures génèrent des mipmaps pour limiter le scintillement des bandes et pastilles blanches à distance dans le casque.
- Les rayées ont une transition adoucie aux limites de la bande colorée.
- Les pastilles blanches ont un bord légèrement adouci.
- Un grain déterministe très discret évite l'aspect d'aplat parfaitement uniforme sans animation ni coût par image.
- Les couleurs et groupes réglementaires restent inchangés.

La physique, le rayon des billes (0,0285 m), les poches, les collisions, les règles 8/9 boules, l'IA et la détection de frappe ne sont pas modifiés.

Validation ajoutée : `tools/check_v29_billard_art.gd`, lancée dans GitHub Actions. Le test vérifie le cache, les mipmaps, les groupes, les dimensions de texture, l'intégration dans le jeu et le rayon inchangé.
