# Modify bugs

## About this document

Most of modification on MRI is bug fixes.
This document describe how to fix bugs with imaginary bug reports.

## `Kernel#hello(name)` (check bugs reported by others)

### `Kernel#hello(name)`: Implementation

Let's review how to add a method to MRI. Try to add `hello` method, a function like method.
Like `p` method, define `hello` in `Kernel` module and make it private.

This method prints "Hello #{name}\n".

You can see the definition in Ruby.

```ruby
def hello name
  puts "Hello #{name}"
end

hello 'ko1' #=> output "Hello ko1"
```

Let's rewrite it in C.
You can use `rb_define_global_function()` to define `Kernel#hello` as private method.

```diff
Index: io.c
===================================================================
--- io.c	(Revision 59647)
+++ io.c	(Working copy)
@@ -12327,6 +12327,14 @@
     }
 }
 
+static VALUE
+f_hello(VALUE self, VALUE name)
+{
+    const char *name_ptr = RSTRING_PTR(name);
+    fprintf(stdout, "Hello %s\n", name_ptr);
+    return Qnil;
+}
+
 /*
  * Document-class: IOError
  *
@@ -12530,6 +12538,8 @@
     rb_define_global_function("p", rb_f_p, -1);
     rb_define_method(rb_mKernel, "display", rb_obj_display, -1);
 
+    rb_define_global_function("hello", f_hello, 1);
+
     rb_cIO = rb_define_class("IO", rb_cObject);
     rb_include_module(rb_cIO, rb_mEnumerable);
 
```

The point is you can get a C string pointers from Ruby string objects by `RSTRING_PTR(name)`.

Write a sample code in `test.rb` and run `$ make run`. Could you check it? Maybe it works fine.

### Bug report

Let's consider that new Ruby (such as Ruby 2.6.0) is released with `hello()` method. Many Ruby users love `hello()` method and this method is used so much times. You got a reputation by writing this method. Congratulations!

But many users use it, issues are also reported.
Redmine ticket are filed.


```
My script causes SEGV.

See attached log for details.
```

Attached log shows the following:

```
../../trunk/test.rb:2: [BUG] Segmentation fault at 0x0000000000000008
ruby 2.5.0dev (2017-08-23 trunk 59647) [x86_64-linux]

-- Control frame information -----------------------------------------------
c:0003 p:---- s:0011 e:000010 CFUNC  :hello
c:0002 p:0007 s:0006 e:000005 EVAL   ../../trunk/test.rb:2 [FINISH]
c:0001 p:0000 s:0003 E:000b00 (none) [FINISH]

-- Ruby level backtrace information ----------------------------------------
../../trunk/test.rb:2:in `<main>'
../../trunk/test.rb:2:in `hello'

-- Machine register context ------------------------------------------------
 RIP: 0x00000000004c17f4 RBP: 0x0000000000df5430 RSP: 0x00007fff031d4680
 RAX: 0x0000000000000000 RBX: 0x00002ba4beccefb0 RCX: 0x00002ba4bebcf048
 RDX: 0x00000000004c17f0 RDI: 0x0000000000e562d0 RSI: 0x0000000000000008
  R8: 0x00002ba4bebcf068  R9: 0x00002ba4beccef80 R10: 0x0000000000000000
 R11: 0x0000000000000001 R12: 0x00002ba4beccefb0 R13: 0x0000000000e1d4f8
 R14: 0x0000000000ec78f0 R15: 0x0000000000e562d0 EFL: 0x0000000000010202

-- C level backtrace information -------------------------------------------
/mnt/sdb1/ruby/build/trunk/miniruby(rb_vm_bugreport+0x528) [0x61a088] ../../trunk/vm_dump.c:671
/mnt/sdb1/ruby/build/trunk/miniruby(rb_bug_context+0xd0) [0x4939c0] ../../trunk/error.c:539
/mnt/sdb1/ruby/build/trunk/miniruby(sigsegv+0x42) [0x58a622] ../../trunk/signal.c:932
/lib/x86_64-linux-gnu/libpthread.so.0 [0x2ba4bedc7330]
/mnt/sdb1/ruby/build/trunk/miniruby(f_hello+0x4) [0x4c17f4] ../../trunk/io.c:12332
/mnt/sdb1/ruby/build/trunk/miniruby(vm_call_cfunc+0x12d) [0x5fbe6d] ../../trunk/vm_insnhelper.c:1903
/mnt/sdb1/ruby/build/trunk/miniruby(vm_call_method+0xf7) [0x60d417] ../../trunk/vm_insnhelper.c:2364
/mnt/sdb1/ruby/build/trunk/miniruby(vm_exec_core+0x2051) [0x607a01] ../../trunk/insns.def:854
/mnt/sdb1/ruby/build/trunk/miniruby(vm_exec+0x98) [0x60b7f8] ../../trunk/vm.c:1793
/mnt/sdb1/ruby/build/trunk/miniruby(ruby_exec_internal+0xb2) [0x499a02] ../../trunk/eval.c:246
/mnt/sdb1/ruby/build/trunk/miniruby(ruby_exec_node+0x1d) [0x49b78d] ../../trunk/eval.c:310
/mnt/sdb1/ruby/build/trunk/miniruby(ruby_run_node+0x1c) [0x49dffc] ../../trunk/eval.c:302
/mnt/sdb1/ruby/build/trunk/miniruby(main+0x5f) [0x41a61f] ../../trunk/main.c:42

-- Other runtime information -----------------------------------------------

* Loaded script: ../../trunk/test.rb

* Loaded features:

    0 enumerator.so
    1 thread.rb
    2 rational.so
    3 complex.so

* Process memory map:

00400000-006f7000 r-xp 00000000 08:11 262436                             /mnt/sdb1/ruby/build/trunk/miniruby
008f6000-008fb000 r--p 002f6000 08:11 262436                             /mnt/sdb1/ruby/build/trunk/miniruby
008fb000-008fc000 rw-p 002fb000 08:11 262436                             /mnt/sdb1/ruby/build/trunk/miniruby
008fc000-0090e000 rw-p 00000000 00:00 0
00df4000-00f2c000 rw-p 00000000 00:00 0                                  [heap]
2ba4beb92000-2ba4bebb5000 r-xp 00000000 08:01 310550                     /lib/x86_64-linux-gnu/ld-2.19.so
2ba4bebb5000-2ba4bebb7000 rw-p 00000000 00:00 0
2ba4bebb7000-2ba4bebb8000 ---p 00000000 00:00 0
2ba4bebb8000-2ba4bebbb000 rw-p 00000000 00:00 0                          [stack:13848]
2ba4bebbb000-2ba4bebc2000 r--s 00000000 08:01 216019                     /usr/lib/x86_64-linux-gnu/gconv/gconv-modules.cache
2ba4bebc2000-2ba4bebc3000 rw-p 00000000 00:00 0
2ba4bebcb000-2ba4becd0000 rw-p 00000000 00:00 0
2ba4becd0000-2ba4becf3000 r--s 00000000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4becf3000-2ba4bed9a000 r--s 00000000 08:01 6641                       /usr/lib/debug/lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4bedb4000-2ba4bedb5000 r--p 00022000 08:01 310550                     /lib/x86_64-linux-gnu/ld-2.19.so
2ba4bedb5000-2ba4bedb6000 rw-p 00023000 08:01 310550                     /lib/x86_64-linux-gnu/ld-2.19.so
2ba4bedb6000-2ba4bedb7000 rw-p 00000000 00:00 0
2ba4bedb7000-2ba4bedd0000 r-xp 00000000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4bedd0000-2ba4befcf000 ---p 00019000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4befcf000-2ba4befd0000 r--p 00018000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4befd0000-2ba4befd1000 rw-p 00019000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4befd1000-2ba4befd5000 rw-p 00000000 00:00 0
2ba4befd5000-2ba4befd8000 r-xp 00000000 08:01 309835                     /lib/x86_64-linux-gnu/libdl-2.19.so
2ba4befd8000-2ba4bf1d7000 ---p 00003000 08:01 309835                     /lib/x86_64-linux-gnu/libdl-2.19.so
2ba4bf1d7000-2ba4bf1d8000 r--p 00002000 08:01 309835                     /lib/x86_64-linux-gnu/libdl-2.19.so
2ba4bf1d8000-2ba4bf1d9000 rw-p 00003000 08:01 309835                     /lib/x86_64-linux-gnu/libdl-2.19.so
2ba4bf1d9000-2ba4bf1e2000 r-xp 00000000 08:01 309837                     /lib/x86_64-linux-gnu/libcrypt-2.19.so
2ba4bf1e2000-2ba4bf3e2000 ---p 00009000 08:01 309837                     /lib/x86_64-linux-gnu/libcrypt-2.19.so
2ba4bf3e2000-2ba4bf3e3000 r--p 00009000 08:01 309837                     /lib/x86_64-linux-gnu/libcrypt-2.19.so
2ba4bf3e3000-2ba4bf3e4000 rw-p 0000a000 08:01 309837                     /lib/x86_64-linux-gnu/libcrypt-2.19.so
2ba4bf3e4000-2ba4bf412000 rw-p 00000000 00:00 0
2ba4bf412000-2ba4bf517000 r-xp 00000000 08:01 309816                     /lib/x86_64-linux-gnu/libm-2.19.so
2ba4bf517000-2ba4bf716000 ---p 00105000 08:01 309816                     /lib/x86_64-linux-gnu/libm-2.19.so
2ba4bf716000-2ba4bf717000 r--p 00104000 08:01 309816                     /lib/x86_64-linux-gnu/libm-2.19.so
2ba4bf717000-2ba4bf718000 rw-p 00105000 08:01 309816                     /lib/x86_64-linux-gnu/libm-2.19.so
2ba4bf718000-2ba4bf8d6000 r-xp 00000000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
2ba4bf8d6000-2ba4bfad6000 ---p 001be000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
2ba4bfad6000-2ba4bfada000 r--p 001be000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
2ba4bfada000-2ba4bfadc000 rw-p 001c2000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
2ba4bfadc000-2ba4bfae1000 rw-p 00000000 00:00 0
2ba4bfae1000-2ba4bfdaa000 r--p 00000000 08:01 376                        /usr/lib/locale/locale-archive
2ba4bfdaa000-2ba4bfdc0000 r-xp 00000000 08:01 266058                     /lib/x86_64-linux-gnu/libgcc_s.so.1
2ba4bfdc0000-2ba4bffbf000 ---p 00016000 08:01 266058                     /lib/x86_64-linux-gnu/libgcc_s.so.1
2ba4bffbf000-2ba4bffc0000 rw-p 00015000 08:01 266058                     /lib/x86_64-linux-gnu/libgcc_s.so.1
2ba4bffc0000-2ba4c0f1c000 r--s 00000000 08:11 262436                     /mnt/sdb1/ruby/build/trunk/miniruby
2ba4c0f1c000-2ba4c10e2000 r--s 00000000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
7fff031b5000-7fff031d6000 rw-p 00000000 00:00 0
7fff031e5000-7fff031e7000 r-xp 00000000 00:00 0                          [vdso]
ffffffffff600000-ffffffffff601000 r-xp 00000000 00:00 0                  [vsyscall]


[NOTE]
You may have encountered a bug in the Ruby interpreter or extension libraries.
Bug reports are welcome.
For details: http://www.ruby-lang.org/bugreport.html

make: *** [run] Aborted (core dumped)
```

This bug report lacks the following points:

* Reproducible code
* Execution environment

But you can see `ruby 2.5.0dev (2017-08-23 trunk 59647) [x86_64-linux]` in attached log file so that you can understand this script cause SEGV bug on Linux environment and using Ruby 2.5.0dev (development version of MRI).

Reproducible code is very important so you ask the repro-code.

(In fact, this attached log files contain enough information to solve, but assume we can't understand)

```
Please send us your reproducible code. Small code is awesome.
```

It is difficult to make reproducible code and send it when we got an error with production rails application, for example.
Also it is difficult to find out non-deterministic bugs (errors in sometimes, somewheres).

Let's assume that this error is in big production application, and reporter said "Sorry we can't make such repro".

It's a time to start debugging with a log file.

### How to see `[BUG]` log file?

`[BUG]` is displayed when MRI has critical errors. Basically, it should be MRI's bug.

```
../../trunk/test.rb:2: [BUG] Segmentation fault at 0x0000000000000008
```

At the beginning of the log, this line says that there is a critical error at `../../trunk/test.rb:2` line.
Second, `Segmentation fault at 0x0000000000000008` shows the reason of `[BUG]`. In this case, Segmentation fault occurs by reading or writing at address 0x0000000000000008.
Generally, it should be a bug caused by reading or writing at reading/writing prohibitted memory area. You can see this error with bug containing C programs.

Next line `ruby 2.5.0dev (2017-08-23 trunk 59647) [x86_64-linux]` shows the version description which we can see with `ruby -v`.

```
-- Control frame information -----------------------------------------------
c:0003 p:---- s:0011 e:000010 CFUNC  :hello
c:0002 p:0007 s:0006 e:000005 EVAL   ../../trunk/test.rb:2 [FINISH]
c:0001 p:0000 s:0003 E:000b00 (none) [FINISH]
```

This block shows "Control frame information", Ruby VM's frame information.
These lines are strongly connected with VM implementation.
Each lines contain the following information:

* `c`: Frame number (cf index)
* `p`: Program counter
* `s`: Stack pointer (depth)
* `e`: Environment pointer (ep) which points an area of local variables.
* Frame type. `EVAL` means a frame pushed by `eval`. `CFUNC` means a frame pushed by C implemented method.
* Frame location. File path and line number for Ruby level frame. Method name for CFUNC.

"Frame location" is similar to backtrace information.

```
-- Ruby level backtrace information ----------------------------------------
../../trunk/test.rb:2:in `<main>'
../../trunk/test.rb:2:in `hello'
```

This block shows "Ruby level backtrace information", Normal Ruby level backtrace information.

```
-- Machine register context ------------------------------------------------
 RIP: 0x00000000004c17f4 RBP: 0x0000000000df5430 RSP: 0x00007fff031d4680
 RAX: 0x0000000000000000 RBX: 0x00002ba4beccefb0 RCX: 0x00002ba4bebcf048
 RDX: 0x00000000004c17f0 RDI: 0x0000000000e562d0 RSI: 0x0000000000000008
  R8: 0x00002ba4bebcf068  R9: 0x00002ba4beccef80 R10: 0x0000000000000000
 R11: 0x0000000000000001 R12: 0x00002ba4beccefb0 R13: 0x0000000000e1d4f8
 R14: 0x0000000000ec78f0 R15: 0x0000000000e562d0 EFL: 0x0000000000010202
```

This block shows "Machine register context", CPU register information.
This block is depends on running information.

```
-- C level backtrace information -------------------------------------------
/mnt/sdb1/ruby/build/trunk/miniruby(rb_vm_bugreport+0x528) [0x61a088] ../../trunk/vm_dump.c:671
/mnt/sdb1/ruby/build/trunk/miniruby(rb_bug_context+0xd0) [0x4939c0] ../../trunk/error.c:539
/mnt/sdb1/ruby/build/trunk/miniruby(sigsegv+0x42) [0x58a622] ../../trunk/signal.c:932
/lib/x86_64-linux-gnu/libpthread.so.0 [0x2ba4bedc7330]
/mnt/sdb1/ruby/build/trunk/miniruby(f_hello+0x4) [0x4c17f4] ../../trunk/io.c:12332
/mnt/sdb1/ruby/build/trunk/miniruby(vm_call_cfunc+0x12d) [0x5fbe6d] ../../trunk/vm_insnhelper.c:1903
/mnt/sdb1/ruby/build/trunk/miniruby(vm_call_method+0xf7) [0x60d417] ../../trunk/vm_insnhelper.c:2364
/mnt/sdb1/ruby/build/trunk/miniruby(vm_exec_core+0x2051) [0x607a01] ../../trunk/insns.def:854
/mnt/sdb1/ruby/build/trunk/miniruby(vm_exec+0x98) [0x60b7f8] ../../trunk/vm.c:1793
/mnt/sdb1/ruby/build/trunk/miniruby(ruby_exec_internal+0xb2) [0x499a02] ../../trunk/eval.c:246
/mnt/sdb1/ruby/build/trunk/miniruby(ruby_exec_node+0x1d) [0x49b78d] ../../trunk/eval.c:310
/mnt/sdb1/ruby/build/trunk/miniruby(ruby_run_node+0x1c) [0x49dffc] ../../trunk/eval.c:302
/mnt/sdb1/ruby/build/trunk/miniruby(main+0x5f) [0x41a61f] ../../trunk/main.c:42
```

This block shows C-level backtrace. Some OSs support it and others doesn't support it.

```
* Loaded script: ../../trunk/test.rb
```

This line shows which file is specified for ruby command.

```
* Loaded features:

    0 enumerator.so
    1 thread.rb
    2 rational.so
    3 complex.so
```

These lines shows which files are loaded by `require` (== `$LOADED_FEATURES`).
In this case we only see 4 lines, but Ruby on Rails applications or bigger applications contain tons of files.

```
* Process memory map:

00400000-006f7000 r-xp 00000000 08:11 262436                             /mnt/sdb1/ruby/build/trunk/miniruby
008f6000-008fb000 r--p 002f6000 08:11 262436                             /mnt/sdb1/ruby/build/trunk/miniruby
008fb000-008fc000 rw-p 002fb000 08:11 262436                             /mnt/sdb1/ruby/build/trunk/miniruby
008fc000-0090e000 rw-p 00000000 00:00 0
00df4000-00f2c000 rw-p 00000000 00:00 0                                  [heap]
2ba4beb92000-2ba4bebb5000 r-xp 00000000 08:01 310550                     /lib/x86_64-linux-gnu/ld-2.19.so
2ba4bebb5000-2ba4bebb7000 rw-p 00000000 00:00 0
2ba4bebb7000-2ba4bebb8000 ---p 00000000 00:00 0
2ba4bebb8000-2ba4bebbb000 rw-p 00000000 00:00 0                          [stack:13848]
2ba4bebbb000-2ba4bebc2000 r--s 00000000 08:01 216019                     /usr/lib/x86_64-linux-gnu/gconv/gconv-modules.cache
2ba4bebc2000-2ba4bebc3000 rw-p 00000000 00:00 0
2ba4bebcb000-2ba4becd0000 rw-p 00000000 00:00 0
2ba4becd0000-2ba4becf3000 r--s 00000000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4becf3000-2ba4bed9a000 r--s 00000000 08:01 6641                       /usr/lib/debug/lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4bedb4000-2ba4bedb5000 r--p 00022000 08:01 310550                     /lib/x86_64-linux-gnu/ld-2.19.so
2ba4bedb5000-2ba4bedb6000 rw-p 00023000 08:01 310550                     /lib/x86_64-linux-gnu/ld-2.19.so
2ba4bedb6000-2ba4bedb7000 rw-p 00000000 00:00 0
2ba4bedb7000-2ba4bedd0000 r-xp 00000000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4bedd0000-2ba4befcf000 ---p 00019000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4befcf000-2ba4befd0000 r--p 00018000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4befd0000-2ba4befd1000 rw-p 00019000 08:01 309830                     /lib/x86_64-linux-gnu/libpthread-2.19.so
2ba4befd1000-2ba4befd5000 rw-p 00000000 00:00 0
2ba4befd5000-2ba4befd8000 r-xp 00000000 08:01 309835                     /lib/x86_64-linux-gnu/libdl-2.19.so
2ba4befd8000-2ba4bf1d7000 ---p 00003000 08:01 309835                     /lib/x86_64-linux-gnu/libdl-2.19.so
2ba4bf1d7000-2ba4bf1d8000 r--p 00002000 08:01 309835                     /lib/x86_64-linux-gnu/libdl-2.19.so
2ba4bf1d8000-2ba4bf1d9000 rw-p 00003000 08:01 309835                     /lib/x86_64-linux-gnu/libdl-2.19.so
2ba4bf1d9000-2ba4bf1e2000 r-xp 00000000 08:01 309837                     /lib/x86_64-linux-gnu/libcrypt-2.19.so
2ba4bf1e2000-2ba4bf3e2000 ---p 00009000 08:01 309837                     /lib/x86_64-linux-gnu/libcrypt-2.19.so
2ba4bf3e2000-2ba4bf3e3000 r--p 00009000 08:01 309837                     /lib/x86_64-linux-gnu/libcrypt-2.19.so
2ba4bf3e3000-2ba4bf3e4000 rw-p 0000a000 08:01 309837                     /lib/x86_64-linux-gnu/libcrypt-2.19.so
2ba4bf3e4000-2ba4bf412000 rw-p 00000000 00:00 0
2ba4bf412000-2ba4bf517000 r-xp 00000000 08:01 309816                     /lib/x86_64-linux-gnu/libm-2.19.so
2ba4bf517000-2ba4bf716000 ---p 00105000 08:01 309816                     /lib/x86_64-linux-gnu/libm-2.19.so
2ba4bf716000-2ba4bf717000 r--p 00104000 08:01 309816                     /lib/x86_64-linux-gnu/libm-2.19.so
2ba4bf717000-2ba4bf718000 rw-p 00105000 08:01 309816                     /lib/x86_64-linux-gnu/libm-2.19.so
2ba4bf718000-2ba4bf8d6000 r-xp 00000000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
2ba4bf8d6000-2ba4bfad6000 ---p 001be000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
2ba4bfad6000-2ba4bfada000 r--p 001be000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
2ba4bfada000-2ba4bfadc000 rw-p 001c2000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
2ba4bfadc000-2ba4bfae1000 rw-p 00000000 00:00 0
2ba4bfae1000-2ba4bfdaa000 r--p 00000000 08:01 376                        /usr/lib/locale/locale-archive
2ba4bfdaa000-2ba4bfdc0000 r-xp 00000000 08:01 266058                     /lib/x86_64-linux-gnu/libgcc_s.so.1
2ba4bfdc0000-2ba4bffbf000 ---p 00016000 08:01 266058                     /lib/x86_64-linux-gnu/libgcc_s.so.1
2ba4bffbf000-2ba4bffc0000 rw-p 00015000 08:01 266058                     /lib/x86_64-linux-gnu/libgcc_s.so.1
2ba4bffc0000-2ba4c0f1c000 r--s 00000000 08:11 262436                     /mnt/sdb1/ruby/build/trunk/miniruby
2ba4c0f1c000-2ba4c10e2000 r--s 00000000 08:01 309818                     /lib/x86_64-linux-gnu/libc-2.19.so
7fff031b5000-7fff031d6000 rw-p 00000000 00:00 0
7fff031e5000-7fff031e7000 r-xp 00000000 00:00 0                          [vdso]
ffffffffff600000-ffffffffff601000 r-xp 00000000 00:00 0                  [vsyscall]
```

Maybe this block only on Linux. OS managed process memory map. Same as `/proc/self/maps`.

----

At first, we need to see backtrace information.
"Control frame information" shows that error is at `hello` method.

Check the `hello` implementation again.

NOTE: It is easy bug which we can find out on backtrace. Difficult bug doesn't appear on backtrace information. For example, break data by a bug and expose a problem when we read its data. This case, we can't find which line break the data.

### Revisit `f_hello()`

The body of `hello` method is a C function.

```
static VALUE
f_hello(VALUE self, VALUE name)
{
    const char *name_ptr = RSTRING_PTR(name);
    fprintf(stdout, "Hello %s\n", name_ptr);
    return Qnil;
}
```

Let's gaze this code. We use `RSTRING_PTR()` for a parameter `name`.
The macro `RSTRING_PTR()` is valid only for String objects (`T_STRING` typed objects) and MRI doesn't guarantee other type of objects. Maybe it will cause a critical bug.
Okay. We may find out the issue.

To verify the hypothesis, try `hello(nil)`. We will have similar `[BUG]` outputs.
Let's add this repro-code to the ticket.

```
The following code can reproduce this issue:

  hello(nil)
```

Such small repro-code helps other people. You can ask someone to fix the issue.
In this case, however, let's make a patch for this issue.

### Debugging with gdb

Write a line `hello(nil)` in `test.rb` and run `make gdb`.

(if you want to use lldb, you need to run `make lldb` and execute `run` lldb command)

```
Program received signal SIGSEGV, Segmentation fault.
f_hello (self=9904840, name=8) at ../../trunk/io.c:12333
12333       const char *name_ptr = RSTRING_PTR(name);
```

If you get this message and gdb stops the program, your debugging successes.
It means debuggee program (a ruby interpreter) receives `SEGV` signal and gdb stops debuggee program.

Let's check the contents in `name`.

```
(gdb) p name
$1 = 8
(gdb) rp name
nil
```

`p name` shows the value of `name` (numeric value): 8. But `8` is difficult to understand.
`rp name` shows that the value 8 means `nil` in Ruby world.

Stopping place by SEGV is `io.c:12333` and the line is `const char *name_ptr = RSTRING_PTR(name);`.
The hypothesis "`RSTRING_PTR()` is an issue" seems correct.

To soleve this problem, we need to check `name` is a `String` instance.
What should happen on type error? We can raise a type mismatch error.
But Ruby has a convention that if an object responds to `to_str`, then we call `to_str` and get converting String object. We want to support this feature.
But (continue...) if a result of `to_str` is not a String instance? It is okay to raise an exception.

For convinience, MRI has a macro `StringValueCStr()` to do everything we want to do.
When you want to get a C string buffer pointer, use `StringValueCStr()`.
This macro calls `to_str` if needed and return a C string pointer.
If there is a problem, then raise an error.

Let's use this macro.

```
  const char *name_ptr = StringValueCStr(name);
```

And run `$ make gdb` again.

```
ko1@u64:~/ruby/build/trunk$ make gdb
compiling ../../trunk/io.c
linking miniruby
gdb -x run.gdb --quiet --args ./miniruby -I../../trunk/lib -I. -I.ext/common  ../../trunk/test.rb
Reading symbols from ./miniruby...done.
Breakpoint 1 at 0x474900: file ../../trunk/debug.c, line 127.
warning: ../../trunk/breakpoints.gdb: No such file or directory
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
[New Thread 0x2aaaaaad5700 (LWP 17714)]
Traceback (most recent call last):
        1: from ../../trunk/test.rb:2:in `<main>'
../../trunk/test.rb:2:in `hello': no implicit conversion of nil into String (TypeError)
[Thread 0x2aaaaaad5700 (LWP 17714) exited]
[Inferior 1 (process 17710) exited with code 01]
```

At first, compiling modified `io.c` again and generate fixed `miniruby`.
Next, run `test.rb` on gdb.

The execution results shows that `TypeError` is raised because there are no `nil.to_str`.
Exception is raised on Ruby level, and no SEGV. OK. gdb is terminated automatically.

We can fix the problem, so report the modification for the `f_hello()` function.
The are several way to report the modification.

* Add a comment on Redmine.
* Make a pull request on GitHub and comment this URL on redmine ticket.

### Ticket: after reporting

#### If we are ignored...

Even if we propose a patch, a bug is not fixed until a ruby committer commits it.
Most of case, fast worker (nobu and others) committers commits bug fixes.
But it is possible to postpone accepting the patch.

* Low priority: if committers think "nobody use `hello()` method", it can be thought as troublesome and postponed.
* Busy: nobody has duty to keep quality assurance, so if people are busy, it can be postponed.
* Modification is not mature: another committer should fix the patch. If the committer who has a charge is busy, it can be postponed.
* Unable to reproduce the problem: if there is no repro-code or repro-code doesn't work well, it can be postponed.

If you can't see the situation, let's urge on a ticket. If you know a Ruby committer, you can ask the person.
Many committers have their own SNS accounts (for example, Matz's twitter account is https://twitter.com/yukihiro_matz), you can ask to such accounts.

You can ask at Ruby developers meeting (monthly). Visit https://bugs.ruby-lang.org/projects/ruby/wiki/ and check the DevelopersMeeting20170831Japan (or similar pages). You can add your ticket to an agenda page.

#### Backport

When latet development version (such as ruby 2.6.0dev) accepts the patch, we also want to apply the fix to older stable version such as Ruby 2.5 or Ruby 2.4.

If you want to backport the issues, ask backporting at the ticket comment.

Stable version branch maintainers manage ticket's "Backport" field. Tickets will be closed when dev version accepts the fix. Branch maintainers checks closed tickets and find out backport fixes, so please remain the status of ticket as "Close". If there are no problems, then the fixes are merged at next release timing.

## `Integer#add(n)` (when you find a bug)

Previous chapter, we implemented `Integer#add(n)` method and I wrote that there is a problem on that implementaiton.
Let's assume we release a new Ruby version with this prbolem (in fact, there are such accidents frequently).

You think `Integer#add` is cooler than `Integer#+` and use it many times. And you got an unexpected exception.

```
a = 3_000_000_000
b = 2_000_000_000
p a+b #=> 5000000000
p a.add(b) #=> `add': integer 3000000000 too big to convert to `int' (RangeError)
```

### Bug report

You already know:

* What behavior you expect (it should same as `Integer#+`)
* What happens (we got `RangeError`)
* Repro-code (4 lines)

So it is enough to report a bug. Let's make a bug report ticket.

Before submitting your bug report, check same report. You can use redmine search, with the words `Integer#+` or `RangeError` for example.

After checking the duplication, we can't find any similar report. This is a time to create a ticket!

1. https://bugs.ruby-lang.org/projects/ruby-trunk/issues is a page to create a ticket. If you don't have an account on redmine, register first and login with new account.
2. Click "New ticket" button.
3. Choose "Tracker" as a "Bug".
4. "Subject" should be clear. Use "Integer#add causes RangeError unexpectedly".
5. "Description" should be also clear (say later).
6. You don't need to touch "Status", "Assignee", "Target version" and "Priority".
7. You should write a result of `ruby -v` into "ruby -v" field.
8. "Preferred language" should be "ruby-core in English" if you want to use English.
9. We don't have any attached file this time because there are no big log output.

"Description" should contain:

* Summary
* Repro-code and your environment (a result of `ruby -v`, OS, compier's version and so on)
* Expected behavior
* Actual behavior
* (if possible) a patch to solve this problem

Let's use the following template.

~~~markdown
# Summary

`Integer#+` raises unexpected exception.

# Repro-code and your environment (a result of `ruby -v`, OS, compier's version and so on)

We can reproduce the problem.

```
a = 3_000_000_000
b = 2_000_000_000
p a+b #=> 5000000000
p a.add(b) #=> `add': integer 3000000000 too big to convert to `int' (RangeError)
```

I run under this environment:

```
$ uname -a
Linux u64 3.13.0-126-generic #175-Ubuntu SMP Thu Jul 20 17:33:56 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux
```

# Expected behavior

Same as `Integer#+`.  The above example should be `p a+b #=> 5000000000`.

# Actual behavior

I got RangeError:
`p a.add(b) #=> `add': integer 3000000000 too big to convert to `int' (RangeError)`
~~~

Completed. Push "Create" button and make a ticket.

### Narrow the problematic values

After making a ticket, nobody responds to this ticket. Nobody use it...?
So let's debug by ourselves.

To find out the bug, we need to check which value causes an error.
It seems that 2 billion (2B) is no problem and 3 billion (3B) cause error.

So check all values from 2B to 3B.

```
def trial low, high
  result = false
  while result == false && low != high
    break if yield low
    low += 1
  end
  low
end

point_value = trial 2_000_000_000, 3_000_000_000 do |n|
  # p n
  begin
    a = n
    b = 2_000_000_000
    a.add(b)
  rescue RangeError
    true
  else
    false
  end
end

p point_value
```

`trial` method tries with a values from `low` to `high` and checks the return value. It find out the timing where return value is changed from false -> true.
Make a block which returns false if `Integer#add()` does not raise an exception and returns true if `Integer#add()` cause exception.
Let's call `trial` method with this block and check the boundary.

Running this program, we can find that 2,147,483,648 is boundary (false -> true).

BTW, we need 13 seconds to find out it. Repeating 147,483,648 times (=> 13sec / 147... = 8.8e-08 sec = 90ns / iteration).
On this case, we can find near by 2B. If the boundary is near to 3B, this check script consumes huge time.

So use "binary search" in `trial` method.

```
def linear_trial low, high
  result = false
  while result == false && low != high
    break if yield low
    low += 1
  end
  low
end

def trial low, high, &b
  # binary search
  while high - low > 2
    mid = (low + high)/2
    result = yield mid
    if result
      high = mid
    else
      low = mid
    end
  end
  linear_trial mid-2, mid+1, &b # to make impl simple.
end
```

Using binary search version, we can find 2,147,483,648 with 0.20 seconds. Calcuration order reduced from O(n) to O(log n).

After all, we can find 2,147,483,647 is okay and 2,147,483,648 is not okay (error). Report it.

```
With my observation,

* There is no exception if a is 2_147_483_647 or smaller
* There is exception if a is 2_147_483_648 or bigger
```

A Ruby committer see the this report and the person can understand the problem immediately. The person fixed the issue. Congratulation!

### Answer checking

Some of you can understand with the number 2,147,483,648, it is equal to 2^31. There is no problem if a < 2^31.

Original error message was `integer 3000000000 too big to convert to `int' (RangeError)`.
Converting fails because the value exceeds the maximum number of C's integer value.
On this environment, the range of C's integer value is -2^31 ～ 2^31-1, so the value 2^31 exceeds the range.

Let's check original implementation.

```
static VALUE
int_add(VALUE self, VALUE n)
{
    if (FIXNUM_P(self) && FIXNUM_P(n)) {
	/* c = a + b */
	int a = FIX2INT(self);
	int b = FIX2INT(n);
	int c = a + b;
	VALUE result = INT2NUM(c);
	return result;
    }
    else {
	return rb_int_plus(self, n);
    }
}
```

We can see `FIX2INT()`. An error is raised with this conversion macro. Let use `long` instead.

```
static VALUE
int_add(VALUE self, VALUE n)
{
    if (FIXNUM_P(self) && FIXNUM_P(n)) {
	/* c = a + b */
	long a = FIX2LONG(self);
	long b = FIX2LONG(n);
	long c = a + b;
	VALUE result = LONG2NUM(c);
	return result;
    }
    else {
	return rb_int_plus(self, n);
    }
}
```

And we can fix this problem. Yay.

Ruby can represent huge numbers if memory is available. However, C or other languages have a limitation for integer representation.
It is important that we need to recognize such limitation (it is not only for Ruby).

## Debugging tips

If you have a problem with huge application, what should we do?

Reduce the code. (If it is acceptable) delete the lines of an application.
You should use version management system (git and so on) so it is easy to restore.

There are non-deterministic bugs related to GC bugs, threading bugs, VM bugs and so on (Koichi got such errors frequently).

MRI has many assertions to check assumptions. Usually we disable such assertion checking because of performance. But you can use it to debug.
Set `RGENGC_CHECK_MODE` in `gc.c` to 2, set `VM_CHECK_MODE` in `vm_core.h` to 1 will enable this feature.
If you want to pass these options to c compiler, pass `-DRGENGC_CHECK_MODE=2 -DVM_CHECK_MODE=1` options as cflags (and you need to run `make clean` before this trial).
