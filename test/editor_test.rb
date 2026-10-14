require_relative 'test_helper'
require_relative '../lib/lightbend/editor'

class EditorTest < Minitest::Test
  def setup
    @errors = java.util.concurrent.ConcurrentLinkedQueue.new
    @previous_handler = java.lang.Thread.default_uncaught_exception_handler
    java.lang.Thread.default_uncaught_exception_handler = ->(_thread, error) { @errors.add(error.to_s) }
  end

  def teardown
    on_ui { @editor.frame.dispose } if @editor
    assert @errors.empty?, @errors.to_a.join("\n")
  ensure
    java.lang.Thread.default_uncaught_exception_handler = @previous_handler
  end

  def on_ui(&block)
    error = nil
    javax.swing.SwingUtilities.invoke_and_wait do
      block.call
    rescue StandardError => e
      error = e
    end
    raise error if error
  end

  def component(name, root = @editor.frame)
    return root if root.name == name
    return nil unless root.respond_to?(:components)

    children = root.respond_to?(:menu_components) ? root.menu_components : root.components
    children.each do |child|
      found = component(name, child)
      return found if found
    end
    nil
  end

  def file_chooser(root)
    return root if root.is_a?(javax.swing.JFileChooser)
    return nil unless root.respond_to?(:components)

    root.components.each do |child|
      found = file_chooser(child)
      return found if found
    end
    nil
  end

  def approve_file_dialog(path)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    loop do
      approved = false
      on_ui do
        java.awt.Window.windows.select(&:visible?).each do |window|
          chooser = file_chooser(window)
          next unless chooser

          chooser.selected_file = java.io.File.new(path)
          chooser.approve_selection
          approved = true
          break
        end
      end
      return if approved
      raise 'File chooser did not appear' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def activate(name)
    on_ui { javax.swing.SwingUtilities.invoke_later { component(name).do_click } }
  end

  def test_visible_editor_creates_edits_saves_reopens_and_exports_a_scene
    on_ui do
      @editor = Lightbend::Editor.new
      @editor.show
    end
    Dir.mktmpdir do |directory|
      scene_path = File.join(directory, 'edited.lbscene')
      image_path = File.join(directory, 'still.png')
      on_ui do
        component('add.cube').do_click
        component('entity.name').text = 'First cube'
        component('position.x').text = '1.5'
        component('color.r').text = '220'
        component('color.g').text = '30'
        component('color.b').text = '15'
        component('material.reflection').text = '40'
        component('material.specular').text = '50'
        component('material.roughness').text = '20'
        component('properties.apply').do_click
        component('add.sphere').do_click
        component('position.x').text = '-2'
        component('properties.apply').do_click
        component('add.plane').do_click
        component('position.z').text = '-1'
        component('properties.apply').do_click
        component('add.light').do_click
        component('position.x').text = '4'
        component('position.y').text = '-4'
        component('position.z').text = '6'
        component('color.r').text = '50'
        component('color.g').text = '200'
        component('color.b').text = '255'
        component('light.brightness').text = '125'
        component('properties.apply').do_click
      end
      activate('file.save_as')
      approve_file_dialog(scene_path)
      activate('file.open')
      approve_file_dialog(scene_path)
      on_ui do
        component('render.width').text = '64'
        component('render.height').text = '36'
      end
      activate('render.start')
      approve_file_dialog(image_path)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20
      until File.exist?(image_path)
        raise 'Editor export timed out' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
      loaded = Lightbend::SceneFile.load(scene_path)
      cube = loaded.objects.find { |entity| entity[:kind] == 'cube' }
      assert_equal 'First cube', cube[:name]
      assert_equal [220, 30, 15], cube[:color]
      assert_in_delta 1.5, cube[:pos][0]
      assert_equal [40.0, 50.0, 20.0], cube.values_at(:reflection, :specular, :roughness)
      assert_equal 3, loaded.objects.length
      light = loaded.find('light-2')
      assert_equal [50, 200, 255], light[:color]
      assert_in_delta 125.0, light[:brightness]
      decoded = javax.imageio.ImageIO.read(java.io.File.new(image_path))
      assert_equal [64, 36], [decoded.width, decoded.height]
      robot = java.awt.Robot.new
      robot.auto_delay = 100
      point = nil
      on_ui do
        canvas = component('scene.viewport')
        point = canvas.screen(canvas.viewport.projection.project(cube[:pos]))
        location = canvas.location_on_screen
        point = [location.x + point[0], location.y + point[1]].map(&:round)
      end
      robot.mouse_move(*point)
      robot.mouse_press(java.awt.event.InputEvent::BUTTON1_DOWN_MASK)
      robot.mouse_release(java.awt.event.InputEvent::BUTTON1_DOWN_MASK)
      robot.wait_for_idle
      on_ui do
        assert_equal 'First cube', component('entity.name').text.to_s
        image = robot.create_screen_capture(@editor.frame.bounds)
        javax.imageio.ImageIO.write(image, 'png', java.io.File.new('tmp/editor.png'))
      end
    end
  ensure
    on_ui { @editor.frame.dispose } if @editor
  end

  def robot_click(robot, control)
    point = nil
    on_ui do
      location = control.location_on_screen
      point = [location.x + (control.width / 2), location.y + (control.height / 2)]
    end
    robot.mouse_move(*point)
    robot.mouse_press(java.awt.event.InputEvent::BUTTON1_DOWN_MASK)
    robot.mouse_release(java.awt.event.InputEvent::BUTTON1_DOWN_MASK)
    robot.wait_for_idle
  end

  def test_real_mouse_drag_moves_group_along_all_three_axes
    on_ui { @editor = Lightbend::Editor.new; @editor.show; @editor.frame.to_front }
    robot = java.awt.Robot.new
    robot.auto_delay = 150
    location = @editor.frame.location
    robot.mouse_move(location.x + 350, location.y + 12)
    robot.mouse_press(java.awt.event.InputEvent::BUTTON1_DOWN_MASK)
    robot.mouse_release(java.awt.event.InputEvent::BUTTON1_DOWN_MASK)
    robot.wait_for_idle
    robot_click(robot, component('add.cube'))
    on_ui { assert_equal 'Cube 1', component('entity.name').text.to_s }
    robot_click(robot, component('add.sphere'))
    on_ui { assert_equal 'Sphere 1', component('entity.name').text.to_s }
    on_ui do
      tree = component('scene.tree')
      paths = []
      tree.row_count.times do |row|
        path = tree.get_path_for_row(row)
        entry = path.last_path_component.user_object
        paths << path if entry.respond_to?(:id) && %w[cube-1 sphere-1].include?(entry.id)
      end
      tree.selection_paths = paths.to_java(javax.swing.tree.TreePath)
      component('group.create').do_click
      assert_equal 'Group 1', component('entity.name').text.to_s
    end
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'dragged.lbscene')
      previous = [0.0, 0.0, 0.0]
      3.times do |axis|
        points = nil
        on_ui do
          canvas = component('scene.viewport')
          start, finish = canvas.viewport.arrows(@editor.selected_id)[axis]
          first = canvas.screen(start)
          last = canvas.screen(finish)
          location = canvas.location_on_screen
          points = [0.55, 0.8].map do |amount|
            [location.x + first[0] + ((last[0] - first[0]) * amount),
             location.y + first[1] + ((last[1] - first[1]) * amount)].map(&:round)
          end
        end
        robot.mouse_move(*points[0])
        robot.mouse_press(java.awt.event.InputEvent::BUTTON1_DOWN_MASK)
        robot.mouse_move(*points[1])
        robot.mouse_release(java.awt.event.InputEvent::BUTTON1_DOWN_MASK)
        robot.wait_for_idle
        on_ui { @editor.save_scene(path) }
        group = Lightbend::SceneFile.load(path).entities.find { |entity| entity[:kind] == 'group' }
        assert group, 'Grouping through native Swing controls must create a group'
        assert_operator group[:pos][axis], :>, previous[axis] + 0.01
        previous = group[:pos]
      end
      on_ui do
        image = robot.create_screen_capture(@editor.frame.bounds)
        javax.imageio.ImageIO.write(image, 'png', java.io.File.new('tmp/editor-group.png'))
      end
    end
  ensure
    on_ui { @editor.frame.dispose } if @editor
  end

  def test_invalid_resolution_text_does_not_break_scene_editing
    on_ui do
      @editor = Lightbend::Editor.new
      @editor.show
      component('render.width').text = 'invalid'
      @editor.changed(refresh_tree: false)
      assert_raises(ArgumentError) { @editor.render_to('tmp/invalid-resolution.png') }
    end
  ensure
    on_ui { @editor.frame.dispose } if @editor
  end

  def test_cancel_button_stops_a_default_resolution_job_without_writing_an_image
    on_ui { @editor = Lightbend::Editor.new; @editor.show }
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'cancelled.png')
      on_ui do
        @editor.render_to(path)
        component('render.cancel').do_click
      end
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
      loop do
        message = nil
        on_ui { message = component('status').text.to_s }
        break if message.include?('cancelled')
        raise 'Cancel action timed out' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
      refute File.exist?(path)
    end
  ensure
    on_ui { @editor.frame.dispose } if @editor
  end

  def test_application_entrypoint_waits_for_window_close
    require_relative '../lib/lightbend/application'
    worker = Thread.new { Lightbend::Application.run }
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    window = nil
    until window
      on_ui { window = java.awt.Frame.frames.find { |frame| frame.name == 'studio.window' && frame.visible? } }
      raise 'Application did not open its window' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05 unless window
    end
    assert worker.alive?, 'Application must retain Ruby runtime while Swing is open'
    on_ui { window.dispose }
    assert worker.join(5), 'Application must return after the window closes'
  ensure
    on_ui { window.dispose } if window
    worker.kill if worker&.alive?
  end

end
