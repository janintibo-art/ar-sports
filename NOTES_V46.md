# v46 — correction appel différé terrain baby-foot

Base : v45. Version 0.46.0.

La v45 pouvait déclencher une erreur pendant certains tests qui créent puis
détruisent rapidement une scène de baby-foot.

Cause :
`_apply_later(game: Node)` recevait directement un objet dans un `call_deferred`.
Si le jeu était libéré avant l'exécution, Godot échouait lors du binding du
paramètre typé avant que `is_instance_valid()` puisse être appelé.

Correction :
- l'appel différé transmet désormais uniquement `get_instance_id()` ;
- après une frame, `instance_from_id()` retrouve le jeu s'il existe encore ;
- si l'instance a été libérée, la fonction s'arrête proprement ;
- `_apply()` accepte une valeur non typée et revalide l'instance.

Aucun changement visuel, physique ou de gameplay.
