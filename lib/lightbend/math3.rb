module Lightbend
  module Math3
    module_function

    def add(a, b) = a.zip(b).map { |x, y| x + y }
    def sub(a, b) = a.zip(b).map { |x, y| x - y }
    def mul(a, amount) = a.map { |x| x * amount }
    def dot(a, b) = a.zip(b).sum { |x, y| x * y }
    def cross(a, b) = [(a[1] * b[2]) - (a[2] * b[1]), (a[2] * b[0]) - (a[0] * b[2]), (a[0] * b[1]) - (a[1] * b[0])]
    def normalize(a) = mul(a, 1.0 / Math.sqrt(dot(a, a)))

    def rotate(v, angles, inverse: false)
      axes = inverse ? [2, 1, 0] : [0, 1, 2]
      axes.reduce(v.dup) do |value, axis|
        angle = angles[axis] * Math::PI / 180.0 * (inverse ? -1 : 1)
        first, second = [[1, 2], [2, 0], [0, 1]][axis]
        result = value.dup
        result[first] = (value[first] * Math.cos(angle)) - (value[second] * Math.sin(angle))
        result[second] = (value[first] * Math.sin(angle)) + (value[second] * Math.cos(angle))
        result
      end
    end

    def transform(v, entity, vector: false, inverse: false)
      if inverse
        point = vector ? v : sub(v, entity[:pos])
        rotate(point, entity[:rot], inverse: true).zip(entity[:scale]).map { |x, scale| x / scale }
      else
        point = rotate(v.zip(entity[:scale]).map { |x, scale| x * scale }, entity[:rot])
        vector ? point : add(point, entity[:pos])
      end
    end
  end
end
