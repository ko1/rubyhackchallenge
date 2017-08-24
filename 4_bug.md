# バグの修正

## この資料について

MRI の変更の大部分は、バグの修正になります。本稿では、バグ修正をどのように行っていくのか、解説していきます。

## `Kernel#hello(name)`

### `Kernel#hello(name)` の実装

まずは復習です。`hello` という関数っぽいメソッドを定義しましょう。`p` メソッドのように `Kernel` に定義します。

このメソッドは、"Hello #{name}\n" という文字列を出力します。

Ruby で実装すると、こんな感じです。

```
def hello name
  puts "Hello #{name}"
end

hello 'ko1' #=> "Hello ko1" と出力
```

これを、C で書き直し、MRI に埋め込みましょう。
`rb_define_global_function()` を使うことで、`Kernel#hello` という private メソッドを作ることができます。

```
Index: io.c
===================================================================
--- io.c	(リビジョン 59647)
+++ io.c	(作業コピー)
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

ポイントは `RSTRING_PTR(name)` で、文字列オブジェクトから C 文字列のポインタを得ることができます。

`test.rb` にサンプルコードを記述し、`$ make run` を用いて実行してみましょう。ちゃんと動きましたか？　多分、動いてるんじゃないかと思います。

### バグ報告

`hello()` メソッドを含めて Ruby の最新バージョンがリリースされたと考えてください。世界中で大人気になり、多くのユーザーが `hello()` を使ったとします。
多くのユーザーが使っていると、不具合も見つかるもので、ある日 Redmine のほうに、次のようなバグ報告がきました。

```
My script causes SEGV.

See attached log for details.
```

添付されていたログには次のように書かれていました。

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

このバグ報告には次の点が欠けています。

* 再現コード
* 実行環境

ただ、添付されたログファイルを見ると、`ruby 2.5.0dev (2017-08-23 trunk 59647) [x86_64-linux]` と書いているので、Linux 環境で Ruby 2.5.0dev （開発版）を使っているのだな、ということがわかります。

再現コードがないのはよくないので、「再現コードをください」と返事をするこにしました。
（この添付のログを読むと、実は手がかりがたくさんあるので、この程度だったらすぐに治るのですが、今回はわからなかったとします）

```
Please send us your reproducible code. Small code is awesome.
```

社内の Rails アプリケーションなどだと、そのまま送るわけにはいかないので、まとめて送ることはできません。
また、「時々落ちる」といった問題は、再現コードを作るのは難しいです。

今回も、実は大きなアプリケーションの一部だったと仮定し、相手からも「Sorry we can't make such repro」といった返事が来たとします。

そこで、デバッグを開始することにしました。

### `[BUG]` の見方

`[BUG]` は、MRI に何か問題が起こったときに生じます。基本的には、インタプリタのバグになります。

```
../../trunk/test.rb:2: [BUG] Segmentation fault at 0x0000000000000008
```

まず、行頭ですが、これは `../../trunk/test.rb:2` という場所を実行中に何か問題が生じた、ということを示しています。
次に、`Segmentation fault at 0x0000000000000008` は、`[BUG]` の原因です。この場合、0x0000000000000008 番地へのメモリの読み書きで、Segmentation fault が発生した、という意味になります。一般的には、読み書き禁止領域に対する読み書きにおいて生じます。「せぐぶ」とか、「せぐふぉ」とか略されるもので、C プログラムでバグがあると、比較的多く見ることができます。

次の `ruby 2.5.0dev (2017-08-23 trunk 59647) [x86_64-linux]` で、`ruby -v` で得られるバージョン番号（および実行環境）が書いてあります。

```
-- Control frame information -----------------------------------------------
c:0003 p:---- s:0011 e:000010 CFUNC  :hello
c:0002 p:0007 s:0006 e:000005 EVAL   ../../trunk/test.rb:2 [FINISH]
c:0001 p:0000 s:0003 E:000b00 (none) [FINISH]
```

このブロックでは、「Control frame information」と書いてあるとおり、Ruby の VM の制御フレーム情報が記述されています。
ここで表示される内容は、VM の内部構造に強く依存するため、VM デバッグ以外では使いませんが、各行には次の内容が含まれています。

* `c`: フレーム番号（cf インデックス）
* `p`: プログラムカウンタ
* `s`: スタックの深さ
* `e`: 環境ポインタ（ep）の値（スタックの深さ、もしくは heap に確保した環境のアドレス）
* フレームタイプ。`EVAL` は `eval` で積んだフレーム、`CFUNC` は C で実装されたメソッド
* フレームの場所。Ruby レベルならファイル名と行番号、C 関数ならメソッド名

最後の場所情報を見ると、いわゆる普通のバックトレース情報として利用できます。

```
-- Ruby level backtrace information ----------------------------------------
../../trunk/test.rb:2:in `<main>'
../../trunk/test.rb:2:in `hello'
```

次のこのブロックは、「Ruby level backtrace information」、つまり Ruby で通常得ることができるバックトレース情報です。

```
-- Machine register context ------------------------------------------------
 RIP: 0x00000000004c17f4 RBP: 0x0000000000df5430 RSP: 0x00007fff031d4680
 RAX: 0x0000000000000000 RBX: 0x00002ba4beccefb0 RCX: 0x00002ba4bebcf048
 RDX: 0x00000000004c17f0 RDI: 0x0000000000e562d0 RSI: 0x0000000000000008
  R8: 0x00002ba4bebcf068  R9: 0x00002ba4beccef80 R10: 0x0000000000000000
 R11: 0x0000000000000001 R12: 0x00002ba4beccefb0 R13: 0x0000000000e1d4f8
 R14: 0x0000000000ec78f0 R15: 0x0000000000e562d0 EFL: 0x0000000000010202
```

このあたりから環境に依存した話になってきますが、「Machine register context」つまり CPU レジスタの情報です。

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

は、C レベルでのバックトレースです。OS などによって、とれたり取れなかったり、別のファイルに保存されていることを示すメッセージを表示することがあります。

```
* Loaded script: ../../trunk/test.rb
```

では、どのファイルを ruby コマンドに渡したかが示されています。

```
* Loaded features:

    0 enumerator.so
    1 thread.rb
    2 rational.so
    3 complex.so
```

では、どのファイルを `require` などでロードしているかを示しています（`$LOADED_FEATURES` の内容です）。

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

これは、多分 Linux だけじゃないかと思いますが、OS が管理するプロセスのメモリマップを示しています。`/proc/self/maps` で出てくる内容です。

デバッグするとき、特に注目するべきはバックトレース情報です。どうやら、Control frame information によると、`hello` でエラーが起こっていることがわかります。

そこで、`hello` の実装を、もう一度じっと見直してみましょう。

NOTE: 問題箇所がバックトレースに現れるバグは、比較的簡単なバグです。難しいバグになると、例えばプログラムの関係ない箇所でデータが壊れており、後にその情報を参照した箇所で `[BUG]` になると、原因の箇所がわからない、ということがよく起きます。

### `f_hello()` 関数の見直し

`hello` メソッドの実体は次の C 関数でした。

```
static VALUE
f_hello(VALUE self, VALUE name)
{
    const char *name_ptr = RSTRING_PTR(name);
    fprintf(stdout, "Hello %s\n", name_ptr);
    return Qnil;
}
```

じっと見ますと、`name` で渡ってきた引数に対して `RSTRING_PTR()` を使っています。
`RSTRING_PTR()` は、文字列オブジェクト（`T_STRING` と型付けされたオブジェクト）にのみ有効なマクロであり、その他のオブジェクトには対応しません（何が起きるか保証されていません）。
多分、これが原因なんじゃないでしょうか。

NOTE: 「じっと見る」ことで問題がわかるかは、MRI の内部構造をどの程度把握しているかによります。今回は規模が小さいため簡単ですが、通常はもっと難しいです。

では、仮説を検証するために、`hello(nil)` とでもしてみましょう。同様の `[BUG]` が出力されたのではないかと思います。

そこで、チケットに再現コードを投稿しておきましょう。

```
The following code can reproduce this issue:

  hello(nil)
```

これだけ小さな再現コードがあれば、あとは得意な人に任せても問題ないと思います。今回は、パッチの作成まで行いましょう。

### gdb を用いたデバッグ

`test.rb` に `hello(nil)` と記入し、`make gdb` と実行しましょう。

```
Program received signal SIGSEGV, Segmentation fault.
f_hello (self=9904840, name=8) at ../../trunk/io.c:12333
12333       const char *name_ptr = RSTRING_PTR(name);
```

と出力されれば成功です。これは、`SEGV` シグナルをうけたため、`gdb` がデバッグ対象プログラムを一時停止した、という意味です。

ちょっと、`name` に何が入っているか確認してみましょう。

```
(gdb) p name
$1 = 8
(gdb) rp name
nil
```

`p name` によって、`name` の値（数値）が 8 であることがわかります。が、8 だけだとよくわかりません。
`rp name` によって、その 8 という値が `nil` であることがわかりました。

SEGV によって停止した場所は io.c:12333 であり、`const char *name_ptr = RSTRING_PTR(name);` という行で起こっていることがわかります。
どうやら、「`RSTRING_PTR()`が問題だ」という仮説は正しかったようです。

あるオブジェクトから C の文字列ポインタをとるには、`StringValueCStr()` を使います。必要なら `to_s` を実行し、文字列に変換してから C の文字列ポインタに変換します。
早速やってみましょう。

```
  const char *name_ptr = StringValueCStr(name);
```

このように修正し、もう一度 `$ make gdb` を実行してみましょう。

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

まず、修正したので `io.c` を再コンパイルし、修正を反映した `miniruby` を生成します。
次に、gdb 上で `test.rb` を実行しています。

実行結果は、`nil.to_s` がないため、`TypeError` が発生し、終了します。Ruby 的には例外発生で終了しましたが、MRI 的には、そのように異常終了することが正常（わかりづらいですね）なので、問題ないと判断し、gdb を終了させます。

では、治ったので、`f_hello()` 関数に行った修正を、チケットに反映させましょう。修正方法を伝えるのは、どのような方法でもかまいません。

よくあるのは次のような方法です。

* Redmine チケットに、diff を含めコメントする
* github で pull request を作り、その URL をチケットに記述する

## `Integer#add(n)` のバグ

先ほど実装した `Integer#add(n)` には問題があると延べました。

TBD
