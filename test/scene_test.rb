require_relative 'test_helper'

class SceneTest < Minitest::Test
  def test_grouped_objects_inherit_group_transforms_and_world_drag
    scene = Lightbend::Scene.new
    cube = scene.add('cube')
    scene.update(cube[:id], pos: [1.0, 0.0, 0.0])
    group = scene.group([cube[:id]], 'Assembly')
    scene.update(group[:id], pos: [2.0, 3.0, 0.0], rot: [0.0, 0.0, 90.0])
    point = scene.world_point(cube, [0.0, 0.0, 0.0])
    assert_in_delta 2.0, point[0]
    assert_in_delta 4.0, point[1]
    scene.translate_world(cube[:id], [1.0, 0.0, 0.0])
    assert_in_delta 3.0, scene.world_point(cube, [0.0, 0.0, 0.0])[0]
  end

  def test_invalid_property_edit_leaves_object_unchanged
    scene = Lightbend::Scene.new
    cube = scene.add('cube')
    assert_raises(ArgumentError) { scene.update(cube[:id], scale: [0.0, 1.0, 1.0]) }
    assert_equal [1.0, 1.0, 1.0], cube[:scale]
    assert_raises(ArgumentError) { scene.update(cube[:id], reflection: 101.0) }
  end

  def test_deleting_group_deletes_members_but_camera_is_protected
    scene = Lightbend::Scene.new
    cube = scene.add('cube')
    group = scene.group([cube[:id]], 'Assembly')
    scene.remove(group[:id])
    assert_nil scene.find(cube[:id])
    assert_nil scene.find(group[:id])
    assert_raises(ArgumentError) { scene.remove('camera') }
  end
end
