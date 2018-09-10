# (4) バグの修正

## この資料について

MRI の変更の大部分は、バグの修正になります。
本稿では、MRI のバグ修正をどのように行っていくのか、仮想のバグ報告をもとに、ご紹介していきます。
バグ報告を受ける方、バグ報告をする方の2つの視点から説明します。

## `Kernel#hello(name)`（他の人のバグ報告を見る場合）

### `Kernel#hello(name)` の実装

まずは、MRI にメソッドを追加する復習です。`hello` という関数っぽいメソッドを定義してみましょう。
`p` メソッドのように `Kernel` に定義し、private メソッドにしておきましょう。

このメソッドは、`"Hello #{name}\n"` という文字列を出力します。

Ruby で実装すると、こんな感じです。

```ruby
def hello name
  puts "Hello #{name}"
end

hello 'ko1' #=> "Hello ko1" と出力
```

これを、C で書き直し、MRI に埋め込みましょう。
`rb_define_global_function()` を使うことで、`Kernel#hello` という private メソッドを作ることができます。

```diff
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

`hello()` メソッドを含めて Ruby の最新バージョン（例えば、Ruby 2.4.0）がリリースされたと考えてください。
このメソッドが世界中で大人気になり、多くのユーザーが `hello()` を使ったとします。
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

再現コードがないのはよくないので、「再現コードをください」と返事をすることにしました（この添付のログを読むと、実は手がかりがたくさんあるので、この程度だったらすぐに治るのですが、今回はわからなかったとします）。

```
Please send us your reproducible code. Small code is awesome.
```

問題が起きたプログラムが社外秘の Rails アプリケーションなどですと、そのソースコードをそのまま送るわけにはいきません。
また、「時々落ちる」といった問題は、再現コードを作るのは難しいです。

今回も、実は大きなアプリケーションの一部だったと仮定し、相手からも「Sorry we can't make such repro」といった返事が来たとします。

そこで、しょうが無いので自分でデバッグを開始することにしました。

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

最後のカラムを見ると、いわゆる普通のバックトレース情報が書いてあります。

```
-- Ruby level backtrace information ----------------------------------------
../../trunk/test.rb:2:in `<main>'
../../trunk/test.rb:2:in `hello'
```

このブロックは、「Ruby level backtrace information」、つまり Ruby で通常得ることができるバックトレースの情報です。

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

この行は、どのファイルを ruby コマンドに渡したかを示しています。

```
* Loaded features:

    0 enumerator.so
    1 thread.rb
    2 rational.so
    3 complex.so
```

では、どのファイルを `require` などでロードしているかを示しています（`$LOADED_FEATURES` の内容です）。
この例では、ファイルがほとんどありませんが、Ruby on Rails アプリケーションなどではたくさんの Gem を利用しているため、この行が数千行になることがあります。

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

これは、多分 Linux 上だけじゃないかと思いますが、OS が管理するプロセスのメモリマップを示しています。`/proc/self/maps` で出てくる内容と同じです。

デバッグするとき、特に注目するべきはバックトレース情報です。どうやら、Control frame information によると、`hello` メソッド実行時に問題が起こっていることがわかります。

そこで、`hello` の実装を、もう一度じっと見直してみましょう。

> NOTE: 問題箇所がバックトレースに現れるバグは、比較的簡単なバグです。難しいバグになると、例えばある箇所でバグによりデータが壊れ、プログラムがある程度進んだ後にその情報を参照した箇所で `[BUG]` になる、といったケースですと、バグの箇所がわからない、ということが起きます。VM や GC のバグなんかは、こういうのが多いです（困ります）。

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

> NOTE: 「じっと見る」ことで問題がわかるかは、MRI の内部構造をどの程度把握しているかによります。今回は規模が小さいため簡単ですが、通常はもっと難しいです。

では、仮説を検証するために、`hello(nil)` とでもしてみましょう。同様の `[BUG]` が出力されたのではないかと思います。

そこで、記録のために、チケットに再現コードをコメントしておきましょう。

```
The following code can reproduce this issue:

  hello(nil)
```

これだけ小さな再現コードがあれば、あとは得意な人に任せても問題ないと思います。
今回は、せっかくなので、パッチの作成まで行いましょう。

### gdb を用いたデバッグ

`test.rb` に `hello(nil)` と記入し、`make gdb` と実行しましょう（lldb を用いる場合は、 `make lldb` と実行した後に、 `run` を実行します）。

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
`rp name` によって、その 8 という値が `nil` であることがわかります。

SEGV によって停止した場所は io.c:12333 であり、`const char *name_ptr = RSTRING_PTR(name);` という行で起こっていることがわかります。
どうやら、「`RSTRING_PTR()`が問題だ」という仮説は正しかったようです。

この問題を解決するためには、`name` が `String` オブジェクトであることをチェックしなければなりません。
違う場合はどうしましょうか。型が合わない、と例外をあげてもいいですね。
ただ、Ruby の場合、`to_str` を持っていれば、これを呼んで文字列オブジェクトに変換し、それを扱うという慣習があります。そこもサポートしておきたいところです。
ただ（まだあるのか）、`to_str` の結果が `String` オブジェクトじゃなかったらどうしましょう。この場合は例外でいいですね。

いちいちこのような処理を書くのは面倒ですし、頻出する操作なので、MRI は、これらのチェック（や、必要なら変換）を行うマクロ `StringValueCStr()` が用意されています。

あるオブジェクトから C の文字列ポインタをとるには、`StringValueCStr()` を使います。
必要なら `to_str` を実行し、文字列に変換してから C の文字列ポインタに変換します。
問題が生じれば、きちんとエラーを発生させます。

早速使って修正してみましょう。

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

実行結果は、`nil.to_s` がないため、`TypeError` が発生し、終了します。Ruby 的には例外発生で終了しましたが、MRI 的には、そのように例外発生による終了することが正常（わかりづらいですね）なので、問題ないと判断し、gdb を終了させます。

では、治ったので、`f_hello()` 関数に行った修正を、チケットに反映させましょう。修正方法を伝えるのは、どのような方法でもかまいません。

よくあるのは次のような方法です。

* Redmine チケットに、diff を含めコメントする（diff が長ければファイルを添付する）
* github で pull request を作り、その URL をチケットにコメントする

やりやすい方法をお選び下さい。

### チケットその後

#### そのまま放っておかれた場合

チケットに修正まで提案しても、Ruby コミッタがコミットするまで、バグは修正されません。
多くの場合、中田さん（nobu）などの手の早いコミッタによって、バグ修正はすぐに取り込まれることが多いですが、いくつかの理由で取り込まれないことがあります。

* 優先度が低い場合 → `hello()` なんて誰も使ってないよね、とコミッタが判断すると、面倒くさがって後回しにされることがあります。
* コミッタが忙しい場合 → Ruby の品質管理に法的責任をもってあたっている人物はいないため、ほかのことに忙しければ後回しになります。
* 修正が微妙な場合 → 担当コミッタが、さらに修正しなければなりません。当該人物が忙しければ、後回しになります。
* 再現ができない場合 → 再現コードがない、もしくは実行してもコミッタの環境では問題が再現できない場合、修正の確認が難しく、放置しがちになります。

状況がわからない場合、チケットにコメントで催促してみましょう。また、もし Ruby コミッタに知り合いがいれば、聞いてみると話が早いかもしれません。
SNS をやっている人も多いので（例えば、まつもとゆきひろさんの  twitter アカウントは https://twitter.com/yukihiro_matz です）、そういう場所で聞いてもいいかもしれません。

最近毎月行っている Ruby 開発者会議で議題に挙げる方法もあります。https://bugs.ruby-lang.org/issues/14770 からたどれる（かもしれない）次回の会議のアジェンダに、議論して欲しいチケットを、その理由を含めてコメントしておいて下さい。

#### バックポート

さて、最新開発版（例えば、ruby 2.5.0dev）では、バグ修正が取り込まれたとします。
しかし、すでにリリース済みの安定版ブランチ、例えば、Ruby 2.4.0 にバグ入りの `hello()` メソッドがあれば、Ruby 2.4.1 で修正して欲しいと思うのが人情です。

このように、すでにリリース済みの安定版ブランチに修正を反映して欲しい時は redmine のチケットに、コメントでその旨伝えましょう。

安定版ブランチメンテナは Backport 欄を適切に設定して backport の必要な変更を管理します。開発版で修正が行われると、チケットは Close になります。安定版ブランチメンテナは Closed のチケットを検索して backport 対象を探すので Close のままにしておいてください。問題なければ、バックポートが行われ、安定版のバグフィックスリリースのタイミングで修正された MRI が公開されます。

## `Integer#add(n)` （バグを自分で発見してしまった場合）

先ほど実装した `Integer#add(n)` には問題があると述べました。この問題ありのコードが、Ruby の安定版としてリリースされてしまったとします（実際にも、こういう例が結構あります）。

あなたは `Integer#+` よりも、`Integer#add` のほうが cool だと思ったので、たくさん使ってみたとします。ただ、`Integer#+` では起きなかった例外が、`Integer#add` では起こるようになってしまいました。

```
a = 3_000_000_000
b = 2_000_000_000
p a+b #=> 5000000000
p a.add(b) #=> `add': integer 3000000000 too big to convert to `int' (RangeError)
```

### バグ報告

ここまでで、

* どのような挙動を期待するか（`Integer#+` と同じ挙動になって欲しい）
* 実際はどのようになったか（`RangeError` となった）
* 小さな再現可能なコード（4 行なので十分小さい）

のような情報が出揃っているため、バグ報告するのに十分な情報が集まりました。バグ報告をしましょう。

ただ、その前に、同様のバグ報告がないかどうか、チェックしましょう。Redmine の検索機能を使って、例えば `Integer#add` や `RangeError`　といったキーワードを用いて検索してみましょう。

検索した結果、どうやらまだ報告されていないことがわかったので、チケットを作成することにしましょう。

1. https://bugs.ruby-lang.org/projects/ruby-trunk/issues でバグ登録しますが、Redmine にアカウントがない場合は、アカウントを登録しましょう。その後、ログインします。
2.「新しいチケット」ボタンをクリックし、チケット登録画面へ映ります。
3. 「トラッカー」は "Bug" で良いです。
4. 題名は、ぱっと見てわかる名前が良いので、「Integer#add causes RangeError unexpectedly」にしましょう。日本語で登録する場合は「Integer#add が RangeError を返す」などでもいいでしょう。
5. 説明には、症状を書きましょう。後述します。
6. ステータス、担当者、対象バージョンは変えないでよいです（わかる人が付けてくれます）。
7. ruby -v には、再現した Ruby の ruby -v の結果を入力しましょう。
8. 報告先は、日本語で議論したい場合、「ruby-dev in Japanese（日本語）」、英語の場合「ruby-core in English」を選びましょう。
9. 今回は長いログなどはないため、添付ファイルは無しです。

説明部には、

* Summary（問題の短いまとめ）
* 再現コードと再現環境（ruby -v の結果（必須です）、OS、コンパイラなどのバージョン、その他）
* 期待する挙動
* 実際に得られた挙動
* （可能なら）その問題を修正するためのパッチ

を書くのでした。下記をコピペして使いましょう。Markdown で記述します。

~~~markdown
# Summary（問題の短いまとめ）

`Integer#+` で意図しない `UnexpectedError` が発生する。

# 再現コードと再現環境（ruby -v の結果（必須です）、OS、コンパイラなどのバージョン、その他）

次のコードで再現します。

```
a = 3_000_000_000
b = 2_000_000_000
p a+b #=> 5000000000
p a.add(b) #=> `add': integer 3000000000 too big to convert to `int' (RangeError)
```

実行したのは下記の環境です。

```
$ uname -a
Linux u64 3.13.0-126-generic #175-Ubuntu SMP Thu Jul 20 17:33:56 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux
```

# 期待する挙動

`Integer#+` と同じ、つまり上記例では `p a+b #=> 5000000000` と同じ挙動を期待しました。

# 実際に得られた挙動

`p a.add(b) #=> `add': integer 3000000000 too big to convert to `int' (RangeError)` のように、`RangeError` が発生しました。
~~~

さて、ここまでくれば OK です。「作成」ボタンを押して、チケットを作成しましょう。

### 問題のある値の絞り込み

チケットを登録しましたが、誰かも返信がつきません。この機能、誰も使ってないんでしょうか...（よくあります）。
そのため、自分でデバッグしようと決心しました。

原因究明のためには、どのような値でエラーが出るのか確認するのが先決です。

今回は、上記コードでは `a` の値を色々いじってみましょう。どうやら、2B（20億）では OK で、3B ではエラーになるようです。
そこで、2B から 3B まで、値をずらしてみましょう。

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

`trial` メソッドは、値を low から high まであげていって、そのカウンタを渡して起動したブロックの返値が false -> true に変更されたタイミングを探ります。
そこで、`Integer#add()` でエラーで無ければ false、エラーなら true になるようにしたブロックを使って、エラーになる境界値を探ってみましょう。

実行してみると、どうやら、2,147,483,648 という値で false -> true になったようです。

なお、この実行を行うために、手元のコンピューターでは 13 秒かかりました。繰り返しを 147,483,648 回行ったからですね（つまり、13sec / 147... = 8.8e-08 ということで、だいたい 90ns / iteration ということになります）。
今回は、たまたま 2B の近くで値を見つけることができましたが、3B に近いところに境界値があると、何倍もの時間がかることになります。

そこで、二分探索を使うように `trial` を修正してみます。二分探索は、探索範囲を半分ずつに減らしていく方法です（前出の線形探索は、1/n ずつ減らしていく方法）。

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
  linear_trial mid-2, mid+1, &b # 実装で楽をするためです
end
```

これを利用すると、2,147,483,648 で変わった、ということがわかり、0.20秒で実行が終了しました。計算量でいうと、O(n) が O(log n) に減ったと表現します。

さて、これによって、2,147,483,647 では平気でしたが、2,147,483,648 ではエラーがでる、ということがわかります。ここまでわかったので、報告しておきましょう。

```
調べてみると、

a が
2_147_483_647 ではエラーが出ませんが、
2_147_483_648 ではエラーがでるようです。
```

これを見たあるコミッタは、すぐに状況を把握できたので、バグを修正してくれました。めでたしめでたし（いつもそうだといいですね）。

### 答え合わせ

2,147,483,648 の値を見てピンとくる人はくると思いますが、2 の 31 乗（2^31）が 2,147,483,648 です。つまり、a < 2^31 のとき、問題ない、ということがわかります。

元々のエラーメッセージは `integer 3000000000 too big to convert to `int' (RangeError)` でした。
変換しようとしている数値が大きすぎて、C の `int` 型の値に収まらないよ、と言っています。
C 言語での int の範囲は -2^31 ～ 2^31-1 になりますので、この範囲を超えた、というエラーですね。

実装を確認してみましょう。

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

`FIX2INT()` をしているところがありますね。ここで、2^31 以上の大きな値が渡ってきたからエラーが出たわけですね。そこで、`long`（と、`FIX2LONG`）を使うようにしましょう。

```C
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

これで、どんなに大きな数を渡しても、`RangeError` が起きることは無くなりました。めでたしめでたし。

Ruby では、メモリがある限り大きな数を（ほかの整数と変わらずに）扱うことができます。
しかし、C やほかの多くのプログラミング言語では、整数値に値の上限（と下限）があることが一般的です。
Ruby に限りませんが、プログラミングにおいて、その違いを意識することは大事です。

## デバッグ Tips

何か問題があったプログラムが大きい場合、どのように再現コードを見つければ良いでしょうか。

可能であれば、プログラムをどんどん削ってしまいましょう。二分探索の要領で、（消せるなら）コードを削っていくと小さくなることがあります。
多くの場合、バージョン管理システムを使っていると思うので、元に戻すのは（多分）簡単です。思い切って削りましょう。

GC バグやスレッドバグ、VM バグなど、なんかよくわからないんだけどランダムに発生する、というケースが時々あります（笹田の場合、とてもよくあります）。

MRI には、ソースコード中にいろいろな制約チェックを行う仕組みが入っています。これを利用すると性能低下してしまうため、普段はオフになっていますが、これをオンにして実行すれば、何かわかるかもしれません。

`gc.c` の `RGENGC_CHECK_MODE` を 2 に、`vm_core.h` の `VM_CHECK_MODE` を 1 に変更すると、この仕組みをオンにできます。
`Makefile` で C コンパイラに渡すオプションを変更する場合は、`-DRGENGC_CHECK_MODE=2 -DVM_CHECK_MODE=1` みたいに追加すると良いです（ただし、一度 clean する必要があります）。

バグがどうしても取れないときは、上記のようなチェックコードを沢山挟むことでバグがみつかりやすくなることがあります。
原因を検討し、関係する正しい条件でアサーションを入れてみましょう。

## おまけの練習問題

バグを仕込んだブランチを作ってみました。どこがバグか探してみましょう。答えは diff にあるので、解いている間は diff を見ないように注意して下さい。

> Note: なお、普通は diff や blame で過去の履歴を見ながら問題を解決していくので、今回の話は、あくまでそういうゲームとしてお楽しみ下さい。

### (1) なんか異常終了する

* `$ git remote add ko1 https://github.com/ko1/ruby.git` として、笹田の GitHub 上の Ruby リポジトリを、リモートリポジトリとして登録して下さい。
* fetch して、`rhc_fail1` ブランチを checkout して下さい。 `$git fetch ko1 && git checkout -b rhc_fail2 ko1/rhc_fail2`
  * このとき、diff は見ないように注意して下さい。
* `$ make miniruby` として、`miniruby` を作って下さい。
* `$ ./miniruby -e ...` など、`./miniruby` で何か動かしてみて下さい。きっと、派手なエラーが出てくると思います。くれぐれも diff を見ないように、ご注意下さい。

> Note: `make gdb` などが役に立つでしょう。

### (2) なんか変な表示が出る

* 今度は、`rhc_fail2` を checkout して下さい。
* 生成した `./miniruby` で、何か動かしてみて下さい。いつもと違うメッセージが出てくるようです。どうやら、デバッグメッセージを消し忘れているようですが、どこにあるか探して、直してみましょう。

> Note: `git grep` などが役に立つでしょう。

### (3) なんか変な値が出る

* 次は、`rhc_fail3` を checkout して下さい。
* `make test-all TESTS='ruby/test_string.rb'` として、文字列のテストを実行すると、沢山エラーが出ます。なぜエラーが出るのか、調べてみましょう。

> Note: 問題のテストコードを見て、最小再現コードを探してみましょう。

### (4) なんかテストが失敗する

* 最後に `rhc_fail4` を checkout して下さい。
* 今度は配列のテストがおかしいようです。`make test-all TESTS='ruby/test_array.rb` を実行してみると、エラーが出ます。なぜエラーが出るのか、調べてみましょう。
