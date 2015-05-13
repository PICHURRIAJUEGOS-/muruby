===MURUBY
Motor para realizacion de video juegos con soporte para: Android >= 2.3, GNU/Linux.

Utilizando como lenguaje de scripting *mruby*.
Y principalmente el *mrgem* *SDL2*.

==TUTORIAL

  * Clonar el repositorio: "git clone https://www.github.com/pichurriaj/muruby"
  * Compilar el gem e instalar
    * *gem build muruby.gemspec*
	* *gem install muruby-\*.gem*
  * Crear aplicacion: *muruby create tutorial --package=org.prueba.tutorial*
    * esto necesita internet para descargar dependencias ademas de: gcc, autoconf, automake, libtool..etc.
  * el juego se crea en app/game/*.rb
  * el core o lo necesario para funcionar esta en core/*
  * para mirar las opciones de compilacion e instalacion, en la carpeta *app/* ejecutar *rake -T*

== MULTI-PROYECTOS

  * Crear directorio **proyectos/**
    * crear Gemfile con
	  ~~~ruby
	  source 'https://rubygems.org'
	  gem 'rake'
	  gem 'thor'
	  gem 'gettext'
	  gem 'muruby', github: 'pichurriaj/muruby'
	  ~~~
    * instalar
	  ~~~bash
	  $ bundle install
	  ~~~
	* ejecutar y crear proyectos
	  ~~~bash
	  $ bundle exec muruby create miproyecto1
	  ~~~
	  
	  
== REQUERIMIENTOS

  * ANDROID-NDK con toolchain
    * $ANDROID_NDK_HOME/build/tools/make-standalone-toolchain.sh --platform=android-14 --install-dir=$HOME/android-14-toolchain
  * variable de entorno 
    * export NDK_ROOT=$HOME/android-14-toolchain
	* export PATH="$NDK_ROOT/bin:$PATH"
  
==TODO

=== DEPURAR

Actualmente es funcional, pero la depuracion se realiza utilizando el *logcat*, no hay
forma de depurar correctamente, detener, mirar la pila, memoria, codigo, etc..
hace falta un buen depurador; 
algunos proyectos base:
  * mruby-mdebug
  * mruby-debugger
