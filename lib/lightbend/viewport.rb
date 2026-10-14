module Lightbend
  class Viewport
    attr_reader :image, :projection

    def initialize(scene, width, height)
      @scene = scene
      @width = width
      @height = height
      @projection = Projection.new(scene.camera, width, height)
      @pixels = Array.new(width * height, 0x1b1f26)
      @depths = Array.new(width * height, Float::INFINITY)
      @ids = Array.new(width * height)
      scene.objects.each { |entity| triangles(entity[:kind]).each { |triangle| rasterize(entity, triangle) } }
      @image = java.awt.image.BufferedImage.new(width, height, java.awt.image.BufferedImage::TYPE_INT_RGB)
      @image.set_rgb(0, 0, width, height, @pixels.to_java(:int), 0, width)
    end

    def triangles(kind)
      case kind
      when 'cube'
        corners = [-1.0, 1.0].repeated_permutation(3).to_a
        faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
        faces.flat_map { |a, b, c, d| [[corners[a], corners[b], corners[c]], [corners[a], corners[c], corners[d]]] }
      when 'plane'
        [[[-5.0, -5.0, 0.0], [5.0, -5.0, 0.0], [5.0, 5.0, 0.0]], [[-5.0, -5.0, 0.0], [5.0, 5.0, 0.0], [-5.0, 5.0, 0.0]]]
      when 'sphere'
        points = (0..8).map do |ring|
          phi = ring * Math::PI / 8
          (0..16).map do |segment|
            theta = segment * Math::PI / 8
            [Math.sin(phi) * Math.cos(theta), Math.sin(phi) * Math.sin(theta), Math.cos(phi)]
          end
        end
        (0...8).flat_map do |ring|
          (0...16).flat_map do |segment|
            a = points[ring][segment]
            b = points[ring + 1][segment]
            c = points[ring + 1][segment + 1]
            d = points[ring][segment + 1]
            [[a, b, c], [a, c, d]]
          end
        end
      end
    end

    def rasterize(entity, triangle)
      world = triangle.map { |point| @scene.world_point(entity, point) }
      projected = world.map { |point| projection.project(point) }
      return if projected.any?(&:nil?)

      a, b, c = projected
      area = ((b[1] - c[1]) * (a[0] - c[0])) + ((c[0] - b[0]) * (a[1] - c[1]))
      return if area.abs < 0.001

      normal = Math3.cross(Math3.sub(world[1], world[0]), Math3.sub(world[2], world[0]))
      shade = 0.45 + (0.55 * Math3.dot(Math3.normalize(normal), Math3.normalize([-1.0, -2.0, 3.0])).abs)
      color = entity[:color].map { |value| (value * shade).round }
      rgb = (color[0] << 16) | (color[1] << 8) | color[2]
      left = [projected.map(&:first).min.floor, 0].max
      right = [projected.map(&:first).max.ceil, @width - 1].min
      top = [projected.map { |v| v[1] }.min.floor, 0].max
      bottom = [projected.map do |v|
        v[1]
      end.max.ceil, @height - 1].min
      (top..bottom).each do |y|
        (left..right).each do |x|
          u = (((b[1] - c[1]) * (x + 0.5 - c[0])) + ((c[0] - b[0]) * (y + 0.5 - c[1]))) / area
          v = (((c[1] - a[1]) * (x + 0.5 - c[0])) + ((a[0] - c[0]) * (y + 0.5 - c[1]))) / area
          w = 1 - u - v
          next if u < -0.00001 || v < -0.00001 || w < -0.00001

          depth = 1.0 / ((u / a[2]) + (v / b[2]) + (w / c[2]))
          index = (y * @width) + x
          next unless depth < @depths[index]

          @depths[index] = depth
          @pixels[index] = rgb
          @ids[index] = entity[:id]
        end
      end
    end

    def pick(x, y)
      return nil if x < 0 || y < 0 || x >= @width || y >= @height

      @scene.lights.each do |light|
        screen = projection.project(light[:pos])
        return light[:id] if screen && ((screen[0] - x)**2) + ((screen[1] - y)**2) < 64
      end
      @ids[(y.to_i * @width) + x.to_i]
    end

    def arrows(id)
      entity = @scene.find(id)
      return [] unless entity

      origin = @scene.world_point(entity, [0.0, 0.0, 0.0])
      screen = projection.project(origin)
      return [] unless screen

      length = screen[2] * 0.16
      3.times.map do |axis|
        delta = [0.0, 0.0, 0.0]
        delta[axis] = length
        [screen, projection.project(Math3.add(origin, delta))]
      end
    end

    def drag_axis(id, axis, from, to)
      entity = @scene.find(id)
      origin = @scene.world_point(entity, [0.0, 0.0, 0.0])
      step = [0.0, 0.0, 0.0]
      step[axis] = 0.01
      screen = projection.project(origin)
      endpoint = projection.project(Math3.add(origin, step))
      return unless screen && endpoint

      dx = endpoint[0] - screen[0]
      dy = endpoint[1] - screen[1]
      return if (dx * dx) + (dy * dy) < 0.00001

      amount = (((to[0] - from[0]) * dx) + ((to[1] - from[1]) * dy)) / ((dx * dx) + (dy * dy)) * 0.01
      delta = [0.0, 0.0, 0.0]
      delta[axis] = amount
      @scene.translate_world(id, delta)
    end
  end
end
