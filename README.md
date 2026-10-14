# Lightbend Studio

JRuby 10.1.2.0 / JDK 25 / Swing desktop scene editor, initially validated on Apple Silicon macOS. Create cubes, spheres, planes and point lights; arrange named groups; save XSD-validated XML scenes; render still images on the CPU.

## Set up on macOS

1. Install an **arm64 JDK 25**. A standard macOS PKG from [Amazon Corretto](https://docs.aws.amazon.com/corretto/latest/corretto-25-ug/macos-install.html) or another JDK vendor works. The application requires Java 25, not merely a newer system Ruby.
2. Select that JDK in Terminal:

   ```sh
   export JAVA_HOME="$(/usr/libexec/java_home -v 25)"
   export PATH="$JAVA_HOME/bin:$PATH"
   java -version
   ```

   If SDKMAN or another version manager already selects JDK 25 and sets `JAVA_HOME`, keep that value instead. `java -version` must report version 25.
3. From the cloned repository:

   ```sh
   bin/setup
   bin/run
   ```

`bin/setup` downloads the pinned JRuby release into `.runtime/`, verifies its SHA-256, and installs the locked analyzer gems. Internet access is needed for initial setup. System Ruby is not used. The runtime and gems stay inside this repository; delete `.runtime/` to remove them.

For later shells, select JDK 25 again before running `bin/run`. Launch failures saying “JDK 25 required” mean `JAVA_HOME` or `PATH` selects another JDK.

## Edit a scene

- The scene tree is on the left, solid camera preview in the middle, properties on the right. A new scene contains one camera and one editable white point light.
- **Cube**, **Sphere**, **Plane**, **Point light** create entities. Primitives start at the origin. Cube side length is 2, sphere radius is 1, and the finite plane is 10×10; use scale to change dimensions.
- Click an object in the tree or viewport. Edit its name, XYZ position, rotation in degrees, positive XYZ scale, RGB channels (0–255), or material percentages, then **Apply properties** or press Enter.
- Reflection, specular and roughness range from 0–100%, initially 0%. Reflection 100% with roughness 0% gives a sharp mirror. Roughness spreads the specular highlight and samples blurred reflection. Preview keeps solids/base colors for quick layout; still rendering applies materials and lighting.
- Drag the red **X**, green **Y**, or blue **Z** arrow to translate the selection in world coordinates. Axes are right-handed and Z-up; coordinates are unitless. Rotation and scaling use numeric properties.
- Select multiple ungrouped primitives in the tree with Cmd-click or Shift-click, then **Group selected**. Name and transform the group in properties. Groups have one level; child transforms inherit the parent. **Delete** removes the selection; deleting a group also deletes its members. The camera cannot be deleted.
- Point lights have XYZ position, RGB color and brightness (0–10000%, default 100%). Their intensity falls with distance; they cast hard shadows in stills.
- Right-drag to orbit the camera around the origin, middle-drag to pan, and scroll to dolly. Numeric camera position, rotation and field of view also work. **Reset camera** restores its starting composition.

## Save and render

Use **File → Save scene** / **Save scene as…** for `.lbscene` XML files and **File → Open scene…** to reopen them. Open `examples/reflection.lbscene` for a small grouped scene with a mirror sphere and colored cube.

[The XSD](schema/scene-v1.xsd) requires schema version 1, valid transforms/materials, unique IDs and valid group references. Reads enforce the schema. Saves write a temporary file, validate the written bytes, then replace the target; invalid scenes preserve the old file. DTDs and external XML resources are forbidden. Unsupported schema versions fail clearly.

Still resolution starts at **1920×1080**. Enter positive integer width/height; press Enter to update camera-preview framing. Choose **PNG**, **BMP**, or **JPG** (default PNG), then **Render still…** and select the output file. JPG quality is 90%. Allocation checks reject resolutions exceeding a quarter of the JVM maximum heap or the image-array limit. Increase the JVM heap only when your machine has memory available.

Rendering runs in a worker using a scene snapshot, so the UI remains usable. The progress bar reports completed rows; **Cancel render** stops the job without saving a partial image. Edits made during a render apply to the next render.

## Check the implementation

```sh
bin/check
```

The full check runs core Minitest tests, visible Swing workflows (including actual mouse clicks and XYZ drags), and the analyzers under JRuby. Let the test window receive focus; tests move the mouse inside it. macOS may require permission for Java to control/capture its own test window. GUI tests retain app-window screenshots in `tmp/`.

For a terminal without desktop access:

```sh
bin/check --core
```

That is explicitly a partial check: desktop behavior is not verified. Tests fail on exceptions, invalid schema behavior, incorrect rendered pixels or exports, broken interactions, and unexpected event-thread failures.

Pinned analyzers: RuboCop 1.92.0, Flay 2.14.4, Reek 6.6.0. Tests and zero RuboCop **lint** offenses are blocking. Full RuboCop style, Reek smell and Flay duplication findings are advisory and retained visibly in `tmp/quality/`; this first slice does not claim those reports are clean. Analyzer crashes and malformed results fail the harness. See [the analyzer decision](docs/adr/0004-analyzer-gate.md).

[Execution evidence](docs/evidence/first-slice.md) records the tested runtime, commands, results and measured render timing. Test-first red/green logs are retained locally in `tmp/receipts/`.

## First-slice limits

Still images only: no animation, mesh imports, nested groups, shared material assets, undo, rotation/scale gizmos or installer. CPU renderer supports direct point lights, hard shadows and two reflection bounces; rough reflection uses four fixed deterministic samples and is an approximation. No transparency, global illumination or soft shadows. Other operating systems remain unvalidated.
