# (2) MRI ソースコードの構造

## この資料について

MRI のソースコードの構造について紹介します。また、Ruby のソースコードをハックする最低限の知識を紹介します。

* 演習: MRI のソースコードを clone
* 演習: MRI のビルド、およびインストール
* LLM・コーディングエージェントの使いどころ
* MRI の構造の紹介
* 演習: ビルドした Ruby でプログラムを実行
* 演習： バージョン表記を変更してみよう

## 本稿で前提とするディレクトリ構造

下記のコマンドは、Linux や Mac OSX などを前提としています。Windows 等を使う場合は、別途頑張ってください。

> Note: ビルドに必要なパッケージを入れた Docker 環境の例が、このリポジトリの [`docker/`](../docker/) にあります（`docker build -f docker/Dockerfile.noble .`）。手元の環境を汚したくない場合にどうぞ。

前提とするディレクトリ構造:

* `workdir/`
  * `ruby/` <- git clone するディレクトリ
  * `build/` <- ビルドディレクトリ（ここに、コンパイルした `*.o` などが入る）
  * `install/` <- インストールディレクトリ (`workdir/install/bin/ruby` がインストールされたディレクトリになります）

前提とするコマンド：

git、ruby、autoconf、gcc (or clang, etc）、make が必須です。その他、依存ライブラリがあれば、拡張ライブラリが作成されます。

ruby が必要なのは、ビルド中にソースコードを生成するツールが Ruby で書かれているためです（`BASERUBY` と呼ばれます）。ある程度新しい ruby（現時点では 3.1 以降）が必要なので、OS 添付の ruby が古い場合は、rbenv などで入れたものを使ってください。

`apt-get` が使える環境では、下記のようなコマンドでインストールされます。

```
$ sudo apt-get install git ruby autoconf gcc make zlib1g-dev libffi-dev libreadline-dev libgdbm-dev libssl-dev libyaml-dev
```

`apt-get` 以外でインストールしたい場合は、例えば [Home · rbenv/ruby\-build Wiki](https://github.com/rbenv/ruby-build/wiki) を参照してみてください。

> Note: Ruby には YJIT と ZJIT という 2 つの JIT コンパイラがあり、これらは Rust で書かれています。`rustc` があれば自動的に一緒にビルドされます（YJIT は rustc 1.58 以降、ZJIT は 1.85 以降が必要）。無くてもビルドは通り、JIT 無しの ruby ができます。明示的に外したい場合は `configure` に `--disable-yjit --disable-zjit` を指定してください。

> Note: 依存関係の最新の情報は、ソースコード中の [`doc/contributing/building_ruby.md`](https://github.com/ruby/ruby/blob/master/doc/contributing/building_ruby.md) にあります。

## 演習: MRI のソースコードを clone

1. `$ mkdir workdir`
2. `$ cd workdir`
3. `$ git clone https://github.com/ruby/ruby.git` # workdir/ruby にソースコードが clone されます

（ネットワーク帯域の問題があるので、できれば家などで行ってきてください）

## 演習: MRI のビルド、およびインストール

1. 上記「前提とするコマンド」を確認
2. `$ cd workdir/` # workdir に移動します
3. `$ cd ruby` # workdir/ruby に移動します
4. `$ ./autogen.sh`
5. `$ cd ..`
6. `$ mkdir build` # `workdir/build` を作成します
7. `$ cd build`
8. `$ ../ruby/configure --prefix=$PWD/../install --enable-shared`
  * `prefix` は、インストールする先のディレクトリです。絶対パスで、好きな場所を指定してください（この例では `workdir/install`）
  * Homebrew で諸々インストールしている場合は、 ```--with-openssl-dir=`brew --prefix openssl` --with-readline-dir=`brew --prefix readline` --disable-libedit``` を付けてください。
  * `-C`（`--config-cache`）を付けておくと、2 回目以降の `configure` が速くなります。
  * デバッグしながらハックするなら、最適化を切り、デバッグ用のコードを有効にしたビルドが便利です: `cppflags="-DRUBY_DEBUG=1" --enable-debug-env optflags="-O0 -fno-omit-frame-pointer"`（`RUBY_DEBUG=1` を付けると assertion などが有効になり、バグに早く気づけます）。
9. `$ make -j` # ビルドします。`-j` は並列にコンパイルなどを行うオプションです。
  * この時点で、`ruby` コマンドと `miniruby` コマンドが `workdir/build` にできているはずです。
  * また、`.ext/` に拡張ライブラリが格納されています。 
10. `$ make install`
  * この時点で、`../install`、つまり `workdir/install` に諸々インストールされます。実際に何が入っているか確認してみましょう。
  * > tips: `make install-nodoc` とすると、rdoc/ri ドキュメントのインストールをスキップします
11. `$ ../install/bin/ruby -v` で、Ruby がインストールされたことを確認してください（`ruby -v` はバージョンを出力して終了します）

> NOTE: `make V=1` とすると、`make` コマンドが具体的にどのようなコマンドを実行しているかを表示します。デフォルト（`V=0`）では、これらの表示を抑制しています。

> NOTE: `make -j` とすると、コンパイルなどのプロセスが並列に実行され、高速に終了する可能性があります。`make -j4` など、数字を置くことで、並列に実行するプロセス数を抑えることができます。

上記手順では、主に次のことをしています。

* `autoreconf` による `configure` スクリプトの生成
* `configure` による `Makefile` の生成
* `make` による `./ruby` の生成（`make` 単体での実行は `make all` の意味になります）。これは、いくつかの生成が含まれています。
  * `make miniruby` による `./miniruby` の生成
  * `make encs` によるエンコーディング関連拡張ライブラリの生成
  * `make exts` による拡張ライブラリの生成
  * `make ruby` による `./ruby` の生成
  * `make docs` による rdoc の生成
* `make install` によるインストールディレクトリの生成

なお、この 2 回の `make` については、`make all install` とすると、1回の呼び出しで終わります。

### 久しぶりに実行したビルドでエラーが起こる場合

以前にRubyを上記の方法でビルドしたことがある場合、 `make` コマンドが失敗する可能性があります。
その場合は、

```
make clean
```

を実行して古いファイル・ディレクトリを削除してから再度 `make` コマンドを実行してみてください。

それでも失敗する場合は、

```
make distclean
```

でconfigureからやり直すとうまくいく可能性があります。

## LLM・コーディングエージェントを使い倒しましょう

MRI のハックは、「C 言語」「巨大なソースコード」「独特の作法」という三重の壁があって、昔は最初の一歩までが大変でした。いまは LLM（コーディングエージェント）があるので、**その壁はだいぶ低くなっています。遠慮なく使ってください。**

この資料も、皆さんにビルドで消耗してもらうために書いているわけではありません。「Ruby のソースコードを clone してビルドして」と頼めば、そこまでやってくれることも多いでしょう。それで先に進めるなら、それが一番です。

とくに効くのは、次のような場面です。

* **ビルドを通す**：ビルドエラーの大半は環境依存の問題（ライブラリが足りない、バージョンが古い、Homebrew の場所が違う……）です。実行したコマンドとエラーメッセージを、OS とバージョンを添えてそのまま貼れば、たいてい当たりを付けてくれます。
* **ソースコードの道案内**：「`rb_ary_entry()` は何をする関数？」「この関数はどこから呼ばれる？」「`rb_control_frame_t` のこのフィールドは何？」。全体を把握していなくても、読む場所の当たりが速くつきます。
* **MRI の作法を教えてもらう**：`rb_define_method()` の最後の引数の意味、`VALUE` と C の値の変換（`INT2NUM` / `NUM2INT` など）、`rb_scan_args()` の書式、例外の上げ方。この手の「知っていれば一瞬、知らないと 30 分」という知識は、聞くのが一番速いです。
* **デバッガの使い方**：gdb / lldb のコマンド、バックトレースの読み方、ブレイクポイントの張り方。`[BUG]` のログを丸ごと貼って「これはどう読む？」と聞くのも有効です（[(4) バグの修正](4_bug.md) でやります）。
* **テストを書く**：どのファイルに、どの流儀で書くか（`bootstraptest/`、`test/`、`spec/` の使い分け）。
* **パッチのたたき台**：「`Array#second` を C で書いて」と頼んで、出てきたものを**自分で読んで直す**。ゼロから書くより速く、しかも「なぜそう書くのか」を考える材料になります。
* **英語**：チケットの本文、コミットメッセージ、Pull Request の説明。英語が理由で報告をためらうくらいなら、書いてもらって、内容を自分で確認して出しましょう。

### ただし、「確かめる」のは自分の仕事です

LLM は、存在しない `configure` のオプションや C の API を、もっともらしく答えることがあります。MRI は内部 API がよく変わるので、学習した時点の古い情報を答えることもあります。そこで、**答えを鵜呑みにせず、手元で確かめる**習慣が大事になります。幸い、確かめる道具はこの資料で全部紹介します。

* 関数や API が本当にあるかは `grep` で確認できます（例: `$ grep -rn "rb_ary_entry" *.c *.h`）。
* 「本当にそう動くのか」は、`printf` を入れて `make run`、あるいは gdb で止めて見れば分かります。
* 「直ったのか」は、テスト（`make test-all` など）が答えます。

MRI をハックする面白さは、**中で何が起きているかを、推測ではなく自分の目で確かめられる**ことにあります。LLM は、そこへ辿り着くまでの時間を短くしてくれる、とても良い道具です。両方使いましょう。

> Note: 出来上がったパッチを Redmine や Pull Request に出すときは、自分で内容を理解し、テストを通してから出してください。AI を使って書いたこと自体は、まったく問題ありません。ただ、自分でも読んでいないコードをレビューしてもらうのは、相手の時間の使い方としてもったいないです。

## 演習：ビルドした Ruby でプログラムを実行してみよう

ビルドした Ruby で実際に Ruby スクリプトを実行する方法はいくつかあります。

一番わかりやすい方法は、上記手順でインストールまで終わらせ、インストールした Ruby を利用して実行することです（この例では、`workdir/install/bin/ruby`）。「いつも Ruby を使っている方法」と全く同じです。ですが、Ruby を修正するたびに Ruby のインストールまで行うと、若干時間がかかります（マシンによりますが、`make install` が終わるまでに数十秒かかります）。

ここでは、それ以外の、Ruby を修正・確認するときに便利な実行方法を紹介します。

### miniruby で実行しよう

Ruby のビルドが終わると、ビルドディレクトリ（`workdir/build`）に、`miniruby` という実行ファイルが生成されます。`miniruby` は、Ruby のビルドするために作られる、機能制限版の Ruby インタプリタです。ただ、制限といっても、拡張ライブラリを読み込むことができない、エンコーディングに制約がある、といったものであり、Ruby の機能のほとんどをサポートしています。

`miniruby` は、Ruby のビルドの初期段階で生成されるため、MRIの修正を行い、その結果を確認するためには、`miniruby` を実行して修正結果を確認するのが良いです。つまり、

1. MRI のソースコードを修正する
2. `make miniruby` として、`./miniruby` を生成する（すべてビルドしてインストールするよりも速く終わる）
3. 修正に関係あるスクリプト `workdir/build/script.rb` を `./miniruby script.rb` で実行する

という流れで開発を進めると効率的です。

この流れを行うために、`make run` という make のルールがあります。これを行うと `miniruby` をビルドし、`workdir/ruby/test.rb` （ソースディレクトリであることに注意）に書かれた内容を実行します。

つまり、下記のように進められます。

1. Ruby のソースコードを修正する。
2. `ruby/test.rb` に、修正に関係した Ruby スクリプトを記述する（`miniruby` では、gem や拡張ライブラリは使えないので注意）。
3. ビルドディレクトリ（`workdir/build`）で `$ make run` を実行する。

`make miniruby` で `./miniruby` を生成した後、`./miniruby ../ruby/test.rb` を実行してくれます。
いちいち、`./miniruby ...` などと入力しなくて良いのが便利なところです。
また、拡張ライブラリのビルドなどを行わない、というのも、実行時間の短縮に寄与しています。
つまり、ちょっと修正しては試す、というサイクルをささっと回しやすい、ということです。

もし、修正が失敗しており、コンパイルエラーなどが起こると、このプロセスは途中で止まります（`make` の機能ですね）。

なお、新しい修正をするとき、`test.rb` の内容を書き換える必要があります。このとき、全てを消すよりは、すでに書いてあるスクリプトの前に `__END__` と書くようにすると、前のスクリプトを残したまま新しいスクリプトを追加できるので便利です。


```
# 新しいテストスクリプト

__END__

# 前のスクリプト
```

笹田の `test.rb` を見てみると、4000行ありました（時々消すので、あんまり大きくないです）。

### miniruby ではない、フルセットの ruby で実行しよう

拡張ライブラリを含む「普通の」Rubyを実行したい時は、`make run` の代わりに `make runruby` を使います。`make install` しないで実行できるため、若干早く開発が進められます。

1. `ruby/test.rb` に実行したい Ruby スクリプトを表示する（gem は使えないので注意）。また、Ruby のソースコードを修正する。
2. ビルドディレクトリ（`workdir/build`）で `$ make runruby` を実行する

### gdb を用いてデバッグしよう

> NOTE: Mac OSX で gdb を動かすのは難しいようです。下記は、Linux 等を念頭に解説しています。笹田は使わないのでよく知らないのですが、`$ make lldb` もあるようです。

Ruby のソースコードを修正すると、C プログラムなので容易に SEGV といったクリティカルな問題を簡単に発生させることができます（発生しちゃいます）。そこで、gdb を使ってデバッグするための方法を用意しています。もちろん、ブレイクポイントを用いたデバッグなどでも利用可能です。

1. `ruby/test.rb` にテストしたい Ruby スクリプトを記述する
2. ビルドディレクトリ（`workdir/build`）で `$ make gdb` を実行する（問題が起こらなければ、何事もなく終了します）

このとき、利用するのは `./miniruby` になります。`./ruby` を用いたい場合は `make gdb-ruby` としてください。

もし、ブレイクポイントを挿入したい場合は、`make gdb` コマンドでビルドディレクトリに生成される `run.gdb` というファイルに、例えば `b func_name` といったブレイクポイント指定を書いてください。

### Ruby のテストを実行しよう

1. `$ make btest` # run bootstrap tests in `ruby/bootstraptest/`
2. `$ make test-all` # run test-unit tests in `ruby/test/`
3. `$ make test-spec` # run tests provided in `ruby/spec`

これらの三つは、それぞれ別々の目的・特徴をもって開発されています。

* `ruby/bootstraptest/`: メソッド呼び出しができるか、など最低限のテスト。各テストは別プロセスで実行される。minitest っぽい独自形式で書かれている。
* `ruby/test/`: Ruby の全機能（が目標）のテスト。minitest 形式で書かれている。
* `ruby/spec/`: Ruby の仕様を記述しようという rubyspec というプロジェクトによるテスト。rspec っぽい独自形式で書かれている。

なお、`make check` とすると、これら全てのテストをまとめて実行します。

## MRI のソースコードの構造の紹介

### インタプリタ

大雑把に、下記のようなディレクトリ構造になっています。

* `ruby/*.c` MRI core files
    * VM cores
        * VM
            * `vm*.[ch]`: VM の実装
            * `vm_core.h`: VM データ構造の定義
            * `insns.def`: VM の命令定義
        * `compile.c, iseq.[ch]`: 命令列関係の処理
        * `gc.c`, `gc/`: GC とメモリ管理（`gc/` には差し替え可能な GC の実装が入っています。`gc/default/` が標準の GC、`gc/mmtk/` が実験的な MMTk 版）
        * `shape.[ch]`: オブジェクトのインスタンス変数のレイアウト管理（object shape）
        * `thread*.[ch]`: スレッド管理（M:N スレッドスケジューラを含む）
        * `ractor.[ch]`, `ractor.rb`, `ractor_sync.c`, `ractor_core.h`: Ractor（[(7) Ractor を触ってみよう](7_ractor.md) で紹介します）
        * `variable.c`: 変数管理
        * `dln*.c`: C拡張のためのダイナミックリンクライブラリ管理
        * `main.c`, `ruby.c`: MRI のエントリーポイント
        * `st.c`: ハッシュテーブルアルゴリズムの実装 (参考: https://blog.heroku.com/ruby-2-4-features-hashes-integers-rounding)
    * 組み込みクラス
        * `string.c`: String class
        * `array.c`: Array class
        * ... (だいたい、クラス名に対応するファイル名に定義が格納されています）
* `ruby/*.h`: 内部定義。拡張ライブラリは基本的に使えません
* `ruby/internal/`: 内部定義（こちらも拡張ライブラリからは使えません）
* `ruby/include/ruby/*`: 外部定義。拡張ライブラリで参照できます
* `ruby/prism/`: デフォルトのパーサ Prism（`ruby/prism` リポジトリからコピーされてきます）
* `ruby/yjit/`, `ruby/zjit/`, `ruby/jit/`: JIT コンパイラ（Rust で書かれています）
* `ruby/enc/`: エンコーディングのためのソースコードや情報
* `ruby/coroutine/`: Fiber のためのコンテキストスイッチの実装（CPU/ABI ごと）
* `ruby/defs/`: 各種定義
* `ruby/tool/`: MRI をビルド・実行するためのツール
* `ruby/missing/`: いくつかの OS で足りないものの実装
* `ruby/cygwin/`, `ruby/win32/`, `ruby/wasm/`, ...: OS/system 依存のソースコード

### ライブラリ

ライブラリは 2 種類あります。

* `ruby/lib/`: 標準添付のライブラリ（Ruby で記述されたライブラリ）
* `ruby/ext/`: 標準添付の拡張ライブラリ（C で記述されたライブラリ）

### テスト

* `ruby/basictest/`: place of old test
* `ruby/bootstraptest/`: bootstrap test
* `ruby/test/`: tests written by test-unit notation
* `ruby/spec/`: tests written by RSpec notation

### misc

* `ruby/doc/`, `ruby/man/`: ドキュメント
    * `ruby/doc/contributing/` には、ビルド・テスト・貢献の方法がまとまっています（[building_ruby.md](https://github.com/ruby/ruby/blob/master/doc/contributing/building_ruby.md)、[testing_ruby.md](https://github.com/ruby/ruby/blob/master/doc/contributing/testing_ruby.md) など）
* `ruby/benchmark/`: ベンチマーク（`make benchmark` で実行できます）
* `ruby/misc/`: エディタ・デバッガ用の設定など

## Ruby のビルドプロセス

Ruby のビルドでは、ソースコードを生成しながらビルドを進めていきます。ソースコードを生成するいくつかのツールは Ruby を用いるため、Ruby のビルドには Ruby が必要になります。ソースコード配布用の tar ball には、これら生成されたソースコードもあわせて配布しているので、tar ball を用いるのであれば、Ruby のビルドに Ruby （や、その他 autoconf などの外部ツール）は不要です。

逆に言うと、Git リポジトリからソースコードを取得した場合は、Ruby インタプリタ（や、autoconf などの外部ツール）が必要になります。

ビルド・インストールは、次のように進みます（要するに、`make all` がやっていること）。

1. miniruby のビルド
    1. parse.y -> parse.c: パーサジェネレータ lrama で文法定義を C のコードへ変換
    2. insns.def -> vm.inc: VM の命令定義を、ruby（`BASERUBY`）で C のコードへ変換
    3. `*.c` -> `*.o` (`*.obj` on Windows): C のコードをコンパイル
    4. できたオブジェクトファイルをリンクして miniruby を作る
2. エンコーディングのビルド
    1. translate enc/... to appropriate C code by `miniruby`
    2. compile C code
3. C 拡張ライブラリのビルド
    1. Make `Makefile` from `extconf.rb` by `mkmf.rb` and `miniruby`
    2. Run `make` using generated `Makefile`.
4. `ruby` コマンドのビルド
5. `rdoc`, `ri` ドキュメントの生成
6. 生成されたファイルのインストール（インストール先は `configure` の `--prefix` で指定したもの）

実は、本当はもっと色々やっているのですが、書き切れないし、私も把握していないので、省略しています。`common.mk` といった make 用のルール集に、いろいろなファイルが入っています。

> Note: Ruby 3.4 から、デフォルトのパーサは `parse.y` ではなく [Prism](https://github.com/ruby/prism)（`prism/` にあります）になりました。`ruby -v` の出力に `+PRISM` と出ていれば Prism を使っています。`parse.y` のパーサも残っており、`ruby --parser=parse.y` で切り替えられます。

## 演習：バージョン表記の修正（改造）

では、実際に Ruby を修正してみましょう。ソースコードはすべて `workdir/ruby/` にあると仮定します。

まずは、`ruby -v`（もしくは `./miniruby -v`）を実行したときに、自分の Ruby だとわかるように、何か表示を変えてみましょう。

1. バージョン表記を行うコードは `version.c` にあるので、これを開きます。
2. 少し、ソースコード全体を眺めてみましょう。
3. `ruby_show_version()` という関数が怪しそうです（関数名見れば自明？）。
4. `fflush()` が、出力を確定する（出力バッファを吐き出す） C の関数なので、この前に何らかの出力をすれば良いと推測。
5. `printf("...\n");` （`...` の部分には、好きな文字列）を記入。
6. `$ make miniruby` でビルド（ビルドディレクトリに移動しておく）。
7. `$ ./miniruby -v` で結果を確認。
8. `$ make install` でインストール。
9. `$ ../install/bin/ruby -v` でインストールされた ruby コマンドにも変更が反映されたことを確認。

最後に `printf(...)` を挟むだけではなく、`ruby ...` と書かれた行を変更しても面白いかもしれませんね。`perl` と出力してみるとか。
