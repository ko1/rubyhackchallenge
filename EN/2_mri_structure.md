# (2) MRI source code structure

## About this document

This document introduces MRI source code structures.
Also it introduces minimum knowlege about how to hack the MRI source code.

There are the followign topics:

* Exercise: Clone the MRI source code.
* Exercise: Build MRI and install built binaries.
* Exercise: Execute Ruby programs with built Ruby.
* MRI source code structures.
* Exercise: 1st hack. Change the version description.

## Assumptions

The following commands based the knowlege of Linux, Mac OSX and so on. We don't show details about Windows. Please refer other documents.

We assume the following directory structures:

* `workdir/`
  * `ruby/` <- git clone'd directory
  * `build/` <- build directory (compiled `*.o` are stored there)
  * `install/` <- install directory (`workdir/install/bin/ruby` is installed binary)

We need the following commands :

git, ruby, autoconf, bison, gcc (or clang, etc）, make is required.
If you have depending other libraries (such as zlib, openssl and so on), extension libraries will be built successfully.

If you can use `apt-get` (or `apt`), then you can get all required commands:

```
$ sudo apt-get install git ruby autoconf bison gcc make zlib1g-dev libffi-dev libreadline-dev libgdbm-dev libssl-dev
```

## Exercise: Clone the MRI source code.

Use the following commands:

1. `$ mkdir workdir`
2. `$ cd workdir`
3. `$ git clone https://github.com/ruby/ruby.git` # And you can get cloned sources in `workdir/ruby`

Because of network bandwidth, please clone at home.

## Exercise: Build MRI and install built binaries.

1. Check required commands described above.
2. `$ cd workdir/` # Move to `workdir`
3. `$ cd ruby` # Move to `workdir/ruby`
4. `$ autoconf`
5. `$ cd ..`
6. `$ mkdir build`
7. `$ cd build`
8. `$ ../ruby/configure --prefix=$PWD/../install --enable-shared`
  * `prefix` option specifies a install directory. You can specify any directory in full-path (in this case, `workdir/install` is specified).
  * If you use `Homebrew`, `--with-openssl-dir="$(brew --prefix openssl)" --with-readline-dir="$(brew --prefix readline)" --disable-libedit` is required.
9. `$ make -j` # Run build. `-j` specifis *parallel build`.
10. `$ make install` # tips: `make install-nodoc` install directory without rdoc (fast install).
11. `$ ../install/bin/ruby -v` will show version description of your installed ruby command.

NOTE: `V=1` option will show details about what `make` command does. By default, `V=0` is specified and details are suppressed.

## Exercise: Execute Ruby programs with built Ruby

There are severail way to run Ruby scripts on built Ruby.

Most simple way is launching installed Ruby. This is completely same as invoking Ruby command we generally do, but we need to install Ruby (`make install`) just after we modify Ruby command. It consumes several minutes.

Here we introduce convenient ways to launch built Ruby without installing.

### Use miniruby

After building Ruby, there is a command named 'miniruby` in `workdir/build`. `miniruby` is limited Ruby to build Ruby itself. However there are only few "Limited" features such as "unable to load extension libraries", "limited encoding" and so on and you can try most of Ruby syntax.

`miniruby` is built at first phase of entirely Ruby build process, so that we can use `miniruby` to try modification of MRI.

So the following development process is efficient:

1. Modify MRI
2. Run `make miniruby` to build `miniruby` (it is faster than `make` or `make all`)
3. Run related Ruby scripts with `miniruby` and you can know modification is correct or not.

To support this modification process, we provide `make run` rule. This rule do the following:

1. Build `miniruby`
2. Run `workdir/ruby/test.rb` (`test.rb` in source directory) with built miniruby.

Using `make run`, you can try modification with the following steps.

1. Write `ruby/test.rb` what you want to check. Note that we can't use `gem` or extension libarries in `test.rb`.
2. Modify MRI.
3. `$ make run` at the build directory and you can have a result.

### Try with full-set Ruby (not miniruby)

If you want to run normal Ruby which can load extension libraries, you can use `make runruby`.

1. Write `ruby/test.rb` what you want to check.
2. Modify MRI.
3. `$ make runruby` at the build directory and you can have a result.

### Debug with gdb

NOTE: gdb on Mac OSX is difficult to try. The following commands assumes Linux environment.

Modifing MRI source code introduces critical problesm such as SEGV easily.
To debug such bugs, we provide support rules to debug with gdb. Of course, you can set break points.

1. Write `ruby/test.rb` what you want to check. Note that we can't use `gem` or extension libarries in `test.rb`.
3. `$ make gdb` and run miniruby with gdb. If there are no problems, then gdb finishes silently.

`make gdb` use `./miniruby`. If you want to debug with `./ruby`, use `make gdb-ruby` rule.

If you want to use break points, modify `run.gdb` file which is generated by `make gdb` command.
For example, `b func_name` gdb command inserts a break point at the beggining of the `func_name` function.

There is similar rule `$ make lldb` to use lldb instead of gdb (but Koichi doesn't know details because he doesn't use lldb).

### Ruby Ruby tests

1. `$ make btest` # run bootstrap tests in `ruby/bootstraptest/`
2. `$ make test-all` # run test-unit tests in `ruby/test/`
3. `$ make test-spec` # run tests provided in `ruby/spec`

These three have different purposes and characteristics.

## MRI source code structures

### Interpreter

At a glance, the following directory strcutre you can observe:

* `ruby/*.c` MRI core files
    * VM cores
        * VM
            * `vm*.[ch]`: VM implementation
            * `vm_core.h`: definitions of VM data structure
            * `insns.def`: definitions of VM instructions
        * `compile.c, iseq.[ch]`: instruction sequence (bytecode)
        * `gc.c`: GC and memory management
        * `thread*.[ch]`: Thread management
        * `variable.c`: variable management
        * `dln*.c`: dll management for extension libraries
        * `main.c`, `ruby.c`: the entry point of MRI
        * `st.c`: Hash algorithm implementation (see https://blog.heroku.com/ruby-2-4-features-hashes-integers-rounding)
    * Embedded classes
        * `string.c`: String class
        * `array.c`: Array class
        * ... (file names shows class names, such as time.c for Time class)
* `ruby/*.h`: internal definitions. C-extension libraries can't use them.
* `ruby/include/ruby/*`: external definitions. C-extension libraries can use them.
* `ruby/enc/`: encoding information.
* `ruby/defs/`: several definitions.
* `ruby/tools/`: tools to build MRI.
* `ruby/missing/`: implementations which is lacked on several enviromnents.
* `ruby/cygwin/`, `ruby/nacl/`, `ruby/win32`, ...: OS/system dependent code.

### Libraries

There are two types libraries.

* `ruby/lib/`: Standard libraries written in Ruby.
* `ruby/ext/`: Bundled extension libraries written in C.

### Tests

* `ruby/basictest/`: place of old test
* `ruby/bootstraptest/`: bootstrap test
* `ruby/test/`: tests written by test-unit notation
* `ruby/spec/`: tests written by RSpec notation

### misc

* `ruby/doc/`, `ruby/man/`: documents

## Ruby's build process

Ruby build process contains several phases containing source code generation and so on. Several tools are written in Ruby so that Ruby build process requires Ruby interpreter. tar ball contains generated source code so that we don't need Ruby interpreter (and other tools such as bison) to build Ruby using tar ball.

If you want to build MRI with souce code fetched by Subversion or Git repository, you need a Ruby interpreter.

Build and install process are the following steps:

1. Build miniruby
    1. parse.y -> parse.c: Compile syntax rules to C code by bison
    2. insns.def -> vm.inc: Compile VM instructions to C code by ruby (`BASERUBY`)
    3. `*.c` -> `*.o` (`*.obj` on Windows): Compile C codes to object files.
    4. link object files into miniruby
2. Build encoding
    1. translate enc/... to appropriate C code by `miniruby`
    2. compile C code
3. Build C-extension libraries
    1. Make `Makefile` from `extconf.rb` by `mkmf.rb` and `miniruby`
    2. Run `make` using generated `Makefile`.
4. Build `ruby` command
5. Genearate documents (`rdoc`, `ri`)
6. Install MRI (an install directory is specified at `configure --prefix` option)

In fact, there are more steps. However it is difficult to write up all and I don't cover everything. So several steps are eliminated.
You can see all make rules in `common.mk` (and some other files).

## Exercise: 1st hack. Change the version description

Let's start to modify MRI. We assume that all source code is placed at `workdir/ruby/`.

At first, let's modify version description which is displayed with `ruby -v` (or  `./miniruby -v`) as your own Ruby (for example, show version description with your name).

1. open `version.c`.
2. view `version.c` entirely.
3. `ruby_show_version()` seems a suspect.
4. `fflush()` isa C function flushes output buffer, so that we can guess we only need to put printing code just before `fflush()` call.
5. put `printf("...\n");` (you can write your favorite string at `...`)
6. `$ make miniruby` and build.
7. `$ ./miniruby -v` and check the result.
8. `$ make install` and install build ruby.
9. `$ ../install/bin/ruby -v` and check the result with installed ruby.

Instead of inserting `printf(...)`, replacing `ruby ...` description with something (such as `perl ...` and so on) would be interesting ;p

