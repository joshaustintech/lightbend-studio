require_relative 'test_helper'

class SceneFileTest < Minitest::Test
  def test_scene_file_round_trip_preserves_grouped_materials_and_lights
    scene = Lightbend::Scene.new
    sphere = scene.add('sphere')
    scene.update(sphere[:id], reflection: 100.0, roughness: 25.0, color: [20, 80, 200])
    scene.group([sphere[:id]], 'Mirror & floor')
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'scene.lbscene')
      Lightbend::SceneFile.save(scene, path)
      loaded = Lightbend::SceneFile.load(path)
      assert_equal(scene.entities.sort_by { |e| e[:id] }, loaded.entities.sort_by { |e| e[:id] })
    end
  end

  def test_scene_validation_rejects_internal_entities_and_invalid_contract_values
    scene = Lightbend::Scene.new
    scene.add('cube')
    valid = Lightbend::SceneFile.dump(scene)
    invalid = valid.sub('<?xml version="1.0" encoding="UTF-8"?>', '<!DOCTYPE scene [<!ENTITY label "hidden">]>')
    assert_raises(ArgumentError) { Lightbend::SceneFile.validate(invalid) }
    [valid.sub('schemaVersion="1"', 'schemaVersion="2"'),
     valid.sub('reflection="0.0"', 'reflection="101"'),
     valid.sub('<scale x="1.0"', '<scale x="0"'),
     valid.sub('<cube ', '<cube unknown="true" '),
     valid.sub('<cube ', '<cube group="missing" ')].each do |xml|
      assert_raises(ArgumentError) { Lightbend::SceneFile.parse(xml) }
    end
  end

  def test_failed_save_preserves_existing_scene
    scene = Lightbend::Scene.new
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'saved.lbscene')
      Lightbend::SceneFile.save(scene, path)
      original = File.read(path)
      scene.add('sphere')[:roughness] = 101
      assert_raises(ArgumentError) { Lightbend::SceneFile.save(scene, path) }
      assert_equal original, File.read(path)
    end
  end
  def test_small_finite_coordinates_save_as_xsd_decimal_without_precision_loss
    scene = Lightbend::Scene.new
    sphere = scene.add('sphere')
    scene.update(sphere[:id], pos: [1.0e-8, 0.0, 0.0], scale: [1.0e-6, 1.0, 1.0])
    xml = Lightbend::SceneFile.dump(scene)
    loaded = Lightbend::SceneFile.parse(xml)
    assert_equal 1.0e-8, loaded.objects.first[:pos][0]
    assert_equal 1.0e-6, loaded.objects.first[:scale][0]
  end

end
