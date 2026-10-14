module Lightbend
  class Canvas < javax.swing.JPanel
    AXIS_COLORS = [java.awt.Color.new(235, 70, 70), java.awt.Color.new(65, 205, 100),
                   java.awt.Color.new(70, 130, 255)].freeze

    attr_reader :viewport

    def initialize(editor)
      super()
      @editor = editor
      set_name('scene.viewport')
      set_background(java.awt.Color.new(20, 23, 29))
      listener = Input.new(self)
      add_mouse_listener(listener)
      add_mouse_motion_listener(listener)
      add_mouse_wheel_listener(listener)
    end

    def refresh
      width, height = @editor.preview_resolution
      ratio = width.to_f / height
      preview_width = [(480 * [ratio, 1.0].min).round, 1].max
      preview_height = [(preview_width / ratio).round, 1].max
      @viewport = Viewport.new(@editor.scene, preview_width, preview_height)
      repaint
    end

    def frame_rect
      ratio = @viewport.image.width.to_f / @viewport.image.height
      frame_width = [width - 24, (height - 24) * ratio].min
      frame_height = frame_width / ratio
      [(width - frame_width) / 2.0, (height - frame_height) / 2.0, frame_width, frame_height]
    end

    def screen(point)
      rect = frame_rect
      [rect[0] + (point[0] * rect[2] / @viewport.image.width), rect[1] + (point[1] * rect[3] / @viewport.image.height)]
    end

    def model(point)
      rect = frame_rect
      [(point[0] - rect[0]) * @viewport.image.width / rect[2], (point[1] - rect[1]) * @viewport.image.height / rect[3]]
    end

    def paintComponent(graphics)
      graphics.color = background
      graphics.fill_rect(0, 0, width, height)
      return unless @viewport

      rect = frame_rect.map(&:round)
      graphics.draw_image(@viewport.image, *rect, nil)
      graphics.color = java.awt.Color.new(130, 135, 145)
      graphics.draw_rect(*rect)
      @editor.scene.lights.each do |light|
        point = @viewport.projection.project(light[:pos])
        next unless point

        x, y = screen(point).map(&:round)
        graphics.color = java.awt.Color.new(*light[:color])
        graphics.draw_oval(x - 6, y - 6, 12, 12)
        graphics.draw_line(x - 10, y, x + 10, y)
        graphics.draw_line(x, y - 10, x, y + 10)
      end
      @viewport.arrows(@editor.selected_id).each_with_index do |(from, to), axis|
        next unless from && to

        x1, y1 = screen(from).map(&:round)
        x2, y2 = screen(to).map(&:round)
        graphics.color = AXIS_COLORS[axis]
        graphics.set_stroke(java.awt.BasicStroke.new(3.0))
        graphics.draw_line(x1, y1, x2, y2)
        length = Math.sqrt(((x2 - x1)**2) + ((y2 - y1)**2))
        if length > 1
          dx = (x2 - x1) / length
          dy = (y2 - y1) / length
          arrow_x = [x2, (x2 - (13 * dx) + (5 * dy)).round, (x2 - (13 * dx) - (5 * dy)).round]
          arrow_y = [y2, (y2 - (13 * dy) - (5 * dx)).round, (y2 - (13 * dy) + (5 * dx)).round]
          graphics.fill_polygon(arrow_x.to_java(:int), arrow_y.to_java(:int), 3)
        end
        graphics.draw_string(%w[X Y Z][axis], x2 + 7, y2 - 7)
      end
      graphics.color = java.awt.Color.new(195, 200, 210)
      graphics.draw_string('Camera framing • Right drag: orbit • Middle drag: pan • Scroll: dolly', 12, height - 8)
    end

    def press(event)
      @previous = [event.x.to_f, event.y.to_f]
      @drag_mode = if javax.swing.SwingUtilities.is_right_mouse_button(event)
                     :orbit
                   elsif javax.swing.SwingUtilities.is_middle_mouse_button(event)
                     :pan
                   else
                     :select
                   end
      return unless @drag_mode == :select

      @axis = @viewport.arrows(@editor.selected_id).each_with_index.find do |(from, to), _axis|
        from && to && segment_distance(@previous, screen(from), screen(to)) < 8
      end&.last
      return unless @axis.nil?

      id = @viewport.pick(*model(@previous))
      @editor.select(id) if id
    end

    def drag(event)
      return unless @previous

      current = [event.x.to_f, event.y.to_f]
      dx = current[0] - @previous[0]
      dy = current[1] - @previous[1]
      case @drag_mode
      when :select
        return if @axis.nil?

        @viewport.drag_axis(@editor.selected_id, @axis, model(@previous), model(current))
      when :orbit then orbit(dx, dy)
      when :pan then pan(dx, dy)
      end
      @previous = current
      @editor.changed(refresh_tree: false)
    end

    def wheel(event)
      camera = @editor.scene.camera
      forward = Math3.rotate([0.0, 0.0, -1.0], camera[:rot])
      @editor.scene.translate_world(camera[:id], Math3.mul(forward, -event.wheel_rotation * 0.5))
      @editor.changed(refresh_tree: false)
    end

    def segment_distance(point, from, to)
      dx = to[0] - from[0]
      dy = to[1] - from[1]
      return Float::INFINITY if (dx * dx) + (dy * dy) < 4

      amount = [[(((point[0] - from[0]) * dx) + ((point[1] - from[1]) * dy)) / ((dx * dx) + (dy * dy)), 0].max, 1].min
      Math.sqrt(((point[0] - from[0] - (amount * dx))**2) + ((point[1] - from[1] - (amount * dy))**2))
    end

    def orbit(dx, dy)
      camera = @editor.scene.camera
      radius = [Math.sqrt(Math3.dot(camera[:pos], camera[:pos])), 0.5].max
      azimuth = Math.atan2(camera[:pos][1], camera[:pos][0]) - (dx * 0.01)
      elevation = [[Math.asin([[camera[:pos][2] / radius, -1].max, 1].min) + (dy * 0.01), -1.5].max, 1.5].min
      position = [radius * Math.cos(elevation) * Math.cos(azimuth), radius * Math.cos(elevation) * Math.sin(azimuth),
                  radius * Math.sin(elevation)]
      @editor.scene.update(camera[:id], pos: position,
                                        rot: [90 - (elevation * 180 / Math::PI), 0.0, 90 + (azimuth * 180 / Math::PI)])
    end

    def pan(dx, dy)
      camera = @editor.scene.camera
      right = Math3.rotate([1.0, 0.0, 0.0], camera[:rot])
      up = Math3.rotate([0.0, 1.0, 0.0], camera[:rot])
      delta = Math3.add(Math3.mul(right, -dx * 0.02), Math3.mul(up, dy * 0.02))
      @editor.scene.translate_world(camera[:id], delta)
    end

    class Input < java.awt.event.MouseAdapter
      def initialize(canvas)
        super()
        @canvas = canvas
      end

      def mousePressed(event) = @canvas.press(event)
      def mouseDragged(event) = @canvas.drag(event)
      def mouseWheelMoved(event) = @canvas.wheel(event)
    end
  end
end
