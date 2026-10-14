require_relative 'test_helper'

class ViewportTest < Minitest::Test
  def test_solid_preview_is_pickable_and_xyz_drag_moves_in_world_space
    scene = Lightbend::Scene.new
    scene.update('camera', pos: [0.0, -6.0, 0.0], rot: [90.0, 0.0, 0.0])
    sphere = scene.add('sphere')
    scene.update(sphere[:id], color: [255, 0, 0], reflection: 100.0)
    group = scene.group([sphere[:id]], 'Assembly')
    scene.update(group[:id], rot: [0.0, 0.0, 90.0])
    viewport = Lightbend::Viewport.new(scene, 160, 100)
    color = java.awt.Color.new(viewport.image.get_rgb(80, 50))
    assert_operator color.red, :>, color.green + 50
    assert_equal sphere[:id], viewport.pick(80, 50)
    from, to = viewport.arrows(sphere[:id])[0]
    viewport.drag_axis(sphere[:id], 0, from, to)
    position = scene.world_point(sphere, [0.0, 0.0, 0.0])
    assert_operator position[0], :>, 0.1
    assert_in_delta 0.0, position[1], 0.001
  end
end
