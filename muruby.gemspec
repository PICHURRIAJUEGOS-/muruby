
# LLM-Assisted
Gem::Specification.new do |s|
  s.name = 'muruby'
  s.homepage = 'http://bit4bit.somxslibres.net'
  s.version = '0.0.1'
  s.date = '2013-12-18'
  s.summary = 'Game Engine (PichurriaJuegos)'
  s.description = 'Game Engine for Android and GNU/Linux using mruby'
  s.authors = ['Jovany Leandro G.C']
  s.email = ['pichurriajuegos@gmail.com']
  s.required_ruby_version = '>= 3.0.0'
  s.files += ['bin/muruby']
  s.files += Dir['lib/*', 'skel/doc/*', 'skel/game/*', 'skel/*', 'lib/*', 'lib/muruby/*', 'lib/muruby/tasks/*']
  s.files += Dir['skel/android-project/**/**/**/**/*']
  s.homepage = ''
  s.license = 'MIT'
  s.add_development_dependency "rake", '~> 0'
  s.add_development_dependency "rspec", '~> 0'
  s.add_development_dependency "thor", '~> 0'
  s.add_development_dependency "gettext", '~> 0'
  s.executables << "muruby"
end
