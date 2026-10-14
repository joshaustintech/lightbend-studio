require_relative '../lightbend'
require_relative 'canvas'

module Lightbend
  class Editor
    Entry = Struct.new(:id, :label) do
      def to_s = label
    end

    attr_reader :scene, :frame, :selected_id

    def initialize
      @scene = Scene.new
      @selected_id = 'camera'
      @dirty = false
      @frame = javax.swing.JFrame.new('Lightbend Studio')
      @frame.name = 'studio.window'
      @frame.default_close_operation = javax.swing.JFrame::DO_NOTHING_ON_CLOSE
      @frame.set_size(1280, 800)
      @frame.set_minimum_size(java.awt.Dimension.new(1000, 650))
      @frame.set_location_relative_to(nil)
      @frame.add_window_listener(CloseListener.new(self))
      @frame.jmenu_bar = menu_bar
      @frame.add(toolbar, java.awt.BorderLayout::NORTH)
      @tree = javax.swing.JTree.new
      @tree.name = 'scene.tree'
      @tree.selection_model.selection_mode = javax.swing.tree.TreeSelectionModel::DISCONTIGUOUS_TREE_SELECTION
      @tree.add_tree_selection_listener do |_event|
        entry = @tree.last_selected_path_component&.user_object
        @selected_id = entry.id if entry.respond_to?(:id) && entry.id
        fill_properties
        @canvas.repaint
      end
      @canvas = Canvas.new(self)
      @properties = javax.swing.JPanel.new
      @properties.layout = javax.swing.BoxLayout.new(@properties, javax.swing.BoxLayout::Y_AXIS)
      @properties.border = javax.swing.BorderFactory.create_empty_border(12, 10, 12, 10)
      tree_scroll = javax.swing.JScrollPane.new(@tree)
      tree_scroll.minimum_size = java.awt.Dimension.new(160, 100)
      property_scroll = javax.swing.JScrollPane.new(@properties)
      property_scroll.minimum_size = java.awt.Dimension.new(250, 100)
      center = javax.swing.JSplitPane.new(javax.swing.JSplitPane::HORIZONTAL_SPLIT, tree_scroll, @canvas)
      center.divider_location = 210
      center.resize_weight = 0.0
      workspace = javax.swing.JSplitPane.new(javax.swing.JSplitPane::HORIZONTAL_SPLIT, center, property_scroll)
      workspace.divider_location = 950
      workspace.resize_weight = 1.0
      @frame.add(workspace, java.awt.BorderLayout::CENTER)
      @frame.add(render_panel, java.awt.BorderLayout::SOUTH)
      rebuild_tree
      fill_properties
      @canvas.refresh
    end

    def show
      @frame.visible = true
      @canvas.refresh
    end

    def button(label, name, &)
      component = javax.swing.JButton.new(label)
      component.name = name
      component.add_action_listener { |_event| safely(&) }
      component
    end

    def toolbar
      panel = javax.swing.JPanel.new(java.awt.FlowLayout.new(java.awt.FlowLayout::LEFT))
      %w[cube sphere plane light].each do |kind|
        panel.add(button(kind == 'light' ? 'Point light' : kind.capitalize, "add.#{kind}") do
          entity = @scene.add(kind)
          @selected_id = entity[:id]
          changed
        end)
      end
      panel.add(button('Group selected', 'group.create') do
        entries = (@tree.selection_paths || []).map { |path| path.last_path_component.user_object }
        ids = entries.filter_map { |entry| entry.id if entry.respond_to?(:id) }
        group = @scene.group(ids, "Group #{@scene.entities.count { |e| e[:kind] == 'group' } + 1}")
        @selected_id = group[:id]
        changed
      end)
      panel.add(button('Delete', 'entity.delete') do
        @scene.remove(@selected_id)
        @selected_id = 'camera'
        changed
      end)
      panel.add(button('Reset camera', 'camera.reset') do
        @scene.update(@scene.camera[:id], pos: [6.0, -9.0, 6.0], rot: [60.98, 0.0, 33.69])
        changed(refresh_tree: false)
      end)
      panel
    end

    def menu_bar
      bar = javax.swing.JMenuBar.new
      file_menu = javax.swing.JMenu.new('File')
      { 'New scene' => -> { new_scene }, 'Open scene…' => -> { choose_open },
        'Save scene' => -> { @path ? save_scene(@path) : choose_save }, 'Save scene as…' => lambda {
                                                                          choose_save
                                                                        } }.each do |label, action|
        item = javax.swing.JMenuItem.new(label)
        item.name = { 'New scene' => 'file.new', 'Open scene…' => 'file.open',
                      'Save scene' => 'file.save', 'Save scene as…' => 'file.save_as' }.fetch(label)
        item.add_action_listener { |_event| safely(&action) }
        file_menu.add(item)
      end
      bar.add(file_menu)
      bar
    end

    def new_scene
      return unless discard_changes?

      @scene = Scene.new
      @path = nil
      @dirty = false
      @selected_id = 'camera'
      rebuild_tree
      fill_properties
      @canvas.refresh
      @status.text = 'New scene'
      update_title
    end

    def chooser(extension, description)
      dialog = javax.swing.JFileChooser.new
      dialog.file_filter = javax.swing.filechooser.FileNameExtensionFilter.new(description,
                                                                               [extension].to_java(:string))
      dialog
    end

    def choose_open
      return unless discard_changes?

      dialog = chooser('lbscene', 'Lightbend scene (*.lbscene)')
      return unless dialog.show_open_dialog(@frame) == javax.swing.JFileChooser::APPROVE_OPTION

      open_scene(dialog.selected_file.absolute_path)
    end

    def choose_save
      dialog = chooser('lbscene', 'Lightbend scene (*.lbscene)')
      return unless dialog.show_save_dialog(@frame) == javax.swing.JFileChooser::APPROVE_OPTION

      path = dialog.selected_file.absolute_path.to_s
      path += '.lbscene' unless path.downcase.end_with?('.lbscene')
      save_scene(path) if overwrite?(path)
    end

    def save_scene(path)
      SceneFile.save(@scene, path)
      @path = path
      @dirty = false
      @status.text = "Saved #{File.basename(path)} — XSD validated"
      update_title
    end

    def open_scene(path)
      loaded = SceneFile.load(path)
      @scene = loaded
      @path = path
      @dirty = false
      @selected_id = loaded.camera[:id]
      rebuild_tree
      fill_properties
      @canvas.refresh
      @status.text = "Opened #{File.basename(path)} — XSD validated"
      update_title
    end

    def rebuild_tree
      root = javax.swing.tree.DefaultMutableTreeNode.new(Entry.new(nil, 'Scene'))
      nodes = {}
      @scene.entities.select { |e| e[:group_id].nil? }.each do |entity|
        node = javax.swing.tree.DefaultMutableTreeNode.new(Entry.new(entity[:id],
                                                                     "#{entity[:name]} (#{entity[:kind]})"))
        root.add(node)
        nodes[entity[:id]] = node
      end
      @scene.objects.select { |e| e[:group_id] }.each do |entity|
        node = javax.swing.tree.DefaultMutableTreeNode.new(Entry.new(entity[:id], entity[:name]))
        nodes[entity[:group_id]].add(node)
        nodes[entity[:id]] = node
      end
      @tree.model = javax.swing.tree.DefaultTreeModel.new(root)
      row = 0
      while row < @tree.row_count
        @tree.expand_row(row)
        row += 1
      end
      node = nodes[@selected_id]
      @tree.selection_path = javax.swing.tree.TreePath.new(node.path) if node
    end

    def select(id)
      @selected_id = id
      rebuild_tree
      fill_properties
      @canvas.repaint
    end

    def field_row(label, names, values)
      row = javax.swing.JPanel.new(java.awt.GridLayout.new(1, names.length + 1, 4, 0))
      row.maximum_size = java.awt.Dimension.new(1000, 32)
      row.add(javax.swing.JLabel.new(label))
      names.zip(values).each do |name, value|
        field = javax.swing.JTextField.new(value.to_s)
        field.name = name
        @fields[name] = field
        field.add_action_listener { |_event| safely { apply_properties } }
        row.add(field)
      end
      @properties.add(row)
      @properties.add(javax.swing.Box.create_vertical_strut(5))
    end

    def fill_properties
      return unless @properties

      @properties.remove_all
      @fields = {}
      entity = @scene.find(@selected_id)
      return unless entity

      @properties.add(javax.swing.JLabel.new("#{entity[:kind].capitalize} properties"))
      @properties.add(javax.swing.Box.create_vertical_strut(12))
      field_row('Name', ['entity.name'], [entity[:name]])
      { position: :pos, rotation: :rot, scale: :scale }.each do |label, key|
        next if label == :scale && %w[camera light].include?(entity[:kind])
        next if label == :rotation && entity[:kind] == 'light'

        field_row(label.capitalize, %w[x y z].map { |axis| "#{label}.#{axis}" }, entity[key].map do |value|
          format('%.3f', value)
        end)
      end
      if %w[cube sphere plane light].include?(entity[:kind])
        field_row('RGB', %w[r g b].map { |channel| "color.#{channel}" }, entity[:color])
        if entity[:kind] == 'light'
          field_row('Brightness %', ['light.brightness'], [entity[:brightness]])
        else
          %i[reflection specular roughness].each do |key|
            field_row("#{key.capitalize} %", ["material.#{key}"], [entity[key]])
          end
        end
      end
      field_row('Field of view', ['camera.fov'], [entity[:fov]]) if entity[:kind] == 'camera'
      @properties.add(javax.swing.Box.create_vertical_strut(8))
      @properties.add(button('Apply properties', 'properties.apply') { apply_properties })
      @properties.add(javax.swing.Box.create_vertical_strut(10))
      @properties.add(javax.swing.JLabel.new('<html>World-axis arrows: move<br>Rotation: degrees<br>Scale: positive multipliers</html>'))
      @properties.revalidate
      @properties.repaint
    end

    def apply_properties
      attributes = { name: @fields.fetch('entity.name').text.to_s }
      { position: :pos, rotation: :rot, scale: :scale }.each do |prefix, key|
        next unless @fields.key?("#{prefix}.x")

        attributes[key] = %w[x y z].map { |axis| Float(@fields.fetch("#{prefix}.#{axis}").text.to_s) }
      end
      if @fields.key?('color.r')
        attributes[:color] = %w[r g b].map do |channel|
          Integer(@fields.fetch("color.#{channel}").text.to_s, 10)
        end
      end
      %i[reflection specular roughness].each do |key|
        attributes[key] = Float(@fields.fetch("material.#{key}").text.to_s) if @fields.key?("material.#{key}")
      end
      attributes[:brightness] = Float(@fields.fetch('light.brightness').text.to_s) if @fields.key?('light.brightness')
      attributes[:fov] = Float(@fields.fetch('camera.fov').text.to_s) if @fields.key?('camera.fov')
      @scene.update(@selected_id, attributes)
      changed
    end

    def changed(refresh_tree: true)
      @dirty = true
      rebuild_tree if refresh_tree
      fill_properties
      @canvas.refresh
      @status.text = 'Scene changed'
      update_title
    end

    def update_title
      @frame.title = "Lightbend Studio#{' *' if @dirty}#{" — #{File.basename(@path)}" if @path}"
    end

    def render_panel
      panel = javax.swing.JPanel.new(java.awt.BorderLayout.new)
      controls = javax.swing.JPanel.new(java.awt.FlowLayout.new(java.awt.FlowLayout::LEFT))
      controls.add(javax.swing.JLabel.new('Still resolution'))
      @render_width = javax.swing.JTextField.new('1920', 6)
      @render_height = javax.swing.JTextField.new('1080', 6)
      @render_width.name = 'render.width'
      @render_height.name = 'render.height'
      [@render_width, @render_height].each { |field| field.add_action_listener { |_event| safely { @canvas.refresh } } }
      controls.add(@render_width)
      controls.add(javax.swing.JLabel.new('×'))
      controls.add(@render_height)
      @format = javax.swing.JComboBox.new(%w[PNG BMP JPG].to_java(:string))
      @format.name = 'render.format'
      controls.add(@format)
      @render_button = button('Render still…', 'render.start') { choose_render }
      @cancel_button = button('Cancel render', 'render.cancel') { @cancel_requested.set(true) if @cancel_requested }
      @cancel_button.enabled = false
      controls.add(@render_button)
      controls.add(@cancel_button)
      @progress = javax.swing.JProgressBar.new(0, 100)
      @progress.string_painted = true
      controls.add(@progress)
      @status = javax.swing.JLabel.new('Create objects, arrange a scene, save, and render a still.')
      @status.name = 'status'
      @status.border = javax.swing.BorderFactory.create_empty_border(3, 10, 8, 10)
      panel.add(controls, java.awt.BorderLayout::CENTER)
      panel.add(@status, java.awt.BorderLayout::SOUTH)
      panel
    end

    def preview_resolution
      @last_preview_resolution = resolution
    rescue ArgumentError
      @last_preview_resolution || [1920, 1080]
    end

    def resolution
      width = Integer(@render_width.text.to_s, 10)
      height = Integer(@render_height.text.to_s, 10)
      Renderer.check_dimensions(width, height)
      [width, height]
    end

    def choose_render
      resolution
      @canvas.refresh
      format = @format.selected_item.to_s.downcase
      dialog = chooser(format, "#{format.upcase} image")
      return unless dialog.show_save_dialog(@frame) == javax.swing.JFileChooser::APPROVE_OPTION

      path = dialog.selected_file.absolute_path.to_s
      path += ".#{format}" unless path.downcase.end_with?(".#{format}")
      render_to(path) if overwrite?(path)
    end

    def render_to(path)
      raise ArgumentError, 'A render is already running' if @rendering

      width, height = resolution
      snapshot = Scene.new(Marshal.load(Marshal.dump(@scene.entities)))
      format = @format.selected_item.to_s.downcase
      @cancel_requested = java.util.concurrent.atomic.AtomicBoolean.new(false)
      @rendering = true
      @render_button.enabled = false
      @cancel_button.enabled = true
      @progress.value = 0
      @status.text = "Rendering #{width}×#{height} on CPU…"
      Thread.new do
        progress = lambda do |row, total|
          if row % [total / 100, 1].max == 0
            javax.swing.SwingUtilities.invoke_later { @progress.value = row * 100 / total }
          end
        end
        image = Renderer.new(snapshot).render(width, height, progress: progress, cancelled: lambda {
          @cancel_requested.get
        })
        if image && !@cancel_requested.get
          ImageFile.save(image, path, format)
          message = "Rendered #{File.basename(path)} — #{width}×#{height}"
        else
          message = 'Render cancelled; no image saved'
        end
      rescue StandardError => e
        message = "Render failed: #{e.message}"
      ensure
        javax.swing.SwingUtilities.invoke_later do
          @rendering = false
          @render_button.enabled = true
          @cancel_button.enabled = false
          @status.text = message
        end
      end
    end

    def safely
      yield
    rescue StandardError => e
      @status.text = e.message if @status
      javax.swing.JOptionPane.show_message_dialog(@frame, e.message, 'Cannot complete action', javax.swing.JOptionPane::ERROR_MESSAGE)
    end

    def overwrite?(path)
      !File.exist?(path) || javax.swing.JOptionPane.show_confirm_dialog(@frame, "Replace #{File.basename(path)}?",
                                                                        'Replace file', javax.swing.JOptionPane::YES_NO_OPTION) == javax.swing.JOptionPane::YES_OPTION
    end

    def discard_changes?
      !@dirty || javax.swing.JOptionPane.show_confirm_dialog(@frame, 'Discard unsaved scene changes?', 'Unsaved scene',
                                                             javax.swing.JOptionPane::YES_NO_OPTION) == javax.swing.JOptionPane::YES_OPTION
    end

    def close
      return unless discard_changes?

      @cancel_requested.set(true) if @cancel_requested
      @frame.dispose
    end

    class CloseListener < java.awt.event.WindowAdapter
      def initialize(editor)
        super()
        @editor = editor
      end

      def windowClosing(_event) = @editor.close
    end
  end
end
