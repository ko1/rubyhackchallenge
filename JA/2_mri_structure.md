# (2) MRI ソースコードの構造

## この資料について

MRI のソースコードの構造について紹介します。また、Ruby のソースコードをハックする最低限の知識を紹介します。

* 演習: MRI のソースコードを clone
* 演習: MRI のビルド、およびインストール
* MRI の構造の紹介
* 演習: ビルドした Ruby でプログラムを実行
* 演習： バージョン表記を変更してみよう

## 本稿で前提とするディレクトリ構造

下記のコマンドは、Linux や Mac OSX などを前提としています。Windows 等を使う場合は、別途頑張ってください。

> Note: docker 環境（Ubuntu 18.04 base）を作ってみました。 `docker pull koichisasada/rhc` で試してみてください。`su rubydev` でアカウントを rubydev でご利用ください。

前提とするディレクトリ構造:

* `workdir/`
  * `ruby/` <- git clone するディレクトリ
  * `build/` <- ビルドディレクトリ（ここに、コンパイルした `*.o` などが入る）
  * `install/` <- インストールディレクトリ (`workdir/install/bin/ruby` がインストールされたディレクトリになります）

前提とするコマンド：

git、ruby、autoconf、bison、gcc (or clang, etc）、make が必須です。その他、依存ライブラリがあれば、拡張ライブラリが作成されます。

`apt-get` が使える環境では、下記のようなコマンドでインストールされます。

```
$ sudo apt-get install git ruby autoconf bison gcc make zlib1g-dev libffi-dev libreadline-dev libgdbm-dev libssl-dev libyaml-dev
```

`apt-get` 以外でインストールしたい場合は、例えば [Home · rbenv/ruby\-build Wiki](https://github.com/rbenv/ruby-build/wiki) を参照してみてください。

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
        * `gc.c`: GC とメモリ管理
        * `thread*.[ch]`: スレッド管理
        * `variable.c`: 変数管理
        * `dln*.c`: C拡張のためのダイナミックリンクライブラリ管理
        * `main.c`, `ruby.c`: MRI のエントリーポイント
        * `st.c`: ハッシュテーブルアルゴリズムの実装 (参考: https://blog.heroku.com/ruby-2-4-features-hashes-integers-rounding)
    * 組み込みクラス
        * `string.c`: String class
        * `array.c`: Array class
        * ... (だいたい、クラス名に対応するファイル名に定義が格納されています）
* `ruby/*.h`: 内部定義。拡張ライブラリは基本的に使えません
* `ruby/include/ruby/*`: 外部定義。拡張ライブラリで参照できます
* `ruby/enc/`: エンコーディングのためのソースコードや情報
* `ruby/defs/`: 各種定義
* `ruby/tool/`: MRI をビルド・実行するためのツール
* `ruby/missing/`: いくつかの OS で足りないものの実装
* `ruby/cygwin/`, `ruby/nacl/`, `ruby/win32`, ...: OS/system 依存のソースコード

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

## Ruby のビルドプロセス

Ruby のビルドでは、ソースコードを生成しながらビルドを進めていきます。ソースコードを生成するいくつかのツールは Ruby を用いるため、Ruby のビルドには Ruby が必要になります。ソースコード配布用の tar ball には、これら生成されたソースコードもあわせて配布しているので、tar ball を用いるのであれば、Ruby のビルドに Ruby （や、その他 bison などの外部ツール）は不要です。

逆に言うと、Subversion や Git リポジトリからソースコードを取得した場合は、Ruby インタプリタ（や、bison などの外部ツール）が必要になります。

ビルド・インストールは、次のように進みます（要するに、`make all` がやっていること）。

1. miniruby のビルド
    1. parse.y -> parse.c: Compile syntax rules to C code by bison
    2. insns.def -> vm.inc: Compile VM instructions to C code by ruby (`BASERUBY`)
    3. `*.c` -> `*.o` (`*.obj` on Windows): Compile C codes to object files.
    4. link object files into miniruby
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
