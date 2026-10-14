# JRuby, Swing, and CPU rendering for the first slice

Lightbend Studio will use Ruby for application and scene logic on JRuby 10.1.2.0 with JDK 25; Swing supplies the desktop UI. The first slice uses a CPU software-rasterized solid viewport and a CPU ray-traced still renderer, with no animation, imported meshes, or GPU renderer. A compatibility spike must prove the pinned runtime and record whether RuboCop, Flay, and Reek run on JRuby before UI work proceeds. This keeps the implementation aligned with the JVM desktop target while bounding the first deliverable to scene editing and stills.
