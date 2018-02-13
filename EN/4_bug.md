# (4) Fixing bugs

## About this document

Most of the modifications made to MRI are bug fixes.
This document describes how to fix bugs with a few imaginary bug reports.

## `Kernel#hello(name)` (Scenario: review bugs reported by others)

### `Kernel#hello(name)`: Implementation

Let's review the procedure for adding a method to MRI. Try to add the `hello` method, a function-like method. Like the `p` method, define `hello` on the `Kernel` module and make it private.

This method prints the string "Hello #{name}\n".

The following is a sample implementation in Ruby.

```ruby
def hello name
  puts "Hello #{name}"
end

hello 'ko1' #=> output "Hello ko1"
```

Let's rewrite it in C and embed it into MRI.
You can use `rb_define_global_function()` to define `Kernel#hello` as a private method.

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

Note that `RSTRING_PTR(name)` allows us to get a C string pointer from a Ruby string object.

Write some code to call `hello` in `test.rb`, and then run `$ make run`. Did it work? It should work fine.

### Bug report

Let's consider that a new Ruby (such as Ruby 2.6.0) is released including the `hello()` method. The `hello()` method is popular, and many Ruby users use this `hello()` method in their applications. You built a reputation by writing this method. Congratulations!

As with anything that has many users, inevitably, bugs are discovered. One day, the following bug report is filed as a ticket on Redmine.


```
My script causes SEGV.

See attached log for details.
```

The attached log shows the following:

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

This bug report lacks the following important pieces of information:

* Code for reproducing the problem
* Details of the execution environment

But you notice the line `ruby 2.5.0dev (2017-08-23 trunk 59647) [x86_64-linux]` in the attached log file, so you guess that the report is for a SEGV bug on a Linux environment and using Ruby 2.5.0dev (the development version of MRI).

It is very important to be able to reproduce the bug, so you decide to ask for code to reproduce the bug.

(Actually, this time, the attached log files contain enough information to solve the problem, but let's assume that we don't have enough information)

```
Please send us your reproducible code. A small code sample would be awesome!
```

It can be difficult to make a reproducible code sample if, say, the problem was discovered in a large production Rails application, or in the case of non-deterministic bugs (where errors only occur occasionally).

Let's assume that this error is in big production application, and the reporter replies that "Sorry we can't make such repro".

It's time to start debugging with a log file.

### How to read `[BUG]` log files

`[BUG]` is displayed when MRI encounters critical errors. Generally, these are interpreter bugs.

```
../../trunk/test.rb:2: [BUG] Segmentation fault at 0x0000000000000008
```

The first line of the log (shown above) indicates that a critical error has occurred at `../../trunk/test.rb:2`.
Next, `Segmentation fault at 0x0000000000000008` indicates the cause of the `[BUG]` message. In this case, a segmentation fault occurred when reading or writing at the address `0x0000000000000008`.
Generally, such bugs are caused by reading from or writing to a restricted area of memory. This is a category of bugs that is quite common in C programs, and is often shortened to "segfault".

The next line, `ruby 2.5.0dev (2017-08-23 trunk 59647) [x86_64-linux]`, shows the version description which we can see with `ruby -v`.

```
-- Control frame information -----------------------------------------------
c:0003 p:---- s:0011 e:000010 CFUNC  :hello
c:0002 p:0007 s:0006 e:000005 EVAL   ../../trunk/test.rb:2 [FINISH]
c:0001 p:0000 s:0003 E:000b00 (none) [FINISH]
```

This block shows "Control frame information", the Ruby VM's frame information.
These lines are strongly connected with the VM implementation, and are rarely used unless debugging the VM.
Each line contains the following information:

* `c`: Frame number (cf index)
* `p`: Program counter
* `s`: Stack pointer (depth)
* `e`: Environment pointer (ep) which points at an area of local variables.
* Frame type. `EVAL` means a frame pushed by `eval`. `CFUNC` means a frame pushed by a method that is implemented in C.
* Frame location. File path and line number for Ruby level frame. Method name for CFUNC.

"Frame location" is similar to backtrace information.

```
-- Ruby level backtrace information ----------------------------------------
../../trunk/test.rb:2:in `<main>'
../../trunk/test.rb:2:in `hello'
```

This block shows "Ruby level backtrace information", i.e. normal Ruby-level backtrace information.

```
-- Machine register context ------------------------------------------------
 RIP: 0x00000000004c17f4 RBP: 0x0000000000df5430 RSP: 0x00007fff031d4680
 RAX: 0x0000000000000000 RBX: 0x00002ba4beccefb0 RCX: 0x00002ba4bebcf048
 RDX: 0x00000000004c17f0 RDI: 0x0000000000e562d0 RSI: 0x0000000000000008
  R8: 0x00002ba4bebcf068  R9: 0x00002ba4beccef80 R10: 0x0000000000000000
 R11: 0x0000000000000001 R12: 0x00002ba4beccefb0 R13: 0x0000000000e1d4f8
 R14: 0x0000000000ec78f0 R15: 0x0000000000e562d0 EFL: 0x0000000000010202
```

This block shows "Machine register context", i.e. CPU register information.
This block depends on the execution environment.

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

This block shows the C-level backtrace. Depending on the OS, this may or may not be available, or may display a message stating that it can be found in a separate file.

```
* Loaded script: ../../trunk/test.rb
```

This line shows the files given to the `ruby` command.

```
* Loaded features:

    0 enumerator.so
    1 thread.rb
    2 rational.so
    3 complex.so
```

These lines shows which files were loaded by `require` (== `$LOADED_FEATURES`).
In this case we only see 4 lines, but in larger applications (e.g. Ruby on Rails applications) that use may gems, there may be thousands of entries.

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

The above block is probably available only on Linux. It is a memory map of OS-managed processes, i.e. the same as `/proc/self/maps`.

----

When debugging, the first thing to look at is the backtrace information.
According to the "Control frame information", we can see that an error occurred at the `hello` method.

Let's review the `hello` implementation again.

NOTE: Bugs where the cause can be identified in the backtrace are relatively easy. In difficult bugs, the backtrace information may not be sufficient. For example, a bug could corrupt data, and then result in a `[BUG]` when the data is read. In such a case, the logs won't indicate the correct cause of the bug.

### Revisiting `f_hello()`

The body of the `hello` method is a C function.

```
static VALUE
f_hello(VALUE self, VALUE name)
{
    const char *name_ptr = RSTRING_PTR(name);
    fprintf(stdout, "Hello %s\n", name_ptr);
    return Qnil;
}
```

Let's take a closer look at this code. We used `RSTRING_PTR()` on the parameter `name`.
The macro `RSTRING_PTR()` is valid only for String objects (`T_STRING` typed objects) and MRI doesn't guarantee behavior for other type of objects. This is a likely culprit for our critical bug.
Okay. Perhaps we can figure out this issue.

To verify the hypothesis, we can try `hello(nil)`. This should result in similar `[BUG]` output.
Let's add the repro-code to the ticket.

```
The following code can reproduce this issue:

  hello(nil)
```

Such a small repro-code helps other people. You could ask someone else to fix the issue.
In this case, however, let's make a patch for this issue.

### Debugging with gdb

Add the line `hello(nil)` to `test.rb` and run `make gdb`.

(If you want to use lldb, you need to run `make lldb` and execute the `run` lldb command.)

```
Program received signal SIGSEGV, Segmentation fault.
f_hello (self=9904840, name=8) at ../../trunk/io.c:12333
12333       const char *name_ptr = RSTRING_PTR(name);
```

If you get this message and gdb stops the program, your debugging is successful.
It means debuggee program (a ruby interpreter) receives the `SEGV` signal and gdb stops the debuggee program.

Let's check the contents of `name`.

```
(gdb) p name
$1 = 8
(gdb) rp name
nil
```

`p name` shows the value of `name` (a numeric value): 8. But the value `8` might be unfamiliar.
`rp name` shows that the value `8` means `nil` in the Ruby world.

The location where SEGV stopped execution is `io.c:12333`, and the content of the line is `const char *name_ptr = RSTRING_PTR(name);`.
It turns out that our hypothesis that "`RSTRING_PTR()` is an issue" seems correct.

To solve this problem, we need to check if `name` is an instance of `String`.
What should happen on a type error? We can raise a type mismatch error.
However, Ruby has a convention that if an object responds to `to_str`, then we should call `to_str` and convert it to a String object. We want to support this feature.
However, what if the result of `to_str` was not a String instance? In this case, it is okay to raise an exception.

Handling all these edge cases can be quite a chore. As it turns out, MRI has a convenient macro `StringValueCStr()` that does everything that we want to do.
When you want to get a C string buffer pointer, use `StringValueCStr()`.
This macro calls `to_str` if needed and returns a C string pointer.
If there is a problem, it then raises an error.

Let's use this macro.

```
  const char *name_ptr = StringValueCStr(name);
```

Now that think we've fixed the problem, let's run `$ make gdb` again.

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

First, compile the modified `io.c` again and generate a fixed `miniruby`.
Next, run `test.rb` on gdb.

The execution result shows that a `TypeError` is raised because `nil.to_str` does not exist.
An exception is raised on the Ruby level, and Ruby exists with no SEGV. From the perspective of MRI, terminating on an exception is correct behaviour. We're done here, so we can terminate gdb.

Now that we have a fix for the problem, we should report the fix for the `f_hello()` function to the original issue
The are several ways to report the modification.

* Add a comment on Redmine with the diff
* Make a Pull Request on GitHub and include the Pull Request URL as a comment on the Redmine ticket.

### Ticket: after reporting

#### If we are ignored...

Even if we propose a patch, a bug is not fixed until a Ruby committer commits it.
In most cases, active committers (e.g. nobu and others) will notice and commit bug fixes.
But it is possible for the acceptance of patches to be postponed.

* Low priority: if committers believe that "nobody uses the `hello()` method", it may be postponed in favor of other work.
* Busy: none of the committers are legally compelled to maintain responsibility quality assurance, so if people are busy, it may be postponed.
* If the fix is not mature or flawed: another committer should fix the patch. If the committer in charge is busy, it may be postponed.
* Unable to reproduce the problem: if there is no repro-code or repro-code doesn't work well, it may be postponed.

If you're unsure of the status of the ticket, try commenting on the issue to resurface it. If you know a Ruby committer, you can ask them to intervene directly.
Many committers have their own social media accounts (for example, Matz's twitter account is https://twitter.com/yukihiro_matz), so you can try contacting them there.

You can also ask at the monthly Ruby developers meeting. Visit https://bugs.ruby-lang.org/projects/ruby/wiki/ and refer to the DevelopersMeeting20170831Japan (or similar pages). You can add your ticket to an agenda page.

#### Backport

When the latest development version (such as ruby 2.6.0dev) accepts the patch, we also want to apply the fix to older stable versions such as Ruby 2.5 or Ruby 2.4.

If you want to backport the issues, ask for backporting in a comment on the ticket.

Maintainers of stable version branches manage backports using Redmine's "Backport" field. Tickets will be closed when fixes are accepted into the dev version. Branch maintainers review closed tickets and search for backport fixes, so please keep the status of ticket as "Closed". If there are no problems, the fixes will be backported and merged at the timing of the next release.

## `Integer#add(n)` (Scenario: when you discover a bug)

In the previous chapter, we implemented `Integer#add(n)` method and I wrote that there is a problem on that implementation.
Let's assume we release a new Ruby version with this problem (in fact, such accidents are common).

You feel that `Integer#add` is way cooler than `Integer#+`, so you use it a lot in your code. One day, however, you encounter an unexpected exception.

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

This is enough information to report a bug. Let's write a bug report.

Before submitting your bug report, check for reports of similar problems. You can use Redmine search to do this. In this case, we can use the keywords `Integer#+` or `RangeError`, for example.

After checking for duplication, we can't find any similar reports. It is a time to create a ticket!

1. Visit https://bugs.ruby-lang.org/projects/ruby-trunk/issues to create a ticket. If you don't have an account on Redmine, register first and login with new account.
2. Click the "New ticket" button.
3. Select "Bug" in the "Tracker" field.
4. The "Subject" should be clear and concise. Let's use "Integer#add causes RangeError unexpectedly".
5. "Description" should be also clear (more later).
6. You don't need to touch the "Status", "Assignee", "Target version" and "Priority" fields.
7. You should insert the result of `ruby -v` into the "ruby -v" field.
8. The "Preferred language" field should be "ruby-core in English" if you want to use English (as opposed to Japanese).
9. We don't have any file attachments this time, because there is no big log output.

"Description" should contain:

* Summary
* Repro-code and your environment (a result of `ruby -v`, OS, compiler's version and so on)
* Expected behavior
* Actual behavior
* (if possible) a patch to solve this problem

Let's use the following template.

~~~markdown
# Summary

`Integer#+` raises unexpected exception.

# Repro-code and your environment (a result of `ruby -v`, OS, compiler's version and so on)

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

### Narrow down the problematic values

After making a ticket, nobody responds to this ticket. Perhaps nobody uses it...?
So let's debug it ourselves.

To determine the cause of the bug, we need to identify which values cause an error.
It seems that 2 billion (2B) is no problem, but 3 billion (3B) causes an error.

Let's try checking all values between 2B and 3B.

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

The `trial` method tries with values from `low` to `high` and checks the return value. It can find the boundary where the return value changes from false -> true.
To explore this boundary, we implement a block which returns false if `Integer#add()` does not raise an exception and returns true if `Integer#add()` causes an exception.
Let's call the `trial` method with this block and check the boundary.

Running this program, we discover that 2,147,483,648 is on the boundary (false -> true).

BTW, this took about 13 seconds to run in my environment. Repeating 147,483,648 times (=> 13sec / 147... = 8.8e-08 sec = 90ns / iteration).
On this case, we can find near by 2B. If the boundary was closer to 3B, this script may have taken many times longer to run.

We can improve this by using a "binary search" to run the `trial` method.

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

Using the binary search version, we can find the boundary value of `2,147,483,648` within 0.20 seconds. In terms of calculation cost, the order has been reduced from O(n) to O(log n).

So, now we know that `2,147,483,647` is okay and `2,147,483,648` is not okay (error). Let's add our findings to the ticket.

```
With my observation,

* There is no exception if a is 2_147_483_647 or smaller
* There is exception if a is 2_147_483_648 or bigger
```

A Ruby committer reads this report and immediately understands the problem. The committer then fixes the issue. Congratulations!

### Answer checking

Some of you may have noticed the significance of the number 2,147,483,648. It is equal to 2^31. That is, there is no problem if a < 2^31.

The original error message was `integer 3000000000 too big to convert to `int' (RangeError)`.
The conversion fails because the value exceeds the maximum number of C's integer value.
In this environment, the range of C's integer value is -2^31 ～ 2^31-1, so the value 2^31 exceeds the range.

Let's check the original implementation.

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

Observe the usage of `FIX2INT()`. An error is raised by this conversion macro. Let's use `long` instead.

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

And now we have fixed this problem. Yay!

Ruby can represent huge numbers as integers, as long as memory is available. However, C or other languages often have a limit on their integer representation.
It is important to recognize such limitations, not only for Ruby, but for programming in general.

## Debugging tips

If you have a problem with huge application, what should you do?

Try to reduce the amount of code involved. If it is acceptable, you should gradually delete the lines of an application using a strategy similar to the binary search we used earlier.

You should use version control (e.g. git) so that you can easily revert any changes you make. This can make it easier to aggressively delete code.

There are non-deterministic issues related to GC bugs, threading bugs, VM bugs and so on (Koichi gets such errors frequently).

MRI has many assertions to check assumptions. Usually we disable such assertion checking because of their impact on performance. But you can use enable them to help you to debug.
Setting `RGENGC_CHECK_MODE` in `gc.c` to 2, and `VM_CHECK_MODE` in `vm_core.h` to 1, will enable this feature.
If you want to pass these options to the C compiler, pass `-DRGENGC_CHECK_MODE=2 -DVM_CHECK_MODE=1` options as cflags (and you need to run `make clean` before this trial).
