#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include "SDL.h"

#if defined(__IPHONEOS__) || defined(__ANDROID__)
#define HAVE_OPENGLES
#endif

#include <mruby.h>
#include <mruby/proc.h>
#include <mruby/data.h>
#include <mruby/string.h>
#include <mruby/array.h>
#include <mruby/proc.h>
#include <mruby/compile.h>
#include <mruby/variable.h>

#ifdef __ANDROID__
#include <android/log.h>
#ifdef printf
#undef printf
#endif
#ifdef vprintf
#undef vprintf
#endif
#define printf(args...) __android_log_print(ANDROID_LOG_INFO, "libtcod", ## args)
#define vprintf(args...) __android_log_vprint(ANDROID_LOG_INFO, "libtcod", ## args)
 
#ifdef assert
#undef assert
#endif
#define assert(cond) if(!(cond)) __android_log_assert(#cond, "libtcod", "assertion failed: %s", #cond)
#endif

const char* program_name = "muruby";

long fileSize(const char* file) {
  SDL_RWops* rwops;
  long size_file;
  rwops = SDL_RWFromFile(file, "r");
  if(!rwops) return -1;
  size_file = SDL_RWseek(rwops, 0, RW_SEEK_END);
  SDL_RWclose(rwops);
  return size_file;
}

int readFile(const char* file,char **buff) {
  SDL_RWops* rwops;

  rwops = SDL_RWFromFile(file, "r");
  if(!rwops) return -1;
  long size = fileSize(file);
  *buff = malloc(sizeof(buff)*size + 1);
  SDL_RWread(rwops, *buff, sizeof(char), fileSize(file));
  SDL_RWclose(rwops);
  return 0;
}
extern void muruby_game_load(mrb_state* mrb, mrbc_context* cxt);

typedef void (*output_stream_func)(mrb_state*, void*, int, const char*, ...);
static void
print_backtrace_android_i(mrb_state *mrb, void *stream, int level, const char *format, ...)
{
  va_list ap;

  va_start(ap, format);
  __android_log_vprint(ANDROID_LOG_DEBUG, "SDL", format, ap);
  va_end(ap);
}

static void
mrb_output_backtrace_android(mrb_state *mrb, struct RObject *exc, output_stream_func func, void *stream)
{
  mrb_callinfo *ci;
  mrb_int ciidx;
  const char *filename, *method, *sep;
  int i, line;

  func(mrb, stream, 1, "trace:\n");
  ciidx = mrb_fixnum(mrb_obj_iv_get(mrb, exc, mrb_intern_lit(mrb, "ciidx")));
  if (ciidx >= mrb->c->ciend - mrb->c->cibase)
    ciidx = 10; /* ciidx is broken... */

  for (i = ciidx; i >= 0; i--) {
    ci = &mrb->c->cibase[i];
    filename = NULL;
    line = -1;

    if (MRB_PROC_CFUNC_P(ci->proc)) {
      continue;
    }
    else {
      mrb_irep *irep = ci->proc->body.irep;
      mrb_code *pc;

      if (mrb->c->cibase[i].err) {
        pc = mrb->c->cibase[i].err;
      }
      else if (i+1 <= ciidx) {
        pc = mrb->c->cibase[i+1].pc - 1;
      }
      else {
        pc = (mrb_code*)mrb_cptr(mrb_obj_iv_get(mrb, exc, mrb_intern_lit(mrb, "lastpc")));
      }
      filename = mrb_debug_get_filename(irep, pc - irep->iseq);
      line = mrb_debug_get_line(irep, pc - irep->iseq);
    }
    if (line == -1) continue;
    if (ci->target_class == ci->proc->target_class)
      sep = ".";
    else
      sep = "#";

    if (!filename) {
      filename = "(unknown)";
    }

    method = mrb_sym2name(mrb, ci->mid);
    if (method) {
      const char *cn = mrb_class_name(mrb, ci->proc->target_class);

      if (cn) {
        func(mrb, stream, 1, "\t[%d] ", i);
        func(mrb, stream, 0, "%s:%d:in %s%s%s", filename, line, cn, sep, method);
        func(mrb, stream, 1, "\n");
      }
      else {
        func(mrb, stream, 1, "\t[%d] ", i);
        func(mrb, stream, 0, "%s:%d:in %s", filename, line, method);
        func(mrb, stream, 1, "\n");
      }
    }
    else {
        func(mrb, stream, 1, "\t[%d] ", i);
        func(mrb, stream, 0, "%s:%d", filename, line);
        func(mrb, stream, 1, "\n");
    }
  }
}

int
main(int argc, char *argv[])
{
  mrb_state* mrb;
  mrbc_context* cxt;
  char *runtime_code;
  
  mrb = mrb_open();
  if (mrb == NULL) {
    SDL_Log("Invalid mrb_state, exiting mruby\n", stderr);
    return EXIT_FAILURE;
  }
  cxt = mrbc_context_new(mrb);
  muruby_game_load(mrb, cxt);
  if(mrb->exc) {
      mrb_output_backtrace_android(mrb, mrb->exc, print_backtrace_android_i, (void*)stderr);
    mrb_value ex = mrb_funcall(mrb, mrb_obj_value(mrb->exc), "inspect", 0);
    if(mrb_type(ex) == MRB_TT_STRING) {

      SDL_Log("RUBY EXCEPTION: %s", RSTRING_PTR(ex));
    }else{
      SDL_Log("RUBY EXCEPTION OCURRED");
    }
  }
  mrbc_context_free(mrb, cxt);
  mrb_close(mrb);
  SDL_Log("Closed %s", program_name);
  //stop all app
  //see SDL_android_main.cpp
  //@see http://sdl.5483.n7.nabble.com/SDL2-Android-Exiting-td38327.html
  exit(0);
}

/* vi: set ts=2 sw=4 expandtab: */



