# Public test seams and bounded still rendering

The user delegated remaining implementation decisions. TDD exercises scene editing, XML/XSD persistence, rendered images, viewport interactions and the actual Swing editor through public boundaries. Scene files use schema version 1 and right-handed Z-up unitless coordinates; translation gizmos use world axes. Materials belong to each object. The CPU still renderer uses two reflection bounces and four deterministic samples for rough reflection, hard point-light shadows and no global illumination. Rendering runs off Swing's event thread with progress/cancel and allocation checks; these bounds keep the first slice usable without adding animation or a graphics engine.

The Ruby application entrypoint waits for window closure using a JDK latch, so Swing callbacks retain a live Ruby runtime. The lifecycle boundary is tested alongside the visible editor journeys.
