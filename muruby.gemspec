require 'rake'
Gem::Specification.new do |s|
  s.name = 'muruby'
  s.version = '0.0.0'
  s.date = '2013-12-18'
  s.summary = 'Game Engine (PichurriaJuegos)'
  s.description = 'Game Engine for Android and GNU/Linux using mruby'
  s.authors = ['Jovany Leandro G.C']
  s.email = ['pichurriajuegos@gmail.com']
  s.files = ['bin/muruby']
  s.files += Dir['skel/doc/*', 'skel/*']
  #@todo recursive?
  s.files += FileList['skel/android-project/**/**/**/**/*']
  s.homepage = ''
  s.license = 'MIT'
  s.add_development_dependency "rspec"
  s.executables << "muruby"
end
