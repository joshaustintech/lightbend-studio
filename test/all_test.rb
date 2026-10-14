Dir[File.join(__dir__, '*_test.rb')].each do |path|
  require path unless File.basename(path) == 'editor_test.rb'
end
