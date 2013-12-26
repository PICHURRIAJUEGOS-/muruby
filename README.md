===MURUBY
Motor para realizacion de video juegos con soporte para: Android >= 2.3, GNU/Linux.

Utilizando como lenguaje de scripting *mruby* y *mrbgems*.

==TUTORIAL

  * Instalar: *gem install muruby*
  * Crear aplicacion: *muruby create tutorial --package=org.prueba.tutorial*
    * esto necesita internet para descargar dependencias ademas de: gcc, autoconf, automake, libtool..etc.
  * el juego se crea en app/game/*.rb
  * el core o lo necesario para funcionar esta en core/*
  * para mirar las opciones de compilacion e instalacion, en la carpeta *app/* ejecutar *rake -T*
