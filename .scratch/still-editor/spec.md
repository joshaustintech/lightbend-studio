# Still-scene editor: first-slice contract

User-confirmed design, with remaining routine choices delegated. App/render logic is Ruby on pinned JRuby 10.1.2.0 and JDK 25; Swing and JDK XML/image APIs supply platform services. Validate macOS Apple Silicon first. The compatibility spike precedes editor work and records actual analyzer versions/results.

## User journey

Start with one perspective camera and an editable white point light. Add cube, sphere, plane and point lights; select through the scene tree or solid viewport; edit properties; group selected primitives; save XML; reopen it; render a still at a chosen resolution and format. The tree is left, viewport center, properties right, with creation commands above and render controls below.

## Scene editing

Right-handed Z-up unitless coordinates. Cube side 2, sphere radius 1, finite plane 10×10 before scaling. Named groups contain primitives, have transforms inherited by members, and do not nest. Position, degree rotations and positive scale are numeric; RGB X/Y/Z arrows translate objects/groups along world axes. Rotation/scale gizmos are deferred. Point lights are positioned with editable RGB and brightness, including additional user-created lights. One camera frames both preview and still; camera orbit/pan/dolly and numeric editing are supported.

## Surface appearance and stills

Per-object RGB color and reflection/specular/roughness percentages, each initially 0 and ranging 0–100. Fully reflective surfaces at zero roughness produce true mirrors; roughness broadens highlights and reflection samples. CPU preview shows solids/base colors. CPU ray tracer applies direct point lights, hard shadows, specular and reflected scene objects. Work is bounded to two reflection bounces and four deterministic rough-reflection samples; no indirect illumination or transparency. Rendering runs off the Swing event thread with progress/cancel and a snapshot of the scene.

Output supports PNG, BMP, JPG; PNG is the default. Width/height are entered as positive integers, initially 1920×1080, with no fixed preset-only restriction. Memory/image-array limits are checked before allocation. JPEG quality is 90%; a constant neutral background is used.

## XML contract and TDD

Human-readable XML scene files use schemaVersion 1 and a repository-owned XSD. Enforce XSD on reads and after writing temporary save bytes, then replace the target only when valid. Reject unknown versions, invalid values and references; forbid DTD/external resources. Tests prove valid and invalid schema cases, precision-preserving save/load, and preservation of existing files on failed saves.

Pre-agreed public test seams under the user's delegation: scene editing, scene-file validation/read/write, rendered image output, viewport projection/picking/axis drags, real Swing controls/dialogs and application lifetime. Use red → green vertical cycles at these boundaries. Full tests and zero RuboCop lint offenses block the harness; full RuboCop style, Reek smell and Flay duplication diagnostics remain visible advisory reports in this first slice.

## Scope and acceptance

No animation, mesh imports, nested groups, shared material assets, undo, rotation/scale gizmos, installer, other light types or soft shadows. macOS instructions must support clean setup and launch. Completion requires real visible desktop interactions, independently reopened persisted XML and encoded images, a full-resolution CPU render, all requested analyzer execution receipts and a passing complete harness.
