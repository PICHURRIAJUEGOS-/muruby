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

==TODO
=== DEPURAR
Actualmente es funcional, pero la depuracion se realiza utilizando el *logcat*, no hay
forma de depurar correctamente, detener, mirar la pila, memoria, codigo, etc..
hace falta un buen depurador; 
algunos proyectos base:
  * mruby-mdebug
  * mruby-debugger
