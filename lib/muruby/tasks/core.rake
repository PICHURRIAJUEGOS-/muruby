namespace "core" do
  desc "Compile mruby"
  task :compile_mruby do
    #necesita de ANDROID_STANDALONE_TOOLCHIAN
    raise RuntimeError, "Need ANDROID_STANDALONE_TOOLCHAIN or ANDROID_NDK_HOME env var" unless ENV['ANDROID_STANDALONE_TOOLCHAIN'] || ENV['ANDROID_NDK_HOME']
    Dir.chdir(Muruby.paths[:mruby_path]) do
      sh "rake"
    end
  end

end
