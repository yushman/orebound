# autoload

Global singletons registered in `project.godot`.

- `GravityField`, `Tuning`, `Telemetry` are `extends Node` stubs without logic; they are registered so later stages do not touch `project.godot`.
