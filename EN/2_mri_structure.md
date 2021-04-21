# (2) MRI source code structure

## About this document

This document introduces the structure of the MRI source code.
It also introduces the minimum required knowledge for hacking on MRI.

There are the following topics:

* Exercise: Clone the MRI source code.
* Exercise: Build MRI and install built binaries.
* Exercise: Execute Ruby programs with built Ruby.
* MRI source code structures.
* Exercise: The 1st hack. Change the version description.

## Assumptions

The following commands assume an Unix-like environment, such as Linux, macOS, etc. If you're using a Windows environment, you will need to refer to other resources.

NOTE: We provide an experimental docker image: `docker pull koichisasada/rhc`. Use `rubydev` account with `su rubydev` and enjoy hacking.

We assume the use of the following directory structure:

* `workdir/`
  * `ruby/` <- git cloned directory
  * `build/` <- build directory (`*.o` files and other compilation artifacts are stored here)
  * `install/` <- install directory (`workdir/install/bin/ruby` is the installed binary)

The commands `git`, `ruby`, `autoconf`, `bison`, `gcc` (or `clang`, etc), and `make` are required.
Standard Ruby extensions (such as zlib, openssl, etc.) will be built if the libraries they depend on are available.

If you use `apt-get` (or `apt`) for package management in your environment, then you can get all dependencies with the following command:

```
$ sudo apt-get install git ruby autoconf bison gcc make zlib1g-dev libffi-dev libreadline-dev libgdbm-dev libssl-dev
```

## Exercise: Clone the MRI source code

Use the following commands:

1. `$ mkdir workdir`
2. `$ cd workdir`
3. `$ git clone https://github.com/ruby/ruby.git` # The cloned source code will be available in `workdir/ruby`

Due to limited network bandwidth at the venue, please clone the source code at home.

## Exercise: Build MRI and install built binaries

1. Check the required commands described above.
2. `$ cd workdir/` # Move to `workdir`
3. `$ cd ruby` # Move to `workdir/ruby`
4. `$ autoconf`
5. `$ cd ..`
6. `$ mkdir build`
7. `$ cd build`
8. `$ ../ruby/configure --prefix=$PWD/../install --enable-shared`
  * the `prefix` option specifies an install directory. You can specify the directory of your choice by supplying the full absolute path (in this case, `workdir/install` is specified).
  * users of `Homebrew` will need to add the following options `--with-openssl-dir="$(brew --prefix openssl)" --with-readline-dir="$(brew --prefix readline)" --disable-libedit`
9. `$ make -j` # Run build. `-j` specifies *parallel build*.
10. `$ make install` # Tip: for a faster install, instead run `make install-nodoc` to install ruby without rdoc.
11. `$ ../install/bin/ruby -v` will show the version description of your installed ruby command.

NOTE: Running `make` with the `V=1` option (i.e. `make V=1 -j`, etc.) will output the full commands that are executed during the build. By default, `V=0` is specified and detailed output is suppressed.

## Exercise: Execute Ruby programs with the Ruby you built

There are several ways to run Ruby scripts on the Ruby you built.

The simplest way is to launch the installed Ruby directly, i.e. invoke `workdir/install/bin/ruby`. This is the same as invoking a pre-built Ruby binary. However, this means you will need to run `make install` every time you make a change to the Ruby source code, which can be rather time-consuming.

Here we introduce a few convenient ways to launch our version of Ruby without installing.

### Use miniruby

After building Ruby, the `miniruby` command is available in `workdir/build`. `miniruby` is a limited version of Ruby for building Ruby itself. The limitations of `miniruby`, however, are minimal: it is unable to load extension libraries and limited encodings are available. You can try most of Ruby's syntax using `miniruby`.

`miniruby` is built during the first phase of the Ruby build process. Thus, `miniruby` is useful for a early verification of modifications made to MRI.

The following development loop is very efficient:

1. Modify MRI
2. Run `make miniruby` to build `miniruby` (this is faster than `make` or `make all`)
3. Run a Ruby script in `miniruby` to test the correctness of your modifications.

To support this development loop, we provide a `make run` rule in the Makefile. This rule does the following:

1. Build `miniruby`
2. Run `workdir/ruby/test.rb` (`test.rb` in source directory) with the built miniruby.

Using `make run`, you can test your modifications with the following steps.

1. Write a test for your modifications in `ruby/test.rb`. Note that you can't require gems or extension libraries in `test.rb`.
2. Modify MRI.
3. Invoke `$ make run` in the build directory

### Use fully-featured Ruby (not miniruby)

If you want to run the "normal" Ruby, which can load extension libraries, you can use `make runruby`. This allows you to run Ruby without the `make install` step, which should save you some time.

1. Write in `ruby/test.rb` what you want to check.
2. Modify MRI.
3. Invoke `$ make runruby` in the build directory.

### Debug with gdb

NOTE: Running `gdb` on macOS can be quite difficult. The following commands assume a Linux environment.

When modifying the MRI source code, you can easily introduces critical problems that result in a SEGV. To debug such problems, we provide Makefile rules to support debugging with gdb. Of course, you can also debug with break points.

1. Write in `ruby/test.rb` what you want to check. Note that you can't use gems or extension libraries in `test.rb`.
3. Invoke `$ make gdb` to run miniruby with gdb. If there are no problems, gdb finishes silently.

`make gdb` uses `./miniruby`. If you want to debug with `./ruby`, use `make gdb-ruby` rule.

If you want to use break points, modify the `run.gdb` file generated by the `make gdb` command.
For example, the `b func_name` gdb command inserts a break point at the beginning of the `func_name` function.

There is a similar rule for [lldb](https://lldb.llvm.org/), `$ make lldb`, for using lldb instead of gdb (but Koichi doesn't know the details because he doesn't use lldb). It may be useful if you use macOS.

### Run Ruby tests

1. `$ make btest` # run bootstrap tests in `ruby/bootstraptest/`
2. `$ make test-all` # run test-unit tests in `ruby/test/`
3. `$ make test-spec` # run tests provided in `ruby/spec`

These three tests have different purposes and characteristics.

## MRI source code structures

### Interpreter

At a glance, the following directory structure you can observe:

* `ruby/*.c` MRI core files
    * VM cores
        * VM
            * `vm*.[ch]`: VM implementation
            * `vm_core.h`: definitions of VM data structure
            * `insns.def`: definitions of VM instructions
        * `compile.c, iseq.[ch]`: instruction sequence (bytecode)
        * `gc.c`: GC and memory management
        * `thread*.[ch]`: thread management
        * `variable.c`: variable management
        * `dln*.c`: dll management for extension libraries
        * `main.c`, `ruby.c`: the entry point of MRI
        * `st.c`: Hash algorithm implementation (see https://blog.heroku.com/ruby-2-4-features-hashes-integers-rounding)
    * Embedded classes
        * `string.c`: String class
        * `array.c`: Array class
        * ... (file names show class names, such as time.c for Time class)
* `ruby/*.h`: internal definitions. C-extension libraries can't use them.
* `ruby/include/ruby/*`: external definitions. C-extension libraries can use them.
* `ruby/enc/`: encoding information.
* `ruby/defs/`: various definitions.
* `ruby/tool/`: tools to build MRI.
* `ruby/missing/`: implementations for features that are missing in some OSes
* `ruby/cygwin/`, `ruby/nacl/`, `ruby/win32`, ...: OS/system dependent code.

### Libraries

There are two kinds of libraries.

* `ruby/lib/`: Standard libraries written in Ruby.
* `ruby/ext/`: Bundled extension libraries written in C.

### Tests

* `ruby/basictest/`: place of old test
* `ruby/bootstraptest/`: bootstrap test
* `ruby/test/`: tests written in test-unit notation
* `ruby/spec/`: tests written in RSpec notation

### misc

* `ruby/doc/`, `ruby/man/`: documentation

## Ruby's build process

Ruby build process is composed of several phases involving source code generation and so on. Several tools are written in Ruby, so the Ruby build process requires the Ruby interpreter. Release tarballs contain generated source code so that installing Ruby with a release tarball does not require the Ruby interpreter (and other development tools such as bison).

If you want to build MRI with source code fetched by Subversion or Git repository, you need a Ruby interpreter.

The following steps describe the build and install process:

1. Build miniruby
    1. parse.y -> parse.c: Compile syntax rules into C code with bison
    2. insns.def -> vm.inc: Compile VM instructions into C code with ruby (`BASERUBY`)
    3. `*.c` -> `*.o` (`*.obj` on Windows): Compile C code into object files.
    4. link object files into miniruby
2. Build encodings
    1. translate enc/... to appropriate C code with `miniruby`
    2. compile C code
3. Build C-extension libraries
    1. Make `Makefile` from `extconf.rb` with `mkmf.rb` and `miniruby`
    2. Run `make` using generated `Makefile`.
4. Build `ruby` command
5. Generate documentation (`rdoc`, `ri`)
6. Install MRI (to the install directory specified by the `configure --prefix` option)

There are actually many more steps in the process. It is difficult, however, to comprehensively list all the steps (even I don't know all of them!), so the above is an abbreviated sequence of steps. If you are curious, you can see all the rules in `common.mk` and related files.

## Exercise: the 1st hack. Change the version description

Let's start modifying MRI. We assume that all source code is placed at `workdir/ruby/`.

For your first exercise, let's modify the version description which is displayed with `ruby -v` (or  `./miniruby -v`) to display it as your own Ruby (for example, show a version description with your name included).

1. Open `version.c` in your editor.
2. Briefly skim over the entirety of `version.c`.
3. The function `ruby_show_version()` seems like what we're looking for
4. `fflush()` is a C function that flushes the output buffer, so we can guess that adding some printing code just before `fflush()` call could work.
5. Add the line `printf("...\n");` (Replace  `...` with a string of your choice)
6. `$ make miniruby` and build (don't forget to move to the build directory)
7. run `$ ./miniruby -v` and check the result.
8. `$ make install` and install build ruby.
9. run `$ ../install/bin/ruby -v` and check the result with the installed ruby.

Finally, instead of just inserting a `printf(...)` statement, try replacing the entire `ruby ...` description with something else (such as `perl ...` and so on) would be interesting ;p

