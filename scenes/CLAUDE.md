# scenes

Game scenes.

- `Run.tscn` (Node2D, main scene) holds a `Camera2D`, an instance of `Ship.tscn`, and 3 `Body.tscn` instances: planet (`index` 0) and 2 moons (`index` 1, 2).
- `Ship.tscn` is a scriptless `CharacterBody2D` named `Ship` with a `Polygon2D` triangle and a `CollisionShape2D` with a `CircleShape2D`; the body type matches the planned ship.
- `Body.tscn` is a view: Node2D with `Body.gd` (`@export var index`) and a placeholder visual; `_physics_process` sets `position = GravityField.body_pos(index, GravityField.time())`. Params live in `Tuning.field`, not on the node.
- `Carrier.tscn`, `Field.tscn` are empty `Node2D` roots.
