# scenes

Game scenes.

- `Run.tscn` (Node2D, main scene) holds a `Camera2D` and an instance of `Ship.tscn`.
- `Ship.tscn` is a scriptless `CharacterBody2D` named `Ship` with a `Polygon2D` triangle and a `CollisionShape2D` with a `CircleShape2D`; the body type matches the planned ship.
- `Body.tscn`, `Carrier.tscn`, `Field.tscn` are empty `Node2D` roots.
