CLEAN.include [
  'pkg', 'tmp',
  'ext/redcloth_scan/**/*.{bundle,so,obj,pdb,lib,def,exp,c,o,xml,class,jar,java}',
  'ext/redcloth_scan/**/redcloth_*.rb', 
  'ext/redcloth_scan/Makefile',
  'lib/*.{bundle,so,o,obj,pdb,lib,def,exp,jar}', 
  'lib/redcloth_scan.rb', 
]

desc "Compile the Java extensions"
task :jar => 'lib/redcloth_scan.jar'

ext = "ext/redcloth_scan"
file 'lib/redcloth_scan.jar' => FileList["#{ext}/RedclothScanService.java", "#{ext}/RedclothInline.java", "#{ext}/RedclothAttributes.java"] do
  sources = FileList["#{ext}/**/*.java"].join(' ')
  sh "javac -target 1.5 -source 1.5 -d #{ext} #{java_classpath_arg} #{sources}"
  sh "jar cf lib/redcloth_scan.jar -C #{ext} ."
end

begin
if !defined?(JRUBY_VERSION)
  require 'rake/extensiontask'
  require File.dirname(__FILE__) + '/ragel_extension_task'
  
  # c = RagelTask.new('c')

  extconf = "ext/redcloth_scan/extconf.rb"
  file extconf do
    FileUtils.mkdir(File.dirname(extconf)) unless File.directory?(File.dirname(extconf))
    File.open(extconf, "w") do |io|
      io.write(<<-EOF)
require 'mkmf'
CONFIG['warnflags'].gsub!(/-Wshorten-64-to-32/, '') if CONFIG['warnflags']
$CFLAGS << ' -O0 -Wall -Werror' if CONFIG['CC'] =~ /gcc/
dir_config("redcloth_scan")
have_library("c", "main")
create_makefile("redcloth_scan")
EOF
    end
  end

  Rake::RagelExtensionTask.new("redcloth_scan") do |ext|
    ext.source_files = ["#{ext.ext_dir}/redcloth_scan.c", "#{ext.ext_dir}/redcloth_inline.c", "#{ext.ext_dir}/redcloth_attributes.c"]
    
    if ENV['RUBY_CC_VERSION']
      ext.cross_compile = true
      ext.cross_platform = 'i386-mingw32'
    end
    
    puts "*" * 100
    puts ext.send(:source_files)
    puts "+" * 100
    
  end
  
  # # The way tasks are defined with compile:xxx (but without namespace) in rake-compiler forces us
  # # to use these hacks for setting up dependencies. Ugly!
  # Rake::Task["compile:redcloth_scan"].prerequisites.unshift(extconf)
  # Rake::Task["compile:redcloth_scan"].prerequisites.unshift(c.target('scan'))
  # Rake::Task["compile:redcloth_scan"].prerequisites.unshift(rb.target('scan'))
  # 
  # Rake::Task["compile"].prerequisites.unshift(extconf)
  # Rake::Task["compile"].prerequisites.unshift(c.target('scan'))
  # Rake::Task["compile"].prerequisites.unshift(rb.target('scan'))
  
end
rescue LoadError
  unless defined?($c_warned)
    warn "WARNING: Rake::ExtensionTask not installed. Skipping C compilation." 
    $c_warned = true
    task :compile # no-op
  end
end

rule( /\.c$/ => [
proc {|task_name| task_name.sub(/redcloth_([^.]+)\.(.+)$/, "redcloth_#{$1}.#{$2}.rl") }
]) do |t|
  sh "cc #{t.source} -c -o #{t.name}"
end