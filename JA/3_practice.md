# (3) 演習：メソッドの追加

## この資料について

実際に、MRI にメソッドを追加してみましょう。修正する例を書いているので、実際に手を動かして追加してみてください。

なお、git リポジトリを使っていると思うので、各修正ごとに commit するか、ブランチを作るようにしておいてください。

## `Array#second`

`Array#second` メソッドを追加してみましょう。
`Array#first` は最初の要素を返します。`Array#second` は二つ目の要素を返すメソッドです。

Ruby で定義するとこんな感じです。

```ruby
# specification written in Ruby
class Array
  def second
    self[1]
  end
end
```

1. `array.c` を開きましょう。
2. `ary_second()` という関数を追加しましょう。`Init_Array()` の前が良いと思います。
3. `rb_define_method(rb_cArray, "second", ary_second, 0);` という行を `Init_Array()` 関数に追加しましょう。
4. ビルドし、`ruby/test.rb` にサンプルコードを記述して、`make run` で動くか試してみましょう。
5. テストを `ruby/test/ruby/test_array.rb` に記入しましょう。minitest フォーマットです。
6. `$ make test-all` と実行すると、書いたテストが実行されます。ただし、数万のテストが走ってしまうので、Array のテストだけに絞りましょう。
  * `$ make test-all TESTS='ruby/test_array.rb'` とすることで、`ruby/test/ruby/test_array.rb` だけテストします。
  * `$ make test-all TESTS='ruby/test_array.rb -n test_xxx'` とすることで、`ruby/test_array.rb` にある `test_xxx` にマッチするテストのみ走らせます。
  * `$ make test-all TESTS='-j8'` とすることで、8 並列でテストを走らせます。
7. ほかのメソッドを参考に、`Array#second` に rdoc ドキュメントを記入してみましょう。

C での定義はこんな感じになります（下記 diff を取ってから時間がたっているので、行番号は、ずれていると思います）。

```diff
diff --git a/array.c b/array.c
index bd24216af3..79c1c1d334 100644
--- a/array.c
+++ b/array.c
@@ -6131,6 +6131,12 @@ rb_ary_sum(int argc, VALUE *argv, VALUE ary)
  *
  */
 
+static VALUE
+ary_second(VALUE self)
+{
+  return rb_ary_entry(self, 1);
+}
+
 void
 Init_Array(void)
 {
@@ -6251,6 +6257,8 @@ Init_Array(void)
     rb_define_method(rb_cArray, "dig", rb_ary_dig, -1);
     rb_define_method(rb_cArray, "sum", rb_ary_sum, -1);
 
+    rb_define_method(rb_cArray, "second", ary_second, 0);
+
     id_cmp = rb_intern("<=>");
     id_random = rb_intern("random");
     id_div = rb_intern("div");
```

少し解説しておきます。

* `ary_second()` が実装です。
* `VALUE` は Ruby のオブジェクトであり、`self` はメソッド呼び出しでのレシーバ（`ary.second` の時の `ary`）です。すべてのメソッド呼び出しは、Ruby の配列を返すので、返値も `VALUE` となります。
* `rb_ary_entry(self, n)` が `self[n]` の意味であり、`n = 1` なので、2番目（0 origin なので）を返します。
* `Init_Array` という関数が、MRI 起動時に実行されます。
* `rb_define_method(rb_cArray, "second", ary_second, 0);` で、`Array` クラスに `second` メソッドを定義しています。
  * `rb_cArray` が Array クラスのオブジェクトです。`rb_` が Ruby の何か、`c` がクラスであることを意味しするため、`rb_cArray` が Ruby の `Array` クラスであることがわかります。ちなみに、モジュールの場合は `m`（例えば、`rb_mEnumerable`、エラークラスの場合は `e`（例えば、`rb_eArgError`）。
  * `rb_define_method` がインスタンスメソッドを定義する関数です。
  * 「`rb_cArray` に、`"second"` という名前のメソッドを定義しろ。メソッドが呼ばれたら `ary_second` を呼び出せ。なお、引数の数は 0 である」という意味になります。

ポイントは、(1) メソッドの実体は C の 1 関数である (2) その関数を `rb_define_method()` で Ruby のメソッドとして登録する、ということです。Ruby のメソッドは、ほぼこんな感じで実装されています。

## `String#palindrome?`

回文判定メソッド `String#palindrome?` を定義してみましょう。

次のコードは Ruby で書いたもの、および、ちょっとしたテストです。

```ruby
class String
  def palindrome?
    chars = self.gsub(/[^A-z0-9\p{hiragana}\p{katakana}]/, '').downcase
    # p chars
    !chars.empty? && chars == chars.reverse
  end
end

# Small sample program
# Sample palindrome from https://en.wikipedia.org/wiki/Palindrome
[# OK
 "Sator Arepo Tenet Opera Rotas",
 "A man, a plan, a canal - Panama!",
 "Madam, I'm Adam",
 "NisiOisiN",
 "わかみかものとかなかとのもかみかわ",
 "アニマルマニア",
 # NG
 "",
 "ab",
].each{|str|
  p [str, str.palindrome?]
}
```

Ruby コードを、C のコードに直接的に変換してみます。
`Array#second` での手順を参考に、下記を変更してみてください。

```diff
diff --git a/string.c b/string.c
index c140148778..0f170bd20b 100644
--- a/string.c
+++ b/string.c
@@ -10062,6 +10062,18 @@ rb_to_symbol(VALUE name)
     return rb_str_intern(name);
 }
 
+static VALUE
+str_palindrome_p(VALUE self)
+{
+  const char *pat = "[^A-z0-9\\p{hiragana}\\p{katakana}]";
+  VALUE argv[2] = {rb_reg_regcomp(rb_utf8_str_new_cstr(pat)),
+                  rb_str_new_cstr("")}; 
+  VALUE filtered_str = rb_str_downcase(0, NULL, str_gsub(2, argv, self, FALSE));
+  return rb_str_empty(filtered_str) ? Qfalse : 
+         rb_str_equal(filtered_str, rb_str_reverse(filtered_str));
+                                     
+}
+
 /*
  *  A <code>String</code> object holds and manipulates an arbitrary sequence of
  *  bytes, typically representing characters. String objects may be created
@@ -10223,6 +10235,8 @@ Init_String(void)
     rb_define_method(rb_cString, "valid_encoding?", rb_str_valid_encoding_p, 0);
     rb_define_method(rb_cString, "ascii_only?", rb_str_is_ascii_only_p, 0);
 
+    rb_define_method(rb_cString, "palindrome?", str_palindrome_p, 0);
+
     rb_fs = Qnil;
     rb_define_hooked_variable("$;", &rb_fs, 0, rb_fs_setter);
     rb_define_hooked_variable("$-F", &rb_fs, 0, rb_fs_setter);
```

解説します。

* `rb_reg_regcomp(pat)` によって、`pat` という C の文字列を正規表現オブジェクトとしてコンパイルします。
* `rb_str_new_cstr("")` で、空の Ruby 文字列を生成します（C の空文字列を、Ruby の空文字列に変換しています）。
* `str_gsub()` で、`String#gsub` 相当の処理を行います。ここでは、正規表現を使って、扱う文字以外を削っています。
* `rb_str_downcase()` で、その結果を小文字にそろえます。
* `rb_str_empty()` で、フィルタ結果が空文字列であるかどうかをチェックします。
* `rb_str_reverse()` で、文字列の順序の逆転をしています。
* `rb_str_equal()` で、文字列の比較をしています。

なんとなく、Ruby のコードと一対一に対応しているのがわかるでしょうか。

ちなみに、Ruby 版と仕様が決定的に異なる点が1つあります。それは、`String` クラスのメソッド（例えば `String#empty?`）を書き換えた時の挙動です。Ruby 版では、書き換えた処理が呼ばれますが、`rb_str_empty()` は、`String#empty?` とは無関係なので呼ばれません（`String#empty?` が `rb_str_empty()` を利用している）。興味があれば、実際に試してみて下さい。

## `Integer#add(n)`

`Integer` クラスに、`n` 足すメソッドを作りましょう。

Ruby で書くと、こんな感じです。

```ruby
class Integer
  def add n
    self + n
  end
end

p 1.add(3) #=> 4
p 1.add(4.5) #=> 5.5
```

```diff
Index: numeric.c
===================================================================
--- numeric.c	(リビジョン 59647)
+++ numeric.c	(作業コピー)
@@ -5238,6 +5238,12 @@
     }
 }
 
+static VALUE
+int_add(VALUE self, VALUE n)
+{
+    return rb_int_plus(self, n);
+}
+
 /*
  *  Document-class: ZeroDivisionError
  *
@@ -5449,6 +5455,8 @@
     rb_define_method(rb_cInteger, "bit_length", rb_int_bit_length, 0);
     rb_define_method(rb_cInteger, "digits", rb_int_digits, -1);
 
+    rb_define_method(rb_cInteger, "add", int_add, 1);
+
 #ifndef RUBY_INTEGER_UNIFICATION
     rb_cFixnum = rb_cInteger;
 #endif
```

1引数が必須なので、`rb_define_method()` の最後の引数が `1` になっており、`int_add()` の引数に `VALUE n` が追加されています。

実際に、足し算を行う処理は `rb_int_plus()` が行っています。そのため、難しい処理は書いていません。ただ、`self` と `n` が `Fixnum`（ある一定の小さな数値、C の `int` への変換、`int` からの変換が容易）である場合だけ、C で足し算をしてみましょう。

> Tips: Ruby 2.3 までは、整数値は `Fixnum` クラスと `Bignum` クラスに分かれていましたが、Ruby 2.4 からは `Integer` に統合されました。ただし、MRI 内部では、（性能上の観点から）それらを区別して管理しています（例えば、`FIXNUM_P(bignum)` とすると偽が返ります）。

```diff
Index: numeric.c
===================================================================
--- numeric.c	(リビジョン 59647)
+++ numeric.c	(作業コピー)
@@ -5238,6 +5238,22 @@
     }
 }
 
+static VALUE
+int_add(VALUE self, VALUE n)
+{
+    if (FIXNUM_P(self) && FIXNUM_P(n)) {
+	/* c = a + b */
+	int a = FIX2INT(self);
+	int b = FIX2INT(n);
+	int c = a + b;
+	VALUE result = INT2NUM(c);
+	return result;
+    }
+    else {
+	return rb_int_plus(self, n);
+    }
+}
+
 /*
  *  Document-class: ZeroDivisionError
  *
```

`FIXNUM_P(self) && FIXNUM_P(n)` によって、`self` と `n` が `Fixnum` であるかどうかをチェックしています。
もしそうであれば、`FIX2INT()` によって、`int` に変換できるので、変換し計算しています。計算結果を `INT2NUM()` によって、VALUE 型（つまり、Ruby の `Integer` クラスのオブジェクト）へ変換し、それを返り値として返します。
もし `self` と `n` のどちらかが `Fixnum` でなければ、`rb_int_plus` に処理を任せています。

※注意：実は、この修正版のプログラムにはバグがあります。

## `Time#day_before(n=1)`

`Time` クラスに n 日前の値（引数が無ければ1日前）を返すメソッドを加えてみましょう。

Ruby で書くとこんな感じです。24時間 * n の秒数を減らしています。厳密には、この方法で n 日前を計算するということは出来ません（閏秒とか、サマータイムとか。そもそも n 日前とは？）。が、今回はサンプルなので、あまり細かいことを考えないようにしようと思います。

```ruby
class Time
  def day_before n = 1
    Time.at(self.to_i - (24 * 60 * 60 * n))
  end
end

p Time.now               #=> 2017-08-24 14:48:44 +0900
p Time.now.day_before    #=> 2017-08-23 14:48:44 +0900
p Time.now.day_before(3) #=> 2017-08-21 14:48:44 +0900
```

C で書いてみると、こんな感じです。

```diff
Index: time.c
===================================================================
--- time.c	(リビジョン 59647)
+++ time.c	(作業コピー)
@@ -4717,6 +4717,22 @@
     return time;
 }
 
+static VALUE
+time_day_before(int argc, VALUE *argv, VALUE self)
+{
+    VALUE nth;
+    int n, sec, day_before_sec;
+
+    rb_scan_args(argc, argv, "01", &nth);
+    if (nth == Qnil) nth = INT2FIX(1);
+    n = NUM2INT(nth);
+
+    sec = NUM2INT(time_to_i(self));
+    day_before_sec = sec - (60 * 60 * 24 * n);
+
+    return rb_funcall(rb_cTime, rb_intern("at"), 1, INT2NUM(day_before_sec));
+}
+
 /*
  *  Time is an abstraction of dates and times. Time is stored internally as
  *  the number of seconds with fraction since the _Epoch_, January 1, 1970
@@ -4896,6 +4912,8 @@
 
     rb_define_method(rb_cTime, "strftime", time_strftime, 1);
 
+    rb_define_method(rb_cTime, "day_before", time_day_before, -1);
+
     /* methods for marshaling */
     rb_define_private_method(rb_cTime, "_dump", time_dump, -1);
     rb_define_private_method(rb_singleton_class(rb_cTime), "_load", time_load, 1);
```

ポイントを説明します。

* 可変長引数にするために、`rb_define_method()` で `-1` を指定しています。何個来るかわかりませんよ、という意味になります。
* `time_day_before(int argc, VALUE *argv, VALUE self)` という関数でメソッドの実体を定義しています。`argc` に引数の数、`argv` に長さ `argc` VALUE の配列へのポインタが格納されています。
* `rb_scan_args()` を使い、引数をチェックしています。`"01"` というのは、必須引数が 0 個、オプショナル引数が 1 個、という意味になります。つまり、0 or 1 個の引数を取る、ということになり、もし 1 個引数を取っていれば、`nth` に格納されます。もし、引数が 0 個の場合（つまり、引数が無い場合）は、`nth` には `Qnil` （Ruby での `nil` を、C ではこのように表現している）が格納されます。
* `Time.at()` を実現するために、`rb_funcall(recv, mid, argc, ...)` を利用しています。
  * 第一引数はレシーバ、つまり `recv.mid(...)` の時の `recv` になります。`Time.at` では、レシーバは `Time` クラスオブジェクト、ということになります。
  * メソッド名の指定は、C の文字列リテラルでは無く、ID で行います。ID を生成するためには、`rb_intern("...")` を利用します。ID は、ある文字列に対して、MRI プロセス中で一意な値のことです。Ruby でいう Symbol、Java でいう "intern" した文字列です。
  * 1 引数なので、1 と指定し、その後で実際の引数を指定します。

なお、この実装には色々と問題があります。Ruby 実装と何が違うのか、検討してみてください。

## 拡張ライブラリ

MRI を後から機能拡張するための、C 拡張ライブラリは、ほぼ同じような流儀で作ることができます。

例えば、`Array#second` を MRI に直接組み込むのではなく、拡張ライブラリで提供することを考えます。

次の手順で `.so` を作ります（MacOS だと、`.bundle` になります）。

1. ディレクトリ `array_second/` を作成する（どこでも良いです）。
2. `array_second/extconf.rb` を作成する
  * `require 'mkmf'` として、mkmf ライブラリを使えるようにする。mkmf ライブラリは、Makefile を生成するためのライブラリで、各種設定（たとえば、OS によって利用するライブラリを変えるなど）を行います。今回は、とくに設定はない。
  * 設定後（今回はない）、`create_makefile('array_second')` と書いておく。
3. `array_second.c` を作成する
  * 最初に `#include <ruby/ruby.h>` を記載する。
  * このファイルには、(1) メソッドの実体と、(2) `Array` クラスへの初期化を書いておく。
  * (1) は、上記 `ary_second()` 関数とまったく同じ。
  * (2) は、`Init_array_second()` 関数内で、`rb_define_method()` を利用する。`Init_array_second` という名前は、`create_makefile` で指定した名前から自動的に決まる。
4. `$ ruby extconf.rb` を実行して、Makefile を生成する。
5. `$ make` を実行し、`array_second.so` をビルドする。できれば、これを `require` で使うことができる。例えば、`$ ruby -r ./array_second -e 'p [1, 2].second'` は 2 を出力する。
6. `$ make install` とすれば、インストールディレクトリに .so がコピーされる。

4 で起動した ruby 用の拡張ライブラリを作成します。前節までで拡張していた Ruby 用に拡張ライブラリを作成するためには、`workdir/install/bin/ruby extconf.rb` のように、インストールした Ruby インタプリタを指定してください。

`array_second` は、このリポジトリにも存在するので参照してください。

`extconf.rb` や別途ビルド・インストールのくだりを除けば Ruby の組み込みメソッドは拡張ライブラリと記述方法がまったく同じです。

拡張ライブラリを配布するためには 2, 3 で作成したファイルをまとめて配布します。ただ、RubyGems パッケージとして配布する方が利用者には便利でしょう。

## Tips: 開発のヒント

https://docs.ruby-lang.org/en/2.4.0/extension_ja_rdoc.html に詳細説明があるのでチェックしましょう。

MRI のソースコードを検索し、似たようなことをやっているメソッドを探しましょう。

Ruby プログラムを書くときは、`p(obj)` メソッドを利用することがあると思います。
C では `rb_p(obj)` とすることで、同様に出力することができます。

gdb が使えるようでしたら、ブレイクポイントを指定して `$ make gdb` を使って実行すると、処理を確認することができます（`./miniruby $(srcdir)/test.rb` を gdb 上で実行します）。このとき、C のファイル中で `#include "vm_debug.h"` とすることで、`bp()` というマクロが使えるようになります。この `bp()` が埋め込まれたところはブレイクポイントとして最初から登録されているため、気になるところに `bp()` を置くと便利かもしれません（つまり、`binding.pry` のように使えます）。

gdb では、`p expr` とすることで、`expr` の値を示すことができます（例えば、変数 `foo` の値を表示したいときは、`p foo`）。`VALUE obj` の値を表示すると、`obj` のクラスにかかわらず、数字が表示されます。これは見づらいので、`rp` という gdb 用のコマンドが定義されています（`ruby/.gdbinit` で定義）。このコマンドを使うと、見やすく整形して出力してくれます。

## 発展演習

次のトピックを、実際に解決してみてください。似たような実装を MRI のソースコードを grep して探してみてください。

* 引き算を行う `Integer#sub(n)` を実装してみてください。
* `Array#second` は、要素数が 1 個以下の場合は `nil` を返します。というのも、`rb_ary_entry()` は、存在しない要素インデックスが指定されると `nil`（`Qnil`）を返すためです。そこで、2要素目がない場合は例外を発生するようにしてみてください。`rb_raise()` という関数を利用します。
* `String#palindrome?` は、非効率な実装になっています。どこが非効率であり、どのように解決できるか検討してみてください。また、可能なら性能を改善するように実装を変更してみてください。
* `Time#day_before` は名前が微妙です。良い名前を考えてみてください。
* MRI にいたずらしてみましょう。
  * `p` メソッドの出力を、ちょっと変えてみましょう。例えば、`p true` の結果を `p> true` としてみるのはどうでしょうか。
  * 起動したら、すぐに終了するようにしてみましょう。
  * GC の処理が行われたら、何か表示するようにしてみましょう。
  * `Integer#+` の結果を、足し算ではなく、引き算した結果になるようにしてください。git の新しいブランチで実行するといいですよ。
    * 実は（高速化のための複雑化のために）とっても難しいです。
    * `numeric.c` に加えて、`insns.def` というファイルも見て下さい。
* 想像力をたくましくして、好きなメソッドを追加してみましょう。

次の章で扱いますが、

* `Time#day_before` の実装の問題点を `Integer#add(n)` と同様に考えてみてください。
* `Integer#add(n)` にはバグがあると言いました。どのようなバグがあるでしょうか。また、どのように解決できるでしょうか。
  * まずは失敗するテストを書きましょう。
  * 問題を解決し、テストが通ることを確認しましょう。
