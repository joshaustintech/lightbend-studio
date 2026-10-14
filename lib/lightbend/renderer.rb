module Lightbend
  class Renderer
    BACKGROUND = [0.06, 0.07, 0.09].freeze
    EPSILON = 0.0001

    def initialize(scene)
      @scene = scene
    end

    def hit(origin, direction)
      @scene.objects.filter_map do |entity|
        local_origin = @scene.local_point(entity, origin)
        local_direction = @scene.local_point(entity, direction, vector: true)
        intersection = case entity[:kind]
                       when 'sphere' then sphere_hit(local_origin, local_direction)
                       when 'plane' then plane_hit(local_origin, local_direction)
                       when 'cube' then cube_hit(local_origin, local_direction)
                       end
        next unless intersection

        distance, normal = intersection
        world_normal = @scene.world_normal(entity, normal)
        world_normal = Math3.mul(world_normal, -1) if Math3.dot(world_normal, direction).positive?
        [distance, entity, world_normal]
      end.min_by(&:first)
    end

    def sphere_hit(origin, direction)
      a = Math3.dot(direction, direction)
      b = 2 * Math3.dot(origin, direction)
      c = Math3.dot(origin, origin) - 1
      discriminant = (b * b) - (4 * a * c)
      return nil if discriminant.negative?

      roots = [(-b - Math.sqrt(discriminant)) / (2 * a), (-b + Math.sqrt(discriminant)) / (2 * a)]
      distance = roots.select { |t| t > EPSILON }.min
      return nil unless distance

      [distance, Math3.add(origin, Math3.mul(direction, distance))]
    end

    def plane_hit(origin, direction)
      return nil if direction[2].abs < EPSILON

      distance = -origin[2] / direction[2]
      point = Math3.add(origin, Math3.mul(direction, distance))
      return nil unless distance > EPSILON && point[0].abs <= 5 && point[1].abs <= 5

      [distance, [0.0, 0.0, 1.0]]
    end

    def cube_hit(origin, direction)
      near = -Float::INFINITY
      far = Float::INFINITY
      3.times do |axis|
        if direction[axis].abs < EPSILON
          return nil if origin[axis].abs > 1

          next
        end
        first, last = [(-1 - origin[axis]) / direction[axis], (1 - origin[axis]) / direction[axis]].sort
        near = [near, first].max
        far = [far, last].min
        return nil if near > far
      end
      distance = near > EPSILON ? near : far
      return nil if distance <= EPSILON

      point = Math3.add(origin, Math3.mul(direction, distance))
      axis = (0..2).max_by { |index| point[index].abs }
      normal = [0.0, 0.0, 0.0]
      normal[axis] = point[axis].positive? ? 1.0 : -1.0
      [distance, normal]
    end

    def sample(origin, direction, depth = 0)
      intersection = hit(origin, direction)
      return BACKGROUND unless intersection

      distance, entity, normal = intersection
      point = Math3.add(origin, Math3.mul(direction, distance))
      base = entity[:color].map { |channel| (channel / 255.0)**2.2 }
      shaded = base.map { |channel| channel * 0.12 }
      @scene.lights.each do |light|
        delta = Math3.sub(light[:pos], point)
        light_distance = Math.sqrt(Math3.dot(delta, delta))
        light_direction = Math3.mul(delta, 1.0 / [light_distance, EPSILON].max)
        obstruction = hit(Math3.add(point, Math3.mul(normal, EPSILON)), light_direction)
        next if obstruction && obstruction[0] < light_distance - EPSILON

        diffuse = [Math3.dot(normal, light_direction), 0].max
        strength = light[:brightness] / 100.0 * 20.0 / [light_distance**2, 1.0].max
        half = Math3.sub(light_direction, direction)
        highlight = if Math3.dot(half, half) > EPSILON
                      exponent = 2 + (254 * ((1 - (entity[:roughness] / 100.0))**4))
                      ([Math3.dot(normal, Math3.normalize(half)), 0].max**exponent) * entity[:specular] / 100.0
                    else
                      0.0
                    end
        3.times do |channel|
          shaded[channel] += ((base[channel] * diffuse) + highlight) * strength * ((light[:color][channel] / 255.0)**2.2)
        end
      end
      amount = entity[:reflection] / 100.0
      return shaded if amount.zero? || depth >= 2

      reflected = Math3.sub(direction, Math3.mul(normal, 2 * Math3.dot(direction, normal)))
      roughness = entity[:roughness] / 100.0
      directions = [reflected]
      if roughness.positive?
        helper = reflected[2].abs < 0.9 ? [0.0, 0.0, 1.0] : [0.0, 1.0, 0.0]
        tangent = Math3.normalize(Math3.cross(reflected, helper))
        bitangent = Math3.cross(reflected, tangent)
        directions = [[-1, -1], [-1, 1], [1, -1], [1, 1]].map do |x, y|
          ray = Math3.normalize(Math3.add(reflected,
                                          Math3.mul(Math3.add(Math3.mul(tangent, x), Math3.mul(bitangent, y)),
                                                    roughness * 0.65)))
          Math3.dot(ray, normal).positive? ? ray : reflected
        end
      end
      colors = directions.map { |ray| sample(Math3.add(point, Math3.mul(normal, EPSILON)), ray, depth + 1) }
      bounced = (0..2).map { |channel| colors.sum { |color| color[channel] } / colors.length }
      shaded.zip(bounced).map { |direct, mirror| (direct * (1 - amount)) + (mirror * amount) }
    end

    def self.check_dimensions(width, height)
      unless [width, height].all? { |value| value.is_a?(Integer) && value.positive? && value < 2**31 }
        raise ArgumentError, 'Resolution needs positive integer width and height'
      end

      budget = java.lang.Runtime.runtime.max_memory / 4
      return unless width * height > (2**31) - 1 || width * height * 4 > budget

      raise ArgumentError,
            'Resolution exceeds safe image memory budget'
    end

    def render(width, height, progress: nil, cancelled: nil)
      self.class.check_dimensions(width, height)
      return nil if cancelled&.call

      image = java.awt.image.BufferedImage.new(width, height, java.awt.image.BufferedImage::TYPE_INT_RGB)
      projection = Projection.new(@scene.camera, width, height)
      height.times do |y|
        return nil if cancelled&.call

        pixels = width.times.map do |x|
          color = sample(*projection.ray(x + 0.5, y + 0.5)).map do |value|
            (([[value, 0].max, 1].min**(1.0 / 2.2)) * 255).round
          end
          (color[0] << 16) | (color[1] << 8) | color[2]
        end
        image.set_rgb(0, y, width, 1, pixels.to_java(:int), 0, width)
        progress&.call(y + 1, height)
      end
      image
    end
  end
end
