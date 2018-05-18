# (6) コードカバレッジの測定

## この資料について

この資料では、MRI のコードカバレッジを測定し、テストを追加する方法を紹介します。

まずコードカバレッジについてごく簡単に説明し、それから MRI のコードカバレッジのとり方を説明します。
最後に、MRI でコードカバレッジを参考にテストを拡充していく方法を説明します。

## コードカバレッジとは

[コードカバレッジ](https://ja.wikipedia.org/wiki/%E3%82%B3%E3%83%BC%E3%83%89%E7%B6%B2%E7%BE%85%E7%8E%87)とは、テストを評価・分析するための指標です。プログラムを関数、行、分岐などの「単位」で区切り、テスト実行中にそれぞれの「単位」が実行されたかどうかを記録したデータのことで、これを分析することで、プログラムのどの「単位」がテストされていないか、どのあたりのモジュールのテストが手薄か、などを把握する材料になります（コードカバレッジの定義をより正確に言うと、「全単位中、いくつの単位が実行されたか」を表す割合の数値なのですが、ここでは「各単位が実行されたかどうかのデータ」を指すことにします）。

コードカバレッジについてもっと知りたければ、[wikipedia の記事](https://ja.wikipedia.org/wiki/%E3%82%B3%E3%83%BC%E3%83%89%E7%B6%B2%E7%BE%85%E7%8E%87)や、[遠藤の RubyKaigi 2017 での発表資料](https://www.slideshare.net/mametter/an-introduction-and-future-of-ruby-coverage-library)、よりきちんと知りたければ教科書（[『ソフトウェア・テストの技法』](https://www.amazon.co.jp/dp/4764903296)や ["Advanced Software Testing"](https://www.amazon.co.jp/dp/B00V7B1NYI/) 、オンラインで読めるドキュメントなら ["Code Coverage Analysis"](http://www.bullseye.com/coverage.html) など）を参照してください。

カバレッジの可視化例を見てみましょう。次の URL を開いてください。

https://rubyci.s3.amazonaws.com/debian8-coverage/ruby-trunk/lcov/index.html

ここには、MRI のカバレッジ測定・可視化を定期実行した最新の結果が置かれています。たとえば、"ruby" というディレクトリを辿り、その中の ["array.c"](https://rubyci.s3.amazonaws.com/debian8-coverage/ruby-trunk/lcov/ruby/array.c.gcov.html) というファイルを開いてみて下さい。

各行のコードのすぐ右に書かれている数値が実行回数です。実行回数が 1 回以上の行は青く、0 回の行は赤く表示されています（白い行は、空行やコメントや記号だけなど、実行の意味を持たない行）。ほとんどの行は白か青で、ときどき赤い行があるのが確認できると思います。ごく単純に言うと、これを見て赤い行を青くするように、テストを拡充していきます（あとで述べますが、実際には、もうちょっと慎重な検討をするべきです）。このように、行単位で計測したカバレッジを行カバレッジ（ラインカバレッジ、ステートメントカバレッジなどとも）と呼びます。

また、同じページで、実行回数よりも右に青や赤で色づいた `[ + - ]` のような表示は、分岐のカバレッジを表しています。両方向に実行が進んでいたら青だけで `[ + + ]` 、片方だけの場合は青と赤で `[ + - ]` 、その分岐に到達していなかったら赤だけで `[ - - ]` となります。

それから、画面一番上の ["functions" というリンク](https://rubyci.s3.amazonaws.com/debian8-coverage/ruby-trunk/lcov/ruby/array.c.func-sort-c.html)をたどると、関数カバレッジが確認できます。これは、各関数の呼ばれたが何回を昇順に並べたものです。

## MRI のコードカバレッジ

### MRI のコードカバレッジとは

ひとくちに MRI のコードカバレッジと言っても、2 種類あることを意識する必要があります。
すなわち、C 言語で書かれた部分（コアと、いくつかの拡張ライブラリ）のコードカバレッジと、Ruby で書かれた部分（拡張ライブラリ以外の標準添付ライブラリ）のコードカバレッジです。
前者は C 言語用のカバレッジ測定ツールを用いて測定し、後者は Ruby 用のカバレッジ測定ツールを用いて測定します。

MRI の Makefile には、それぞれのカバレッジを測定し、合算した上で可視化する機能が備わっています。この機能の使い方を説明していきます。

### C 言語部分のコードカバレッジ測定

MRI の Makefile に用意されているコードカバレッジ測定・可視化の仕組みは、gcov と lcov を利用しています。gcov は gcc に付属するコードカバレッジ測定ツールで、lcov は gcov の測定結果を HTML で可視化するツールです。現時点では clang でのコードカバレッジ測定は未対応です（貢献チャンス）。

gcov は通常、gcc とあわせてインストールされますが、lcov は別途インストールする必要があります。apt-get が使える環境では、下記のようなコマンドでインストールできます。

```
$ sudo apt-get install lcov
```

これで環境設定が完了です。つぎに、実際に測定する方法を説明します。

コアと、いくつかの拡張ライブラリなど、C 言語で書かれたコードのカバレッジを測定するには、`configure` に `--enable-gcov` オプションを与えてビルドする必要があります。なお、`configure` の `--enable-shared` オプションは `--enable-gcov` と相性が悪いので、いまのところ与えないでください。

```
$ ../ruby/configure --prefix=$PWD/../install --enable-gcov
$ make -j
$ make test-all
```

`make btest` や `make test-spec` もお好みで実行してください。

ここまで実行すると、拡張子が `.gcda` や `.gcno` のファイルがたくさんできているはずです。`.gcda` はカバレッジ測定単位ごとのカウンタ、すなわち実行回数を記録したもので、`.gcno` はカバレッジ測定単位とコード中の位置の対応付けを持つファイルです。

これを人間に理解できるようにするには、`make lcov` コマンドを実行します。

```
$ make lcov
```

これで lcov-c-out/index.html に HTML が生成されました。これを開けばカバレッジが見えるはず。

### Ruby 部分のコードカバレッジ測定

標準ライブラリのコードカバレッジを測定するには、まず simplecov をインストールする必要があります。これは `make update-coverage` で勝手にやってくれます。また、測定自体は `make test-all` に `COVERAGE=true` というオプションを与えます。なお、test-all 以外のテストで Ruby 部分のコードカバレッジを測定することは未対応です（貢献チャンス）。
まとめると、次のように実行します。

```
$ ../ruby/configure --prefix=$PWD/../install
$ make update-coverage
$ make -j
$ make test-all COVERAGE=true
```

測定結果は、coverage/index.html に HTML が生成されています。

このとき、Ruby 部分のコードカバレッジ情報は test-coverage.dat というファイルにも保存されています。これを lcov で可視化することもできます。C 言語のときと同じ `make lcov` を実行してください。

```
$ make lcov
```

これで lcov-rb-out/index.html が生成されるはずです。見方は C 言語と同じです。

### C 言語部分と Ruby 部分のコードカバレッジを同時に測定

単純に、`configure` に `--enable-gcov` を与えつつ `make test-all` に `COVERAGE=true` を与えれば、両方あわせて測定できます。

```
$ ../ruby/configure --prefix=$PWD/../install --enable-gcov
$ make -j
$ make test-all COVERAGE=true
...

Finished tests in 774.821741s, 25.3052 tests/s, 2936.0586 assertions/s.                                 
19607 tests, 2274922 assertions, 0 failures, 1 errors, 96 skips

ruby -v: ruby 2.6.0dev (2018-04-04 trunk 63088) [x86_64-linux]
Coverage report generated for Ruby's `make test-all` to /home/mame/work/ruby.build/coverage. 3581 / 3944 LOC (90.8%) covered.
```

また、Ruby 部分のコードカバレッジは、HTML だけでなく `test-coverage.dat` というファイルにも保存されています。`make lcov` は `test-coverage.dat` があったら、gcov で測定した結果と合算した上で可視化するようになっています。

```
$ make lcov
```

これで、lcov-out/index.html が生成されます。C 言語のコードと Ruby のコードのカバレッジが両方含まれているのがわかると思います。冒頭で紹介した [CI でのコードカバレッジ測定結果](https://rubyci.s3.amazonaws.com/debian8-coverage/ruby-trunk/lcov/index.html) は、この結果をアップロードしています。


## コードカバレッジを見てテストを改善する

手元でカバレッジを確認できるようになったので、次はコードカバレッジを上げてみましょう。基本的なやり方は次のとおりです。

1. コードカバレッジを見て、実行されていないコード（赤い行）を見つける
2. そのコードを実行するようなテストを書いて、実行されるようにする（青い行にする）

ただ、あまり安易にやりすぎると、意図がわからないテストになったり、環境依存なテストになったり、CI に悪影響があったりします。極端な例では、メモリ不足に動くコードをテストするために、実際にメモリを使い尽くすようなテストは、現状の `make test-all` の中に入れることは想定されていません。そのようなテストに意味がないわけではありませんが、`make test-all` 以外の仕組みを作って行うべきでしょう。コードカバレッジを上げることは目的ではなく、テストの質を高めることが目的であることを忘れないようにしましょう。

また、「なぜテストされていないのか」を考えることも重要です。最近新しく実装されたコードであれば、単純にテストが不足している可能性が高いです。しかし、昔からあるコードなのにテストされていない場合は、何か事情があるかもしれません。典型的なのは、特定のプラットフォームでしか使われないコードです（この場合、テストを書くのは難しいでしょう）。条件分岐が冗長になっていたり、すでに使われないコードになっていたりするなど、コードの方に問題がある場合もあります（この場合、テストを書く以外に、リファクタリングも検討すべきです）。

### `Array#second` のコードカバレッジを測定する

さて、3 章で紹介した `Array#second` を実装した状態で、コードカバレッジを測定してみましょう。

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

↑のパッチをあてて、C 言語部分のコードカバレッジを測定してみましょう。

```
$ ../ruby/configure --prefix=$PWD/../install --enable-gcov
$ make -j
$ make test-all
$ make lcov
```

... を開いて、ruby/ ディレクトリ→ array.c のカバレッジ、と進み、`ary_second` のところを探します。

![図1](9_coverage_fig1.png)

このように、赤くなっています。まだ `Array#second` のテストを書いてないのだから、当たり前です。

### Ruby のテストの構成

2 章で触れたとおり、Ruby には 3 種類のテストがあります。それぞれ簡単に説明します。

1 つめは `make btest` で実行されるものです。Ruby の VM をテストすることに特化しています。失敗したら SEGV のように致命的な問題が起きるテストが書かれています。1 つのテストを実行するたびにインタプリタを立ち上げ直すことで、そのような問題を扱いやすくする工夫がなされています。

2 つめは `make test-all` で実行されるものです。組み込みクラスから標準ライブラリまでを幅広くテスト対象としています。テストファイルは ruby/test 以下に置かれています。特に、コア本体に対するテストは ruby/test/ruby にあります。テストは minitest という、比較的シンプルなテストフレームワークを使って記述されています。

3 つめは、`make test-spec` で実行されるものです。これは元々 rubyspec と呼ばれていたプロジェクトで、複数の Ruby インタプリタ間の互換性を検証する目的で作られています。rubyspec は https://github.com/ruby/spec という別リポジトリが upstream となっています。

### `Array#second` のテストを追加する

それでは、`Array#second` のテストを書いてみましょう。`Array#second` は VM の機能ではないので、`make test-all` か `make test-spec` のどちらかに追加します。今回は、`make test-all` の方に追加することにします（執筆者が test-spec の流儀にあまり詳しくないので）。

テストを追加するときは、似たようなテストを探すところから始めるとよいでしょう。今回は、`Array#first` のテストを探します。組み込みクラスのテストは ruby/test/ruby 以下にあるので、そこから git grep してみます。

```
$ git grep -w first test/ruby
...
test/ruby/test_array.rb:    assert_equal(1, x.first)
test/ruby/test_array.rb:    assert_equal([1], x.first(1))
test/ruby/test_array.rb:    assert_equal([1, 2, 3], x.first(3))
test/ruby/test_array.rb:    assert_equal(3,   @cls[3, 4, 5].first)
test/ruby/test_array.rb:    assert_equal(nil, @cls[].first)
...
```

`-w` オプションは word 単位の検索です。"first" の前後が記号や空白などで、単語区切りになっている場合のみヒットします。"headfirst" にはヒットしません。

どうやら `test/ruby/test_array.rb` が Array クラスのテストのようです。ファイルを開いて見てみます。

```
  def test_first
    assert_equal(3,   @cls[3, 4, 5].first)
    assert_equal(nil, @cls[].first)
  end
```

かんたんですね。これを真似して書き足しましょう。次のテストを `test_first` メソッドの後ろあたりに書きます。

```
  def test_second
    assert_equal(4,   @cls[3, 4, 5].second)
    assert_equal(nil, @cls[].second)
  end
```

その上で、再度テストを実行します。`test/ruby/test_array.rb` だけ実行すればよいので、次のように実行します。

```
$ make test-all TESTS='ruby/test_array.rb'
Run options: "--ruby=./miniruby -I../ruby/lib -I. -I.ext/common  ../ruby/tool/runruby.rb --extout=.ext  -- --disable-gems" --excludes-dir=../ruby/test/excludes --name=!/memory_leak/

# Running tests:

Finished tests in 3.994787s, 47.0613 tests/s, 3109.0522 assertions/s.   
188 tests, 12420 assertions, 0 failures, 0 errors, 0 skips

ruby -v: ruby 2.6.0dev (2018-04-05 trunk 63097) [x86_64-linux]
```

無事テストは成功しました。lcov でカバレッジを確かめてみましょう。

```
$ make lcov
```

coverage/index.html を開き、ruby → array.c のカバレッジを開いて、`ary_second` 関数を確認します。

![図2](9_coverage_fig1.png)

無事青くなりました。きちんとテストできていることが確認できて、安心できますね。

### 注意点

* コンパイル後に C 言語コードを変更した場合、すべての再コンパイルが必要です。

本文で示した例は、Ruby でテストコードを書き足しただけだったので、問題なく再実行できました。

しかし、C 言語コードを変更してテスト実行すると、再コンパイルが起きます。そうすると、実行不回数を保持する .gcda ファイルと、ソースコードの対応をつなぐ .gcno ファイルに一貫性がなくなってしまい、gcov や lcov がうまく動かない場合があります。

たとえば array.c を編集した場合は、array.gcdea と array.gcno を削除した上で `make` と `make test-all` を実行することで、array.c に関してゼロから測定し直すことができるようです（ただし、array.c が `#include` している別ソースコードの測定は異常になる可能性があります）。それでもうまくいかない場合は、すべてを消してビルドし直すのが（少し面倒ですが）確実です。

* 試行錯誤はカバレッジ測定なしでやるとよいです。

現代では、MRI のテストの品質はわりとよいです（遠藤がテストを書き足したり、ruby/spec というプロジェクトが取り込まれたりしたため）。

よって、いまだに未テストの箇所を実行するテストを書くのは、それほど容易ではないかもしれません。printf などを挟みながら、いろいろな入力を試行錯誤して未テストの箇所に到達していく必要があるでしょう（デバッガを使えば良いのですが、遠藤は gcov と gdb を組み合わせて使ったことがないのでよくわかりません）。

これをカバレッジ測定下でやるためには、.gcda や .gcno の削除をする必要があり、トラブルが生じやすいです。遠藤のベストプラクティスとしては、別ディレクトリで `--enable-gcov` なしでビルドしたディレクトリでテスト作成を行い、最終的にまたカバレッジ測定を使ってその箇所が実行されることを確認するという方法です。より良い方法があれば、ぜひ共有してください。

また、C 言語コード部分のテストは入念に行われていますが、一部の標準添付ライブラリについては十分にテストされていないものもあります。そちらの方をターゲットとして取り組んでみるのもよいでしょう。
