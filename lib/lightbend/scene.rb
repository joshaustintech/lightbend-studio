module Lightbend
  class Scene
    KINDS = %w[cube sphere plane light group camera].freeze
    attr_reader :entities

    def initialize(entities = nil)
      @entities = entities || []
      if entities
        validate!
        return
      end

      @entities << build('camera').merge(id: 'camera', pos: [6.0, -9.0, 6.0], rot: [60.98, 0.0, 33.69])
      @entities << build('light').merge(id: 'light-1', pos: [-4.0, -4.0, 8.0])
    end

    def build(kind)
      { id: '', kind: kind, name: kind.capitalize, group_id: nil,
        pos: [0.0, 0.0, 0.0], rot: [0.0, 0.0, 0.0], scale: [1.0, 1.0, 1.0],
        color: [192, 192, 192], reflection: 0.0, specular: 0.0, roughness: 0.0,
        brightness: 100.0, fov: 45.0 }.tap { |e| e[:color] = [255, 255, 255] if kind == 'light' }
    end

    def add(kind)
      raise ArgumentError, 'Unknown object type' unless (KINDS - ['camera']).include?(kind)

      entity = build(kind)
      number = 1
      number += 1 while @entities.any? { |e| e[:id] == "#{kind}-#{number}" }
      entity[:id] = "#{kind}-#{number}"
      entity[:name] = "#{kind.capitalize} #{number}"
      @entities << entity
      entity
    end

    def find(id) = @entities.find { |entity| entity[:id] == id }
    def camera = @entities.find { |entity| entity[:kind] == 'camera' }
    def objects = @entities.select { |entity| %w[cube sphere plane].include?(entity[:kind]) }
    def lights = @entities.select { |entity| entity[:kind] == 'light' }

    def update(id, attributes)
      entity = find(id) || raise(ArgumentError, 'Object no longer exists')
      candidate = entity.merge(attributes)
      validate_entity!(candidate)
      entity.replace(candidate)
      entity
    end

    def validate_entity!(entity)
      raise ArgumentError, 'Unknown object type' unless KINDS.include?(entity[:kind])
      unless entity[:name].is_a?(String) && (1..120).cover?(entity[:name].strip.length)
        raise ArgumentError,
              'Name must contain 1–120 characters'
      end

      %i[pos rot scale].each do |key|
        value = entity[key]
        next if value.is_a?(Array) && value.length == 3 && value.all? do |n|
          n.is_a?(Numeric) && n.finite?
        end

        raise ArgumentError,
              "#{key} needs three finite numbers"
      end
      raise ArgumentError, 'Scale must be positive' unless entity[:scale].all?(&:positive?)
      unless entity[:color].length == 3 && entity[:color].all? do |n|
        n.is_a?(Integer) && (0..255).cover?(n)
      end
        raise ArgumentError,
              'RGB values must be integers from 0–255'
      end

      %i[reflection specular roughness].each do |key|
        raise ArgumentError, "#{key} must be 0–100" unless (0..100).cover?(entity[key])
      end
      raise ArgumentError, 'Brightness must be 0–10000' unless (0..10_000).cover?(entity[:brightness])
      unless entity[:fov] > 0 && entity[:fov] < 179
        raise ArgumentError,
              'Camera field of view must be between 0 and 179'
      end
      return unless entity[:group_id]

      parent = find(entity[:group_id])
      raise ArgumentError, 'Only primitives may belong to a group' unless %w[cube sphere
                                                                             plane].include?(entity[:kind]) && parent && parent[:kind] == 'group'
    end

    def validate!
      raise ArgumentError, 'Scene must contain exactly one camera' unless @entities.count do |e|
        e[:kind] == 'camera'
      end == 1

      ids = @entities.map { |e| e[:id] }
      raise ArgumentError, 'Duplicate object IDs' unless ids.uniq.length == ids.length

      @entities.each { |entity| validate_entity!(entity) }
      self
    end

    def group(ids, name)
      members = ids.map { |id| find(id) }
      raise ArgumentError, 'Select primitives to group' unless !members.empty? && members.all? do |e|
        e && %w[cube sphere plane].include?(e[:kind]) && e[:group_id].nil?
      end

      group = add('group')
      group[:name] = name
      members.each { |e| e[:group_id] = group[:id] }
      group
    end

    def remove(id)
      entity = find(id) || raise(ArgumentError, 'Object no longer exists')
      raise ArgumentError, 'The scene camera cannot be deleted' if entity[:kind] == 'camera'

      @entities.reject! { |e| e[:id] == id || e[:group_id] == id }
    end

    def chain(entity)
      parent = find(entity[:group_id])
      parent ? [entity, parent] : [entity]
    end

    def world_point(entity, point, vector: false)
      chain(entity).reduce(point) { |v, e| Math3.transform(v, e, vector: vector) }
    end

    def local_point(entity, point, vector: false)
      chain(entity).reverse.reduce(point) { |v, e| Math3.transform(v, e, vector: vector, inverse: true) }
    end

    def world_normal(entity, normal)
      transformed = chain(entity).reduce(normal) do |value, e|
        Math3.rotate(value.zip(e[:scale]).map { |x, scale| x / scale }, e[:rot])
      end
      Math3.normalize(transformed)
    end

    def translate_world(id, delta)
      entity = find(id)
      parent = find(entity[:group_id])
      local = parent ? Math3.transform(delta, parent, vector: true, inverse: true) : delta
      update(id, pos: Math3.add(entity[:pos], local))
    end
  end
end
