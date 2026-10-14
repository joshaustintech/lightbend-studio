module Lightbend
  module ImageFile
    module_function

    def save(image, path, format = 'png')
      raise ArgumentError, 'Choose PNG, BMP, or JPG' unless %w[png bmp jpg].include?(format)

      Tempfile.create(['still', ".#{format}"], File.dirname(File.expand_path(path))) do |file|
        if format == 'jpg'
          writer = javax.imageio.ImageIO.get_image_writers_by_format_name('jpeg').next
          output = javax.imageio.ImageIO.create_image_output_stream(java.io.File.new(file.path))
          begin
            writer.output = output
            settings = writer.default_write_param
            settings.compression_mode = javax.imageio.ImageWriteParam::MODE_EXPLICIT
            settings.compression_quality = 0.9
            writer.write(nil, javax.imageio.IIOImage.new(image, nil, nil), settings)
          ensure
            output.close
            writer.dispose
          end
        else
          success = javax.imageio.ImageIO.write(image, format, java.io.File.new(file.path))
          raise IOError, 'No image writer is available' unless success
        end
        file.fsync
        File.rename(file.path, path)
      end
      path
    end
  end
end
