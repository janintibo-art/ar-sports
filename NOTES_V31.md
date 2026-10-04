# v31 — correction compilation des billes de billard

Base : v30. Version 0.31.0.

La v29 introduisait une erreur de compilation GDScript dans
`scripts/billard/bill_ball.gd` : Godot 4.7.2 ne pouvait pas inférer les types
des variables locales `du` et `d2` dans la génération des pastilles blanches.

Conséquence : la classe `BillBall` ne se chargeait plus. Les erreurs `Nil`
observées ensuite dans `_new_ball`, `_rack_balls`, `_strike` et les auto-tests
étaient des erreurs en cascade.

Correction :
- types explicites ajoutés à toutes les variables numériques sensibles de
  `texture_of()` ;
- conversion explicite de la valeur de boucle `cu_value` en `float` ;
- cache, mipmaps et rendu amélioré de la v29 conservés ;
- habillage de la queue de billard v30 conservé ;
- aucune règle, collision, dimension ni physique modifiée.
