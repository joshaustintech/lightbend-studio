require 'open3'
require 'json'
require 'fileutils'

root = File.expand_path('..', __dir__)
Dir.chdir(root)
FileUtils.mkdir_p('tmp/quality')
runner = File.join(root, 'bin/jruby')
flags = ['--ignore-parent-exclusion', '--config', '.rubocop.yml', '--cache', 'false']
commands = {
  'rubocop-lint' => ['rubocop', *flags, '--lint', '--format', 'json', 'lib', 'test', 'bin/quality.rb'],
  'rubocop' => ['rubocop', *flags, '--format', 'json', 'lib', 'test', 'bin/quality.rb'],
  'reek' => ['reek', '--format', 'json', 'lib'],
  'flay' => ['flay', 'lib']
}
failed = false
commands.each do |name, arguments|
  output, errors, result = Open3.capture3(runner, '-S', 'bundle', 'exec', *arguments)
  File.write("tmp/quality/#{name}.txt", output + errors)
  count = case name
          when 'rubocop', 'rubocop-lint' then JSON.parse(output).fetch('summary').fetch('offense_count')
          when 'reek' then JSON.parse(output).length
          when 'flay' then Integer(output[/Total score \(lower is better\) = (\d+)/, 1])
          end
  puts "#{name}: #{count} #{name == 'flay' ? 'duplication score' : 'findings'} (exit #{result.exitstatus}); tmp/quality/#{name}.txt"
  allowed = name == 'reek' ? [0, 2] : (name == 'flay' ? [0] : [0, 1])
  failed ||= !allowed.include?(result.exitstatus) || (name == 'rubocop-lint' && !result.success?)
end
abort 'Quality check failed: fix lint errors or analyzer execution failures.' if failed
puts 'Lint gate passed. Full style, smell and duplication diagnostics are advisory; all findings retained.'
