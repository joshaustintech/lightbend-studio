# Lightbend Studio

Lightbend Studio is a desktop 3D scene editor for arranging simple objects and producing still images. Its first slice focuses on grouped primitives, materials, point lights, and saved scenes.

## Scene language

**Scene**:
A saved arrangement of objects, groups, one camera, and point lights.
_Avoid_: Project, world

**Object**:
A renderable primitive with a transform and material.
_Avoid_: Mesh (for the built-in cube, sphere, or plane)

**Primitive**:
One of the built-in cube, sphere, or plane shapes.
_Avoid_: Asset, imported mesh

**Group**:
A named set of objects whose transform applies to its members. Groups do not contain other groups in the first slice.
_Avoid_: Collection, folder

**Camera**:
The scene viewpoint used to frame a still render.
_Avoid_: View (when referring to the render viewpoint)

**Point light**:
A positioned light source with color and brightness.
_Avoid_: Lamp

## Appearance and output

**Material**:
An object's surface appearance, described by base color, reflection, specular, and roughness values.
_Avoid_: Shader (when referring to editable surface properties)

**Reflection**:
The amount of reflected scene contribution in an object's appearance; 100% is fully reflective and produces a sharp mirror at zero roughness.
_Avoid_: Shine

**Viewport**:
The interactive solid view used to select and arrange a scene.
_Avoid_: Render preview

**Still render**:
A single image rendered from the scene camera.
_Avoid_: Frame (when referring to a rendered image)
