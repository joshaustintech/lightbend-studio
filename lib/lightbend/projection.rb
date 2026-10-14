module Lightbend
  class Projection
    attr_reader :width, :height

    def initialize(camera, width, height)
      @camera = camera
      @width = width
      @height = height
      @right = Math3.rotate([1.0, 0.0, 0.0], camera[:rot])
      @up = Math3.rotate([0.0, 1.0, 0.0], camera[:rot])
      @forward = Math3.rotate([0.0, 0.0, -1.0], camera[:rot])
      @focal = height / (2.0 * Math.tan(camera[:fov] * Math::PI / 360.0))
    end

    def ray(x, y)
      horizontal = Math3.mul(@right, (x - (width / 2.0)) / @focal)
      vertical = Math3.mul(@up, ((height / 2.0) - y) / @focal)
      [@camera[:pos], Math3.normalize(Math3.add(@forward, Math3.add(horizontal, vertical)))]
    end

    def project(point)
      delta = Math3.sub(point, @camera[:pos])
      depth = Math3.dot(delta, @forward)
      return nil if depth <= 0.05

      [(width / 2.0) + (Math3.dot(delta, @right) * @focal / depth),
       (height / 2.0) - (Math3.dot(delta, @up) * @focal / depth), depth]
    end
  end
end
