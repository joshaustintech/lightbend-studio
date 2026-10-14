require 'bigdecimal'
require 'cgi'
require 'tempfile'

module Lightbend
  module SceneFile
    SCHEMA_PATH = File.expand_path('../../schema/scene-v1.xsd', __dir__)

    module_function

    def schema
      factory = javax.xml.validation.SchemaFactory.new_instance('http://www.w3.org/2001/XMLSchema')
      factory.set_property(javax.xml.XMLConstants::ACCESS_EXTERNAL_DTD, '')
      factory.set_property(javax.xml.XMLConstants::ACCESS_EXTERNAL_SCHEMA, '')
      factory.new_schema(java.io.File.new(SCHEMA_PATH))
    end

    def validate(xml)
      raise ArgumentError, 'Scene XML cannot contain a DOCTYPE' if xml.match?(/<!DOCTYPE/i)

      validator = schema.new_validator
      validator.set_property(javax.xml.XMLConstants::ACCESS_EXTERNAL_DTD, '')
      validator.set_property(javax.xml.XMLConstants::ACCESS_EXTERNAL_SCHEMA, '')
      validator.validate(javax.xml.transform.stream.StreamSource.new(java.io.StringReader.new(xml)))
      true
    rescue Java::OrgXmlSax::SAXException => e
      raise ArgumentError, "Invalid scene XML: #{e.message}"
    end

    def attributes(values)
      values.map { |key, value| "#{key}=\"#{CGI.escapeHTML(value.is_a?(Float) ? BigDecimal(value.to_s).to_s('F') : value.to_s)}\"" }.join(' ')
    end

    def entity_xml(entity)
      values = { id: entity[:id], name: entity[:name] }
      values[:group] = entity[:group_id] if entity[:group_id]
      values[:fov] = entity[:fov] if entity[:kind] == 'camera'
      values[:brightness] = entity[:brightness] if entity[:kind] == 'light'
      body = { position: :pos, rotation: :rot, scale: :scale }.map do |tag, field|
        "<#{tag} #{attributes(%i[x y z].zip(entity[field]).to_h)}/>"
      end.join
      if %w[cube sphere plane light].include?(entity[:kind])
        color = %i[r g b].zip(entity[:color]).to_h
        tag = entity[:kind] == 'light' ? 'color' : 'material'
        %i[reflection specular roughness].each { |key| color[key] = entity[key] } if tag == 'material'
        body += "<#{tag} #{attributes(color)}/>"
      end
      "<#{entity[:kind]} #{attributes(values)}>#{body}</#{entity[:kind]}>"
    end

    def dump(scene)
      scene.validate!
      sections = [['groups', ['group']], ['objects', %w[cube sphere plane]], ['lights', ['light']]]
      body = entity_xml(scene.camera)
      sections.each do |tag, kinds|
        body += "<#{tag}>#{scene.entities.select do |e|
          kinds.include?(e[:kind])
        end.map { |e| entity_xml(e) }.join}</#{tag}>"
      end
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><scene schemaVersion=\"1\">#{body}</scene>"
    end

    def save(scene, path)
      xml = dump(scene)
      Tempfile.create(['scene', '.xml'], File.dirname(File.expand_path(path))) do |file|
        file.write(xml)
        file.flush
        file.fsync
        validate(File.read(file.path))
        File.rename(file.path, path)
      end
      path
    end

    def parse(xml)
      validate(xml)
      factory = javax.xml.parsers.DocumentBuilderFactory.new_instance
      factory.set_feature('http://apache.org/xml/features/disallow-doctype-decl', true)
      factory.set_feature('http://xml.org/sax/features/external-general-entities', false)
      factory.set_feature('http://xml.org/sax/features/external-parameter-entities', false)
      factory.set_attribute(javax.xml.XMLConstants::ACCESS_EXTERNAL_DTD, '')
      factory.set_attribute(javax.xml.XMLConstants::ACCESS_EXTERNAL_SCHEMA, '')
      document = factory.new_document_builder.parse(org.xml.sax.InputSource.new(java.io.StringReader.new(xml)))
      elements = document.get_elements_by_tag_name('*')
      entities = []
      elements.length.times do |index|
        node = elements.item(index)
        next unless Scene::KINDS.include?(node.tag_name)

        entity = Scene.new.build(node.tag_name)
        entity[:id] = node.get_attribute('id').to_s
        entity[:name] = node.get_attribute('name').to_s
        entity[:group_id] = node.get_attribute('group').to_s unless node.get_attribute('group').empty?
        { position: :pos, rotation: :rot, scale: :scale }.each do |tag, field|
          vector = node.get_elements_by_tag_name(tag.to_s).item(0)
          entity[field] = %w[x y z].map { |key| vector.get_attribute(key).to_f }
        end
        if %w[cube sphere plane light].include?(entity[:kind])
          color = node.get_elements_by_tag_name(entity[:kind] == 'light' ? 'color' : 'material').item(0)
          entity[:color] = %w[r g b].map { |key| color.get_attribute(key).to_i }
          unless entity[:kind] == 'light'
            %i[reflection specular roughness].each do |key|
              entity[key] = color.get_attribute(key.to_s).to_f
            end
          end
        end
        %i[brightness fov].each do |key|
          entity[key] = node.get_attribute(key.to_s).to_f if node.has_attribute(key.to_s)
        end
        entities << entity
      end
      Scene.new(entities)
    end

    def load(path)
      raise ArgumentError, 'Scene file exceeds 16 MiB' if File.size(path) > 16 * 1024 * 1024

      parse(File.read(path))
    end
  end
end
