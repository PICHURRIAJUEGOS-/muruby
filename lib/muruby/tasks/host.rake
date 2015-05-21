file Muruby.paths[:sdl_so] do
  Dir.chdir(sdl_root) do 
    sh './configure'
    sh 'make -j2'    
  end
end


namespace :host do
    
  desc "irb muruby on the host (development)"
  task :shell do
    sh("LD_LIBRARY_PATH=%s; %s" % [File.dirname(Muruby.paths[:sdl_so]), Muruby.paths[:mruby_mirb]])
  end
  
  desc "Run debugger on the host (development) pass <filename .rb> for run specific file"
  task :debug, [:file]  => [Muruby.paths[:sdl_so]] do |t, args|
    main_rb = 'runtime.rb'
    if(args[:file])
      main_rb = args[:file]
    end
    bin_mruby = Muruby.paths[:mruby_mrdb].to_s
    FileUtils.rm_rf '.debug_run'
    mkdir '.debug_run'
    Dir.chdir('.debug_run') do
      sh 'cp %s .' % [File.join(Muruby.paths[:game_root], '*.rb')]
      sh 'cp %s .' % File.join(Muruby.paths[:resource_root], '*')
      sh("LD_LIBRARY_PATH=%s; %s  %s" % [File.dirname(Muruby.paths[:sdl_so]), bin_mruby, main_rb])
    end
    rmdir '.debug_run'
  end
  
  desc "Run the game on the host (development) pass <filename .rb> for run specific file"
  task :run, [:file]  => [Muruby.paths[:sdl_so]] do |t, args|
    main_rb = 'runtime.rb'
    if(args[:file])
      main_rb = args[:file]
    end
    
    FileUtils.rm_rf '.test_run'
    sh 'cp -fa %s .test_run' % [Muruby.paths[:game_root]]
    sh 'cp -fa %s/* .test_run' % [Muruby.paths[:resource_root]]
    bin_mruby = Muruby.paths[:mruby_mruby].to_s
    Dir.chdir('.test_run') do
      sh("LD_LIBRARY_PATH=%s; %s %s" % [File.dirname(Muruby.paths[:sdl_so]), bin_mruby, main_rb])
    end
    rmdir '.test_run'
    
  end
  

end
