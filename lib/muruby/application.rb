# LLM-Assisted
module Muruby
  class Application
    def self.load_tasks
      require 'rake'
      %w(
core
host
android
).each do |task|
        load File.join(Muruby.root, "muruby/tasks/#{task}.rake")
      end
      nil
    end
  end

  def self.app
    Dir.pwd
  end

  def self.root
    File.expand_path('../../', __FILE__)
  end

  def self.paths
    core_path = File.absolute_path(File.expand_path(File.join(Muruby.app, '../', 'core')))
    game_root ||= ENV['GAME_DIR']
    game_root ||= File.absolute_path(File.join(Muruby.app, 'game'))

    resource_root ||= ENV['RESOURCE_DIR']
    resource_root ||= File.absolute_path(File.join(Muruby.app, 'resources'))
    mruby_path = File.absolute_path(File.join(core_path, 'mruby'))

    {
      :game_root => game_root,
      :resource_root => resource_root,
      :core_path => core_path,
      :mruby_path => File.absolute_path(File.join(core_path, 'mruby')),
      :mruby_android_path => File.absolute_path(File.join(mruby_path, 'build', 'androideabi')),
      :mruby_mrbc => File.absolute_path(File.join(core_path, 'mruby', 'build', 'host', 'bin', 'mrbc')),
      :mruby_mirb => File.absolute_path(File.join(core_path, 'mruby', 'build', 'host', 'bin', 'mirb')),
      :mruby_mrdb => File.absolute_path(File.join(core_path, 'mruby', 'build', 'host-debug', 'bin', 'mrdb')),
      :mruby_mruby => File.join(core_path, 'mruby', 'build', 'host', 'bin', 'mruby'),
      :sdl_path => File.join(core_path, 'SDL2'),
      :sdl_root => File.join(core_path, 'core', 'SDL2'),
      :sdl_so => File.join(core_path, 'build_host', 'lib', 'libSDL2.so'),
      :android_build_path => File.absolute_path(File.join(core_path, 'build_android')),
    }
  end

end
