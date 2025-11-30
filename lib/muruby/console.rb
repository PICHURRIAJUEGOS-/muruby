# LLM-Assisted
require 'rubygems'
require 'thor'
require 'gettext'
require 'rbconfig'
require 'fileutils'
require 'delegate'

$GIT_REPO_MRUBY="git://github.com/mruby/mruby.git"
$HG_REPO_SDL2= {
#  'SDL' => "http://hg.libsdl.org/SDL",
  'SDL' => 'https://codeload.github.com/SDL-mirror/SDL/zip/release-2.0.5',
#  'SDL_image' => "http://hg.libsdl.org/SDL_image/",
  'SDL_image' => 'http://www.libsdl.org/projects/SDL_image/release/SDL2_image-2.0.0.tar.gz',
#  'SDL_mixer' => "http://hg.libsdl.org/SDL_mixer/",
  'SDL_mixer' => 'http://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.0.tar.gz',
#  'SDL_ttf' => "http://hg.libsdl.org/SDL_ttf/"
  'SDL_ttf' => 'http://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.12.tar.gz'
}

module CacheDir

  def cache_directory(basename)
    local_file = File.absolute_path File.join(cache_path, basename)
    Dir.mkdir(cache_path) unless Dir.exist?(cache_path)
    yield(local_file)
  end

end

class DownloadError < StandardError
end

class Download < SimpleDelegator
  include CacheDir
end

class Curl < Download

  def clone(dir, url, file_from: nil, file_to: nil)
    file_to = File.basename(url) if file_to.nil?

    cache_directory(file_to) { |local_file|
      run("curl -C - %s -o %s" % [url, local_file])

      case
      when local_file.end_with?("zip")
        cmd_extractor = "unzip -u %s -d %s"
      when local_file.end_with?("tar.gz")
        cmd_extractor = "tar -xzf %s -C %s"
      when local_file.end_with?("tar.bz2")
        cmd_extractor = "tar -xjf %s -C %s"
      else
        raise "Can't unpack file #{local_file}"
      end

      dir_extraction = File.join(dir, '.extraction')
      FileUtils.mkdir_p dir_extraction
      run(cmd_extractor % [local_file, dir_extraction])
      if !file_from.nil?
        run("cp -ur %s/* %s" % [File.join(dir_extraction, file_from),  dir])
      else
        run("cp -ur %s/* %s" % [dir_extraction, dir])
      end
    }
  rescue => e
    raise DownloadError.new(e.message)
  end

  def pull(dir)
  end

end

class Git < SimpleDelegator
  include CacheDir

  def clone(dir, url, options = "")
    cache_directory(File.basename(dir)) {|local_path|
      if Dir.exist?(local_path)
        pull(dir)
      else
        out = run("git clone -q %s %s %s" % [url, options, local_path], :capture => true)
        raise out if out.include?("fatal")
        FileUtils.copy_entry(local_path, dir)
      end
    }
  rescue => e
    raise DownloadError.new(e.message)
  end

  def pull(dir)
    inside(dir) do
      out = run("git pull -q", :capture => true)
      raise out if out.include?("fatal")
    end
  rescue => e
    raise DownloadError.new(e.message)
  end
end

class Hg < SimpleDelegator
  include CacheDir

  def clone(dir, url, options = "")
    cache_directory(File.basename(dir)) {|local_path|
      if Dir.exist?(local_path)
        pull(dir)
      else
        out = run("hg clone -q %s %s %s" % [url, options, local_path], :capture => true)
        raise out if out.include?("abort")
        FileUtils.copy_entry(local_path, dir)
      end
    }
  rescue => e
    raise DownloadError.new(e.message)
  end

  def pull(dir)
    inside(dir) do
        out = run("hg pull -q", :capture => true)
        raise out if out.include?("abort")
    end
  rescue => e
    raise DownloadError.new(e.message)
  end
end

class ShellError < StandardError
end

class Shell < Thor
  include Thor::Actions

  attr_accessor :env
  attr_accessor :raise_on_run_fail

  def initialize(app)
    @app = app
    @env = {}
    @raise_on_run_fail = true
  end

  def run(cmd, options = {})
    options[:env] = @env

    ret = @app.run(cmd, options)
    if options.fetch(:capture, false) && !ret
      raise ShellError.new(ret)
    end
    ret
  end
end

class AndroidEnvironment < SimpleDelegator
  include Thor::Actions

  DEFAULT_SDK_TAG = '4333796'
  DEFAULT_NDK_VERSION = '19b'
  DEFAULT_ANDROID_API = 24

  attr_reader :android_sdk_dir
  attr_reader :android_ndk_dir
  attr_reader :android_ndk_version

  def initialize(app, android_sdk_dir, android_ndk_dir)
    self.__setobj__(app)

    @app = app
    @env = {}
    @shell = Shell.new(app)
    @android_sdk_dir = android_sdk_dir
    @android_ndk_dir = android_ndk_dir
    @android_ndk_version = DEFAULT_NDK_VERSION
    @android_ndk_toolchain_dir = File.join(android_ndk_dir, "muruby-toolchain-#{@android_ndk_version}")
    @android_api = DEFAULT_ANDROID_API
    @curl = Curl.new(@app)
  end

  def locale_java_home
    '/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64'
  end

  def environment
    return unless block_given?

    current_shell_env = @shell.env.clone
    @shell.env = @env
    begin
        yield @shell
    ensure
      @shell.env = current_shell_env
    end
  end

  def download_sdk
    Dir.mkdir(@android_sdk_dir) unless Dir.exist?(@android_sdk_dir)

    url = 'http://dl.google.com/android/repository/sdk-tools-linux-%s.zip'  % [DEFAULT_SDK_TAG]
    @curl.clone(@android_sdk_dir, url)
  end

  def current_build_tools_version_sdk
    build_tools_path = File.join(@android_sdk_dir, 'build-tools')
    return [] unless Dir.exist?(build_tools_path)
    Dir.entries(build_tools_path).delete_if { |dir| ['..', '.'].include?(dir) }.sort
  end

  def available_build_tools_version_sdk
    sdk_manager('--list', :capture => true).lines
      .map(&:chomp)
      .map(&:strip)
      .select { |line| line.start_with?('build-tools;') }
      .map { |line| line.split('|').first.strip.split(';').last }
  end

  def configure_sdk
    sdk_manager('tools platform-tools')
    sdk_manager('--update')

    if current_build_tools_version_sdk.empty?
      last_build_tools_version = available_build_tools_version_sdk.last
      sdk_manager("'build-tools;#{last_build_tools_version}'")
    end

    platform_android_api_path = File.join(@android_sdk_dir, 'platforms', "android-#{@android_api}")
    unless Dir.exist?(platform_android_api_path)
      sdk_manager("'platforms;android-#{@android_api}'")
    end
  end

  def sdk_manager(*args, **options)
    environment do |shell|
      sdkmanager_bin = File.join(@android_sdk_dir, 'tools', 'bin', 'sdkmanager')
      shell.run("#{sdkmanager_bin} #{args.join(' ')}", options)
    end
  end

  def configure_ndk
    download_ndk

    sysroot_include_path = File.join(@android_ndk_dir, 'sysroot', 'usr', 'include')
    sysroot_android_path = File.join(@android_ndk_dir, 'platforms', "android-#{@android_api}", 'arch-arm', 'usr')
    run("cp -ur #{sysroot_include_path} #{sysroot_android_path}")

    @env['NDK_HOME'] = @android_ndk_dir
  end

  def download_ndk
    Dir.mkdir(@android_ndk_dir) unless Dir.exist?(@android_ndk_dir)

    ndk_name = 'android-ndk-r%s' % [@android_ndk_version]
    arch = 'x86_64'
    url = 'https://dl.google.com/android/repository/%s-linux-%s.zip' % [ndk_name,
                                                                        arch]
    @curl.clone(@android_ndk_dir, url, file_from: ndk_name)
  end
end

module Build
  #directory for build code for the host
  def build_host_path
    File.join(app_path(), 'core', 'build_host')
  end

  def build_android_path
    File.join(app_path(), 'core', 'build_android')
  end

  def core_path
    File.join(app_path(), 'core')
  end


  def _configure_mruby(app, mruby_path, options = {})
    options[:dev_github_mruby_sdl2] ||= 'mruby-sdl2/mruby-sdl2'

    gems_common = [
                   'mrbgems/mruby-math',
                   'mrbgems/mruby-enum-ext',
                   'mrbgems/mruby-random',
                   'mrbgems/mruby-proc-ext',
                   'mrbgems/mruby-exit',
                   'mrbgems/mruby-fiber',
                   'mrbgems/mruby-struct',
                   'mrbgems/mruby-sprintf',
                   'mrbgems/mruby-string-ext',
                   'mrbgems/mruby-object-ext',
                   'mrbgems/mruby-array-ext',
                   'mrbgems/mruby-hash-ext',
                   'mrbgems/mruby-symbol-ext',
                   'mrbgems/mruby-eval'
                  ]
    gems_base = [
                 {
                   :github => options[:dev_github_mruby_sdl2],
                   :branch => 'master',
                   :cc => {
                     'cc.include_paths' => [File.join(build_host_path, 'include'),
                                            File.join(build_host_path, 'include', 'SDL2')],
                     'linker.libraries' => ['SDL2'],
                     'linker.library_paths' => [File.join(build_host_path, 'lib')]
                   }
                 },
                 'mrbgems/mruby-print',
                 'mrbgems/mruby-bin-mirb',
                 'mrbgems/mruby-bin-mruby'
    ] | gems_common | [
      { :github => 'iij/mruby-dir', :branch => 'master' },
      { :github => 'iij/mruby-io', :branch => 'master' },
      { :github => 'iij/mruby-tempfile', :branch => 'master' },
      { :github => 'iij/mruby-require', :branch => 'master' }
    ]


    gems_android = [
                    {
                      :github => options[:dev_github_mruby_sdl2],
                      :branch => 'master',
                      :cc => {
                        'cc.include_paths' => [File.join(build_host_path, 'include'),
                                               File.join(build_host_path, 'include', 'SDL2'),
                                               File.join(ENV['ANDROID_NDK_HOME'], 'sources/android/support/include/'),
                                              ],
                        #'linker.libraries' => [%w(SDL2)],
                        #'linker.library_paths' => [File.join(build_android_path, 'libs', 'armeabi')]
                      },

                    },
                    #{
                    #  :github => 'pichurriaj/mruby-print-android',
                    #  :branch => 'master'
                    #}
                ] | gems_common

    _configure_mruby_host(mruby_path, gems_base)
    _configure_mruby_android(mruby_path, gems_android) if options[:build_android]

    inside(mruby_path) do
      run("rake clean && rake")
    end
  end

  #changes name logo and personalize the engine
  def _personalize_android(app, package)
    android_manifest_path = File.join(build_android_path, 'AndroidManifest.xml')
    gsub_file android_manifest_path, 'package="com.pichurriajuegos.muruby"', "package=\"%s\"" % package
    android_values_path = File.join(build_android_path, 'res', 'values', 'strings.xml')
    gsub_file android_values_path '<string name="app_name">muruby</string>', '<string name="app_name">%s</string>' % app
  end


  def _configure_mruby_host(mruby_path, gems_base)
    _mruby_update_build_conf(mruby_path, gems_base, "MRuby::Build.new do |conf|\n", "#AUTOMATIC MRBGEMS --NO EDIT--\n")
    _mruby_update_build_conf(mruby_path, gems_base, "MRuby::Build.new('host-debug') do |conf|\n", "#AUTOMATIC MRBGEMS DEBUG --NO EDIT--\n")
  end

  def _configure_mruby_android(mruby_path, gems_base)
    key_to_append = "#AUTOMATIC GEMS ANDROID --NO EDIT--\n"
    insert_into_file File.join(mruby_path, 'build_config.rb'), :after => "# Define cross build settings\n" do
      out = "#AUTOMATIC CROSSBUILD ANDROID\n"
      out += "MRuby::CrossBuild.new('android-armeabi') do |conf|\n"
      out += %Q{
params = { :arch => 'armeabi', :platform => 'android-24', :toolchain => :clang }
}
      out += "toolchain :android, params\n"
      out += "conf.cc.flags = %w(-Wwrite-strings)\n"
      out += "conf.bins = []\n"
      out += key_to_append
      out += "end\n"
      out
    end
    _mruby_update_build_conf(mruby_path, gems_base, key_to_append, "#AUTOMATIC ANDROID MBRGEMS\n")


    #copy skel android projct
    #@todo how do recursive??
    run("rm -rf %s" % build_android_path)
    run("cp -ra %s %s" % [_skel_root('android-project'), build_android_path])
    inside(File.join(build_android_path, 'android-project')) do
      run("patch -p1 < #{_skel_root('android-project.patch')}")
    end
    sdl_android_path = File.join(build_android_path, 'jni', 'SDL')
    repo('curl').clone(sdl_android_path, $HG_REPO_SDL2['SDL'],
                       file_from: 'SDL-release-2.0.5',
                       file_to: 'SDL2-2.0.5.zip')  unless File.directory?(sdl_android_path)

    if options[:enable_sdl_image]
      sdl_image_android_path = File.join(build_android_path, 'jni', 'SDL_image')
      repo('curl').clone(sdl_image_android_path, $HG_REPO_SDL2['SDL_image']) unless File.directory?(sdl_image_android_path)
      sdl_image_android_path_mk = File.join(sdl_image_android_path, 'Android.mk')
      gsub_file sdl_image_android_path_mk, "SUPPORT_WEBP := true", "SUPPORT_WEBP := false"
    end

    if options[:enable_sdl_ttf]
      sdl_ttf_android_path = File.join(build_android_path, 'jni', 'SDL_ttf')
      repo('curl').clone(sdl_ttf_android_path, $HG_REPO_SDL2['SDL_ttf']) unless File.directory?(sdl_ttf_android_path)
      sdl_ttf_android_path_mk = File.join(sdl_ttf_android_path, 'Android.mk')
      gsub_file sdl_ttf_android_path_mk, "SUPPORT_JPG := true", "SUPPORT_JPG := false"
    end

    if options[:enable_sdl_mixer]
      sdl_mixer_android_path = File.join(build_android_path, 'jni', 'SDL_mixer')
      repo('curl').clone(sdl_mixer_android_path, $HG_REPO_SDL2['SDL_mixer']) unless File.directory?(sdl_mixer_android_path)

      sdl_mixer_android_path_mk = File.join(sdl_mixer_android_path, 'Android.mk')
      gsub_file sdl_mixer_android_path_mk, "SUPPORT_MOD_MODPLUG := true", "SUPPORT_MOD_MODPLUG := false"
      gsub_file sdl_mixer_android_path_mk, "SUPPORT_MOD_MIKMOD := true", "SUPPORT_MOD_MIKMOD := false"
      gsub_file sdl_mixer_android_path_mk, "SUPPORT_MP3_SMPEG := true", "SUPPORT_MP3_SMPEG := false"
    end
  end


  def _mruby_update_build_conf(mruby_path, gems_base, after, tag = "")

    insert_into_file File.join(mruby_path,"build_config.rb"), :after => after do
      gems_base.map do |gem|
        case gem
        when Hash
          out = tag
          out += "\nconf.gem :github => '%s', :branch => '%s' " % [gem[:github], gem[:branch]]
          if gem[:cc]
            out += "do |g|\n"
            out += gem[:cc].map{|k,v|
              case v
              when Array
                v.map{|vc| "\tg.#{k} << '#{vc}'"}.join("\n")
              else
                "\tg.#{k} = '#{v}'"
              end
            }.join("\n")
            out += "\nend\n"
          end
          out
        when String
          "conf.gem '%s'" % gem
        end
      end.join("\n") + "\n"
    end
  end


  def _configure_sdl2(app, sdl_path)
    #compile for host
    say("compiling %s for host" % sdl_path)
    @sdl_path = sdl_path
    sdl_lib_path = File.join(build_host_path, 'lib', 'libSDL2.so')
    if File.exists?(sdl_lib_path)
      say("Skipping SDL2...")
      return
    end
    inside(sdl_path) do
      #simulate system install
      run("mkdir include/SDL2")
      run("cp -ra include/* include/SDL2/")
      run("./configure --prefix=%s" % build_host_path, :capture => false)
      run("make")
      run("make install")
      run("make clean")
    end
    if !File.exists?(sdl_lib_path)
      raise RuntimeError, "Failed Compiling SDL2, build manually %s" % sdl_path
    end
  end

  def _configure_sdl2_image(app, sdl_path, sdl_image_path)
    #compile for host
    say("compiling %s for host" % sdl_image_path)
    sdl_image_lib_path = File.join(build_host_path, 'lib', 'libSDL2_image.so')
    if File.exists?(sdl_image_lib_path)
      say("Skipping SDL2 image..")
      return
    end
    inside(sdl_image_path) do
      run("./autogen.sh")
      run("./configure --prefix=%s --with-sdl-prefix=%s" % [build_host_path, build_host_path], :capture => false)
      run("make")
      run("make install")
      run("make clean")
    end
    if !File.exists?(sdl_image_lib_path)
      raise RuntimeError, "Failed Compiling SDL2 image, build manually %s" % sdl_image_path
    end
  end

  def _configure_sdl2_ttf(app, sdl_path, sdl_ttf_path)
    #compile for host
    say("compiling %s for host" % sdl_ttf_path)
    sdl_ttf_lib_path = File.join(build_host_path, 'lib', 'libSDL2_ttf.so')
    if File.exists?(sdl_ttf_lib_path)
      say("Skipping SDL2 ttf...")
      return
    end
    inside(sdl_ttf_path) do
      run("./autogen.sh")
      run("./configure --prefix=%s --with-sdl-prefix=%s" % [build_host_path, build_host_path], :capture => false)
      run("make")
      run("make install")
      run("make clean")
    end
    if !File.exists?(sdl_ttf_lib_path)
      raise RuntimeError, "Failed Compiling SDL2 ttf build manually %s" % sdl_ttf_path
    end

  end

  def _configure_sdl2_mixer(app, sdl_path, sdl_mixer_path)
    #compile for host
    say("compiling %s for host" % sdl_mixer_path)
    sdl_mixer_lib_path = File.join(build_host_path, 'lib', 'libSDL2_mixer.so')
    if File.exists?(sdl_mixer_lib_path)
      say("Skipping SDL2 mixer...")
      return
    end

    inside(sdl_mixer_path) do
      run("./autogen.sh")
      run("./configure --prefix=%s --with-sdl-prefix=%s" % [build_host_path, build_host_path], :capture => false)
      run("make")
      run("make install")
    end
    if !File.exists?(sdl_mixer_lib_path)
      raise RuntimeError, "Failed Compiling SDL2 mixer, build manually %s" % sdl_mixer_path
    end

  end

end

module Muruby
  class Game < Thor
    include Thor::Actions
    include Build

    @@app_path = nil
    def self.source_root
      File.dirname(__FILE__)
    end

    def exit_on_failure?
      true
    end

    class_option :ndk_dir, :type => :string, :default => File.join(ENV["HOME"], '.muruby_android_ndk')
    class_option :sdk_dir, :type => :string, :default => File.join(ENV["HOME"], '.muruby_android_sdk')
    desc 'install-android-environment', 'install android environment'
    def install_android_environment
      @android = AndroidEnvironment.new(self, options[:sdk_dir], options[:ndk_dir])
      @android.configure_ndk
      puts "export ANDROID_NDK_HOME=#{@android.android_ndk_dir}"
    end

    class_option :enable_sdl_mixer, :type => :boolean, :default => false, :desc => "Not Implemented yet"
    class_option :enable_sdl_ttf, :type => :boolean, :default => false, :desc => "Not implemented yet"
    class_option :enable_sdl_image, :type => :boolean, :default => false, :desc => "Not implemented yet"
    class_option :mruby_unstable, :type => :boolean, :default => false, :desc => "Use the master of mruby"
    class_option :dev_github_mruby_sdl2, :type => :string, :default => 'mruby-sdl2/mruby-sdl2', :desc => "Choose implementation mruby SDL2 on github, ex: mruby-sdl2/mruby-sdl2."
    class_option :build_android, :type => :boolean, :default => true, :desc => "Build android"
    method_option :package, :type => :string, :default => 'com.pichurriajuegos.muruby', :required => true, :banner => 'ej: com.pichurriajuegos.muruby the package'
    desc 'create <app>', "Create a directory <name> structure with everything need for creating games for Android, and GNU/Linux.
"
    def create(name)
      if options[:build_android]
        abort "Need enviroment variable ANDROID_NDK_HOME" unless ENV["ANDROID_NDK_HOME"]
      end

      @@app_path =  File.absolute_path File.join(".", name)
      source_paths << _skel_root()
      _create_app(name)
      _create_core(name)
    end

    no_commands {
      def app_path
        @@app_path
      end

      def cache_path
        File.join(Dir.home, ".muruby")
      end

      def repo(type)
        case type
        when 'hg'
          Hg.new(self)
        when 'git'
          Git.new(self)
        when 'curl'
          Curl.new(self)
        else
          raise RuntimeError, "Invalid Cloner %s\n" % [type]
        end
      end

    }

    private

    def _create_app(name)
      empty_directory "#{name}/app"
      empty_directory "#{name}/app/game"
      copy_file "doc/README_game.md", "#{name}/app/game/README.md"
      copy_file "game/runtime.rb", "#{name}/app/game/runtime.rb"
      copy_file "Rakefile", "#{name}/app/Rakefile"
      copy_file "Gemfile", "#{name}/app/Gemfile"
      copy_file ".gitignore.tmpl", "#{name}/app/.gitignore"

      empty_directory "#{name}/app/resources"
      copy_file "doc/README_resources.md", "#{name}/app/resources/README.md"

      empty_directory "#{name}/app/deploy"
      copy_file "doc/README_deploy.md", "#{name}/app/deploy/README.md"
    end

    def _create_core(name)
      empty_directory "#{name}/core"

      #download sources
      sdl_path = "#{name}/core/SDL2"
      repo('curl').clone(sdl_path, $HG_REPO_SDL2['SDL'],
                         file_from: 'SDL-release-2.0.5',
                         file_to: 'SDL2-2.0.5.zip') unless File.directory?(sdl_path)
      sdl_image_path = "#{name}/core/SDL2_image"
      repo('curl').clone(sdl_image_path, $HG_REPO_SDL2['SDL_image']) unless File.directory?(sdl_image_path) if options[:enable_sdl_image]
      sdl_ttf_path = "#{name}/core/SDL2_ttf"
      repo('curl').clone(sdl_ttf_path, $HG_REPO_SDL2['SDL_ttf']) unless File.directory?(sdl_ttf_path) if options[:enable_sdl_ttf]
      sdl_mixer_path = "#{name}/core/SDL2_mixer"
      repo('curl').clone(sdl_mixer_path, $HG_REPO_SDL2['SDL_mixer']) unless File.directory?(sdl_mixer_path) if options[:enable_sdl_mixer]

      mruby_path = "#{name}/core/mruby"
      unless File.directory?(mruby_path)
        repo('git').clone(mruby_path, $GIT_REPO_MRUBY)
      end
      inside(mruby_path) do
        unless options[:mruby_unstable]
          run("git checkout 1.4.1")
        else
          run("git checkout master")
        end
      end
      #mruby-android
      #mruby-require

      #configure apps

      _configure_sdl2(name, sdl_path)
      _configure_sdl2_image(name, sdl_path,  sdl_image_path) if options[:enable_sdl_image]
      _configure_sdl2_ttf(name, sdl_path, sdl_ttf_path) if options[:enable_sdl_ttf]
      _configure_sdl2_mixer(name, sdl_path, sdl_mixer_path) if options[:enable_sdl_mixer]

      _configure_mruby(name, mruby_path, options.dup)
    end

    def _skel_root(path = nil)
      gem_dir = nil
      begin
        spec = Gem::Specification.find_by_name("muruby")
        gem_dir = spec.gem_dir
      rescue Gem::MissingSpecError
        gem_dir = File.absolute_path File.join(File.expand_path(File.dirname(__FILE__)), '..', '..')
      end

      if path
        File.join(gem_dir, 'skel', path)
      else
        File.join(gem_dir, 'skel')
      end
    end
  end

  class Android < Thor
    include Thor::Actions

    def self.source_root
      File.dirname(__FILE__)
    end
  end


  class Gnu < Thor
    include Thor::Actions
    def self.source_root
      File.dirname(__FILE__)
    end
  end

end
