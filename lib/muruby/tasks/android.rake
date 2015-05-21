
namespace :android do
    desc "Check syntax ruby code"
    task :check_syntax do
      FileList[File.join(Muruby.paths[:game_root], '*.rb')].each do |ruby_file|
        sh Muruby.paths[:mruby_mrbc], '-c', ruby_file
      end
    end

     desc "Compile .rb to .c"
    #This create a jni/game.c file
    #with the function *muruby_game_load(mrb_state*, mrbc_context*)* for load all classes an
    #Kernel.require for load file :)
    task :compile_rb => [:check_syntax] do
      game_c = File.join(Muruby.paths[:core_path], 'build_android', 'jni', 'src', 'game.c')
      fgame_c = File.new(game_c, "w")
      fgame_c << "#include <mruby.h>\n"
      fgame_c << "#include <mruby/compile.h>\n"
      fgame_c << "#include <mruby/value.h>\n"
      fgame_c << "#include <mruby/string.h>\n"
      fgame_c << "#include <mruby/irep.h>\n"
      fgame_c << "#include <mruby/dump.h>\n"
      fgame_c << "static mrbc_context *cxt_global;\n"

      fgame_c.close
      game_files = []
      FileList[File.join(Muruby.paths[:game_root],'**/*.rb')].each { |ruby_file|
        name_ruby_file = ruby_file.gsub(Muruby.paths[:game_root], "").gsub(/^\//,"")
        basename_ruby_file = name_ruby_file.gsub(/[^a-zA-Z0-9]+/,"_");
        game_file = {}
        name_for_require = 'game_'
        name_for_require += basename_ruby_file.to_s.chomp(File.extname(basename_ruby_file))
        game_file[:name_for_require] = name_for_require
        game_file[:name] = name_ruby_file.to_s
        c_var_loaded = "%s_loaded" % name_for_require

        #@todo how option debug disable??
        sh "%s -B%s -g -o- %s >> %s" % [Muruby.paths[:mruby_mrbc], name_for_require, ruby_file, game_c]
        fgame_c = File.new(game_c, "a")
        fgame_c << "static int %s = 0;\n" % c_var_loaded
        #variable:C flag

        c_func_load_name = "%s_load" % name_for_require
        c_func_load = "
        int #{c_func_load_name}(mrb_state* mrb) {
        if(!#{c_var_loaded}) {
mrbc_context* cxt = mrbc_context_new(mrb);
mrbc_filename(mrb, cxt, \"#{name_ruby_file}\");
           cxt->capture_errors = 1;
           cxt->filename = \"#{name_ruby_file}\";
 int ai = mrb_gc_arena_save(mrb);
 mrb_value irep = mrb_load_irep_cxt(mrb, #{name_for_require}, cxt);
 mrb_gc_arena_restore(mrb, ai);
 #{c_var_loaded} = 1;
mrbc_context_free(mrb,cxt);
 return 1; //loaded
 } 
return 0; //not loaded
}
"
        fgame_c << c_func_load
        fgame_c.close
        game_file[:func_load] = c_func_load_name
        game_files << game_file
        
      }

      fgame_c = File.new(game_c, "a")
#This simulate Kernel#load
#very simple it load and run +file+ passed
c_func_muruby_game_load = "muruby_game_kernel_load"
#KERNEL#REQUIRE
fgame_c << "mrb_value #{c_func_muruby_game_load}(mrb_state *mrb, mrb_value self) {
mrb_value file;
mrb_get_args(mrb, \"o\", &file);
if(!mrb_string_p(file)) mrb_raise(mrb, E_ARGUMENT_ERROR, \"Need String\");
"
game_files.each do |game_require|
fgame_c << "if(!strcmp(RSTRING_PTR(file), \"#{game_require[:name]}\")) {
if(#{game_require[:func_load]}(mrb)) return mrb_true_value();
return mrb_false_value();
}\n
"
end
fgame_c << "return mrb_nil_value();}\n\n"
fgame_c.fsync
#implemest single require for android
fgame_c << "void muruby_game_load(mrb_state *mrb, mrbc_context* cxt){
  struct RClass *krn;
  krn = mrb->kernel_module;
"
#define methods mrb
fgame_c << " mrb_define_method(mrb, krn, \"load\", #{c_func_muruby_game_load}, MRB_ARGS_REQ(1));\n"
#load Runtime
fgame_c << ' cxt_global = cxt; '
fgame_c << ' game_runtime_rb_load(mrb); '
fgame_c << "\n}\n"
fgame_c.close
       sh "ndk-build -C %s main" % Muruby.paths[:android_build_path]
    end

    file File.join(Muruby.paths[:android_build_path], './libs/armeabi/libSDL2.so') do
      sh "ndk-build -C %s NDK_DEBUG=1" % Muruby.paths[:android_build_path]
    end

    desc "Clean android project"
    task :clean do
      Dir.chdir(Muruby.paths[:android_build_path]) do
        sh "ndk-build clean"
      end
    end
    
    desc "Compile for android"
    task :build => [:compile_rb] do
      sh "ndk-build -C %s NDK_DEBUG=1 -j2" % Muruby.paths[:android_build_path]
    end

    namespace :apk do
      desc "Create apk debug"
      task :debug => ['muruby:android:build'] do
        Dir.chdir(Muruby.paths[:android_build_path]) do
          Dir.mkdir('assets') unless File.exists?('assets/')
          sh 'cp -ra %s/* assets/' % Muruby.paths[:resource_root]
          sh "ant debug"
        end
      end
      desc "Create apk release"
      task :release => ['muruby:android:build'] do
        Dir.chdir(Muruby.paths[:android_build_path]) do
          Dir.mkdir('assets') unless File.exists?('assets/')
          sh 'cp -ra %s/* assets/' % Muruby.paths[:resource_root]
          sh "ant release"
        end
      end
      
      desc "Install apk on avd"
      namespace :install do
        task :debug do
          Dir.chdir(Muruby.paths[:android_build_path]) do
            sh "ant installd"
          end
        end
        task :release do
          Dir.chdir(Muruby.paths[:android_build_path]) do
            sh "ant installr"
          end
        end
      end
    end

end
