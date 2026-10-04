# v42 — correction syntaxe GitHub Actions

Base : v41. Version 0.42.0.

La v41 n'a créé aucun job GitHub Actions car le workflow YAML était invalide.

Cause :
la commande `printf` destinée à écrire `editor_settings` contenait des retours
à la ligne réels dans le bloc YAML, ce qui faisait sortir `[resource]` du bloc
`run: |`.

Correction :
- restauration de la commande `printf` sur une seule ligne ;
- séquences `\n` conservées littéralement dans le shell ;
- workflow validé localement comme YAML ;
- test graphique v41 conservé inchangé ;
- aucun changement au gameplay ou aux graphismes.
