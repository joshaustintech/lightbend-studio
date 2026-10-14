require_relative 'test_helper'

class RendererTest < Minitest::Test
  def scene_with_camera
    scene = Lightbend::Scene.new
    scene.update('camera', pos: [0.0, -6.0, 0.0], rot: [90.0, 0.0, 0.0])
    scene.update('light-1', pos: [-2.0, -4.0, 4.0])
    scene
  end

  def test_rendered_sphere_has_material_color_and_requested_dimensions
    scene = scene_with_camera
    sphere = scene.add('sphere')
    scene.update(sphere[:id], color: [255, 0, 0])
    image = Lightbend::Renderer.new(scene).render(48, 32)
    center = java.awt.Color.new(image.get_rgb(24, 16))
    assert_equal [48, 32], [image.width, image.height]
    assert_operator center.red, :>, center.green + 50
  end

  def test_mirror_plane_reflects_colored_object_behind_camera
    scene = scene_with_camera
    mirror = scene.add('plane')
    scene.update(mirror[:id], rot: [90.0, 0.0, 0.0], reflection: 100.0, color: [0, 255, 0])
    sphere = scene.add('sphere')
    scene.update(sphere[:id], pos: [0.0, -8.0, 0.0], color: [255, 0, 0])
    color = Lightbend::Renderer.new(scene).sample([0.0, -6.0, 0.0], [0.0, 1.0, 0.0])
    assert_operator color[0], :>, color[1] + 0.1
  end

  def test_scaled_rotated_cube_occludes_objects_behind_it
    scene = scene_with_camera
    sphere = scene.add('sphere')
    scene.update(sphere[:id], color: [255, 0, 0])
    cube = scene.add('cube')
    scene.update(cube[:id], pos: [0.0, -2.0, 0.0], rot: [0.0, 0.0, 30.0], scale: [0.5, 0.5, 0.5], color: [0, 255, 0])
    color = Lightbend::Renderer.new(scene).sample([0.0, -6.0, 0.0], [0.0, 1.0, 0.0])
    assert_operator color[1], :>, color[0] + 0.1
  end

  def test_point_light_shadow_and_color_change_the_still
    scene = scene_with_camera
    plane = scene.add('plane')
    scene.update(plane[:id], color: [255, 255, 255])
    scene.update('light-1', pos: [0.0, 0.0, 6.0], color: [0, 255, 0])
    origin = [0.0, -6.0, 1.0]
    direction = Lightbend::Math3.normalize([0.0, 6.0, -1.0])
    lit = Lightbend::Renderer.new(scene).sample(origin, direction)
    assert_operator lit[1], :>, lit[0] + 0.1
    cube = scene.add('cube')
    scene.update(cube[:id], pos: [0.0, 0.0, 2.0])
    shadow = Lightbend::Renderer.new(scene).sample(origin, direction)
    assert_operator shadow[1], :<, lit[1] * 0.5
  end

  def test_specular_highlight_is_visible_on_black_material
    scene = scene_with_camera
    scene.update('light-1', pos: [0.0, -6.0, 0.0])
    sphere = scene.add('sphere')
    scene.update(sphere[:id], color: [0, 0, 0])
    renderer = Lightbend::Renderer.new(scene)
    matte = renderer.sample([0.0, -6.0, 0.0], [0.0, 1.0, 0.0])
    scene.update(sphere[:id], specular: 100.0)
    shiny = renderer.sample([0.0, -6.0, 0.0], [0.0, 1.0, 0.0])
    assert_operator shiny[0], :>, matte[0] + 0.1
  end

  def test_roughness_blurs_the_reflection_instead_of_only_changing_the_ui
    scene = scene_with_camera
    mirror = scene.add('plane')
    scene.update(mirror[:id], rot: [90.0, 0.0, 0.0], reflection: 100.0)
    sphere = scene.add('sphere')
    scene.update(sphere[:id], pos: [0.0, -8.0, 0.0], color: [255, 0, 0])
    renderer = Lightbend::Renderer.new(scene)
    sharp = renderer.sample([0.0, -6.0, 0.0], [0.0, 1.0, 0.0])
    scene.update(mirror[:id], roughness: 100.0)
    rough = renderer.sample([0.0, -6.0, 0.0], [0.0, 1.0, 0.0])
    assert_operator rough[0] - rough[1], :<, (sharp[0] - sharp[1]) * 0.5
  end

  def test_exports_real_png_bmp_and_jpg_at_custom_resolution_and_rejects_unsafe_dimensions
    renderer = Lightbend::Renderer.new(scene_with_camera)
    image = renderer.render(23, 17)
    Dir.mktmpdir do |directory|
      %w[png bmp jpg].each do |format|
        path = File.join(directory, "still.#{format}")
        Lightbend::ImageFile.save(image, path, format)
        decoded = javax.imageio.ImageIO.read(java.io.File.new(path))
        assert_equal [23, 17], [decoded.width, decoded.height]
      end
    end
    assert_raises(ArgumentError) { renderer.render(0, 1080) }
    assert_raises(ArgumentError) { renderer.render(2**31, 2**31) }
    assert_nil renderer.render(32, 24, cancelled: -> { true })
  end
end
