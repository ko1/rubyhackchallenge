# (8) Ruby::Box を触ってみよう

## この資料について

`Ruby::Box` は、**1 つのプロセスの中で、クラス・モジュールの定義を分ける**ための仕組みです。Ruby 4.0 で入った experimental な機能です [[Feature #21311]](https://bugs.ruby-lang.org/issues/21311)。

[(7) Ractor を触ってみよう](7_ractor.md) と並べると分かりやすいかもしれません。

* Ractor は、**状態（オブジェクト）** を分けます。
* Box は、**定義（クラス・モジュール・定数）** を分けます。

どちらも experimental で、どちらも「使ってみた人の報告」が一番足りていないものです。

この資料中の実行例は、`ruby 4.1.0dev (2026-09-14T04:56:14Z master d568c61094)` で確認しています。

## 準備

Box は、**ruby の起動時に環境変数 `RUBY_BOX=1` が設定されていないと使えません**（プログラムが始まってから設定しても効きません）。

```
$ RUBY_BOX=1 ./ruby -W:no-experimental box.rb
```

設定を忘れると、こうなります。

```ruby
p Ruby::Box.enabled?   #=> false
Ruby::Box.new
#=> Ruby Box is disabled. Set RUBY_BOX=1 environment variable to use Ruby::Box. (RuntimeError)
```

`RUBY_BOX=1` を付けると、起動時に experimental の警告が出ます。`-W:no-experimental` で消せます。

```
ruby: warning: Ruby::Box is experimental, and the behavior may change in the future!
See https://docs.ruby-lang.org/en/master/Ruby/Box.html for known issues, etc.
```

## 何が嬉しいのか

Ruby では、アプリケーションも、読み込んだライブラリも、モンキーパッチも、**すべて同じ場所（1 つのクラス・定数の空間）** に定義されます。便利な半面、

* 同じ名前のクラスを持つライブラリを、2 つ同時には使えません。
* あるライブラリが当てたモンキーパッチは、アプリケーション全体に効いてしまいます。
* ライブラリ A が依存する gem のバージョンと、ライブラリ B が依存するバージョンが違うと、片方が壊れます。

Box は、**読み込んだファイルが定義したクラス・モジュール・定数を、その box の中だけのものにします**。

## 演習 1: ライブラリを box に読み込む

`lib_a.rb`:

```ruby
VERSION = "1.0"

class Greeter
  def hello = "hello from #{VERSION}"
end
```

`main.rb`:

```ruby
VERSION = "main"

box = Ruby::Box.new
box.require_relative("lib_a")

p VERSION            #=> "main"
p box::VERSION       #=> "1.0"
p box::Greeter.new.hello  #=> "hello from 1.0"
```

```
$ RUBY_BOX=1 ./ruby -W:no-experimental main.rb
"main"
"1.0"
"hello from 1.0"
```

* `Ruby::Box.new` で box を作り、`box.require` / `box.require_relative` / `box.load` でファイルを読み込みます。読み込んだファイルがさらに `require` したものも、同じ box に入ります。
* box の中の定数やクラスは、`box::VERSION`、`box::Greeter` のように box 越しに参照します。
* box の中で動くメソッドは、**box の中の定義**を見ます（`Greeter#hello` が見ている `VERSION` は `"1.0"` のほうです）。

## 演習 2: モンキーパッチを閉じ込める

`box.eval` を使うと、ファイルを作らずに box の中でコードを実行できます。

```ruby
box = Ruby::Box.new
box.eval(<<~RUBY)
  class String
    def shout = upcase + "!"
  end
RUBY

p box.eval(%q{"hi".shout})   #=> "HI!"
p "hi".respond_to?(:shout)   #=> false
"hi".shout                   #=> undefined method 'shout' for an instance of String (NoMethodError)
```

`String` への変更が、box の外に漏れていません。「このライブラリのモンキーパッチだけ閉じ込めたい」がそのまま書けます。

## 演習 3: 同じライブラリの別バージョンを同時に使う

Box が一番効くのはこれです。互換性のない 2 つのバージョンを、1 つのプロセスで同時に使ってみましょう。

`v1/lib.rb`:

```ruby
class Lib
  VERSION = "1.0"
  def self.calc(n) = n * 2
end
```

`v2/lib.rb`:

```ruby
class Lib
  VERSION = "2.0"
  def self.calc(n) = n * 3     # 非互換な変更
end
```

`two.rb`:

```ruby
b1 = Ruby::Box.new
b2 = Ruby::Box.new
b1.require_relative("v1/lib")
b2.require_relative("v2/lib")

p [b1::Lib::VERSION, b1::Lib.calc(10)]  #=> ["1.0", 20]
p [b2::Lib::VERSION, b2::Lib.calc(10)]  #=> ["2.0", 30]
p b1::Lib.equal?(b2::Lib)               #=> false （別のクラスです）
p defined?(Lib)                         #=> nil   （外には定義されていません）
```

同じ名前の `Lib` クラスが 2 つ、別物として共存しています。box の外には `Lib` がそもそも存在しません。

## Box の種類

書くときに意識するのは 2 つだけです。

* **main**: `ruby foo.rb` の `foo.rb` が動く box。起動時に自動で作られます。
* **optional**: `Ruby::Box.new` で作る box。main と技術的には同じものです。

```ruby
p Ruby::Box.enabled?          #=> true
p Ruby::Box.current           #=> #<Ruby::Box:3,user,main>
p Ruby::Box.current.main?     #=> true
p Ruby::Box.new.main?         #=> false
```

`box.inspect` の末尾（`#<Ruby::Box:4,user,optional>` の `optional` の部分）が、その box の種類です。

> Note: 実装にはもう 2 つ、**root**（組み込みのクラス・モジュールが定義され、動く場所。プロセスに 1 つ）と **master**（すべての box の元になる「原本」。ここではコードは動きません）があります。使う側が気にすることは、まずありません。

`Ruby::Box` のメソッドは、これだけです。

* クラスメソッド: `enabled?`、`current`、`main`、`root`、`master`
* インスタンスメソッド: `require`、`require_relative`、`load`、`eval`、`load_path`、`main?`、`root?`、`master?`、`inspect`

`box.load_path` は、その box 用の `$LOAD_PATH` です（外側の `$LOAD_PATH` とは別のオブジェクトです）。

## 今できないこと

experimental なので、まだ動かないところがあります。[`doc/language/box.md`](https://github.com/ruby/ruby/blob/master/doc/language/box.md) の "Known issues" に挙がっているのは、

* `RUBY_BOX=1` が要る（デフォルトでは無効）
* `RUBY_BOX=1` のもとでは、`extconf.rb` が stack level too deep になって native 拡張のインストールが失敗することがある
* `require 'active_support/core_ext'` が失敗することがある
* box の中で定義したメソッドが、Ruby で書かれた組み込みメソッドから見えないことがある

手元で試して分かったものも 1 つ。**非メイン Ractor の中では box を作れません。**

```ruby
Ractor.new { Ruby::Box.new }.value
#=> can not set constants of classes/modules created by another Ractor (Ractor::IsolationError)
```

一方、**メインの Ractor で作った box を Ractor に渡して使うことはできます**。

```ruby
box = Ruby::Box.new
box.eval("class Worker; def self.work(n) = n * 2; end")

r = Ractor.new(box) {|box| box::Worker.work(21) }
p r.value  #=> 42
```

この種の「どこまで動くか」は、試した人にしか分かりません。動かないものを見つけたら、それは報告する価値があります。

## 実装を覗いてみる

| ファイル | 中身 |
|---|---|
| `box.c` | Box の本体（1300 行ほど）。`Ruby::Box` のメソッドはここです |
| `internal/box.h` | データ構造の定義 |
| `load.c` | `require` / `load` を box ごとに行うための対応 |
| `variable.c`, `class.c`, `vm.c`, `proc.c` | 定数の参照、クラス定義、メソッド探索の側の対応 |
| `test/ruby/test_box.rb` | テスト（1500 行ほど）。**いま何がどこまで動くのか、一番正確に書いてある場所**です |
| [`doc/language/box.md`](https://github.com/ruby/ruby/blob/master/doc/language/box.md) | 設計ドキュメント。Known issues と TODO も載っています |

## 発展課題

* 自分が普段使っている gem を box に入れて `require` してみる。動いたら儲けもの、動かなかったら**何が起きたかを報告する**（いまは、これが一番価値のある貢献です）。
* `doc/language/box.md` の TODO を 1 つ選んで手を付けてみる。
* `test/ruby/test_box.rb` を読んで、書かれていない挙動を見つけ、テストを足す。
* Box と Ractor を組み合わせて、どこまでできるか探る。「box ごとに Ractor を立てる」は書けるでしょうか。
