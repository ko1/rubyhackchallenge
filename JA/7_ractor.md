# (7) Ractor を触ってみよう

## この資料について

Ractor は、Ruby で並列プログラミングを行うための仕組みです。この資料では、**最新の Ruby（master ブランチ）で Ractor を実際に動かしてみる**ことを目的にします。

* Ractor の考え方（何ができて、何ができないか）
* 演習：Ractor を作る、並列に動かす、メッセージを送る、オブジェクトを共有する
* よくつまづくところ
* Ruby 4.0 / 4.1 での変更点
* 実装のどこを読めばいいか
* もっと遊ぶための材料

Ractor は **experimental（実験的）な機能**です。使うと警告が出ますし、API はまだ変わる可能性があります。裏を返すと、**今、実際に使ってみた人の意見が一番効く**タイミングでもあります。「こう書きたいのに書けない」「このエラーメッセージだと何が悪いのかわからない」といった感想は、そのまま Ruby へのフィードバックになります。

この資料中の実行例は、`ruby 4.1.0dev (2026-09-14T04:56:14Z master d568c61094)` で確認しています。

> Note: この章は [EURUKO 2026](https://2026.euruko.org/)（2026/9/18 午後、チェコ・ブルノ）のワークショップ用に書かれました（[案内](../events/euruko2026.md)）。もちろん、ひとりで進めることもできます。

## 準備

[(2) MRI ソースコードの構造](2_mri_structure.md) の手順で、master ブランチの Ruby をビルドしてください。ビルドした ruby のバージョンを確認しておきましょう。

```
$ ./ruby -v
ruby 4.1.0dev (2026-09-14T04:56:14Z master d568c61094) +PRISM [x86_64-linux]
```

Ractor を使うと、次の警告が出ます。

```
warning: Ractor API is experimental and may change in future versions of Ruby.
```

うるさいときは `-W:no-experimental` を付けてください。以降の例では、この警告は省略しています。

```
$ ./ruby -W:no-experimental test.rb
```

なお、簡単な例は `make run`（miniruby）でも動きますが、`require 'json'` のように拡張ライブラリを使う例は動きません。`make runruby` か、ビルドした `./ruby` を直接使うのが確実です。

## Ractor とは

ひとつの Ruby プロセスの中に、複数の Ractor を作れます。ポイントは 2 つです。

* **並列に動く**：MRI では GVL（Global VM Lock）を Ractor ごとに持っています。そのため、複数の Ractor は本当に同時に動きます。Thread では（同じ Ractor 内である限り）Ruby のコードは同時には動きません。
* **オブジェクトを共有しない**：Ractor 間では、ほとんどのオブジェクトを共有できません。共有できるのは「shareable なオブジェクト」（数値、シンボル、`true`/`false`/`nil`、freeze した文字列、クラス・モジュールなど）だけです。それ以外のオブジェクトは、**コピー**するか**移動**して渡します。

この「共有しない」という制限のおかげで、データ競合（data race）が原理的に起きません。ロックを忘れて壊れる、という種類のバグを、実行する前に（多くは `Ractor.new` した瞬間に）エラーとして弾けます。

|  | Thread | Ractor |
|---|---|---|
| Ruby コードの並列実行 | されない（GVL を共有） | される（Ractor ごとに GVL） |
| オブジェクトの共有 | 全部共有 | shareable なものだけ |
| データ競合 | 起こる（自分でロックする） | 起きない |
| 作るコスト | 小さい | Thread より大きい |

## 演習 1: 最初の Ractor

```ruby
r = Ractor.new do
  puts "Hi, I am #{Ractor.current.inspect}"
  42
end

p r.value  #=> 42
```

実行結果:

```
Hi, I am #<Ractor:#2 test.rb:1 running>
42
```

* `Ractor.new{ ... }` でブロックを渡すと、新しい Ractor がブロックの実行を始めます。
* `Ractor#value` は、その Ractor が終わるのを待って、ブロックの戻り値を返します（`Thread#value` と同じ感覚です）。
* 戻り値がいらないときは `Ractor#join` を使います（`Thread#join` と同じ）。
* `Ractor.count` で、現在動いている Ractor の数がわかります（メインの Ractor も 1 つと数えます）。

> Note: `Ractor#value` で受け取れるのは 1 回だけです。2 回目は `Ractor::Error (The value was already taken)` になります。終了値は「コピー」ではなく「移動」されるため、受け取れる Ractor はひとつだけ、という仕様です。

## 演習 2: 本当に並列に動くか確かめる

Ractor の一番のご利益は並列実行です。確かめてみましょう。

```ruby
def fib(n) = n < 2 ? n : fib(n-1) + fib(n-2)

N = 4
n = 30

t = Time.now
N.times { fib(n) }
puts "sequential: #{Time.now - t} sec"

t = Time.now
N.times.map { Thread.new { fib(n) } }.each(&:join)
puts "#{N} threads: #{Time.now - t} sec"

t = Time.now
rs = N.times.map { Ractor.new(n) {|n| fib(n) } }
rs.each(&:value)
puts "#{N} ractors: #{Time.now - t} sec"
```

手元（コアが 4 つ以上あるマシン）で実行すると、`sequential` と `N threads` はほぼ同じ時間、`N ractors` はそれより短くなるはずです。Thread では Ruby のコードが並列に動かないこと、Ractor では動くことが、これで確認できます。

うまく速くならない場合は、次を疑ってみてください。

* CPU のコア数（`nproc` など）は足りていますか？
* 他のプロセスが CPU を使っていませんか？
* `fib(n)` の `n` が小さすぎて、Ractor を作るコストのほうが大きくなっていませんか？

## 演習 3: ブロックは隔離される

Ractor に渡すブロックは「隔離（isolate）」されます。外側のローカル変数を参照できません。

```ruby
a = 1
Ractor.new { p a }
#=> can not isolate a Proc because it accesses outer variables (a). (Ractor::IsolationError)
```

エラーは、Ractor が動き始める前（`Ractor.new` の時点）に出ます。「うっかり共有してしまった」ことを実行前に教えてくれる、というわけです。

値を渡したいときは、引数として渡します。引数はブロックパラメータで受け取ります。

```ruby
a = 1
r = Ractor.new(a) {|a| a + 1 }
p r.value  #=> 2
```

引数が shareable でないオブジェクトの場合は、コピーされて渡ります（後述）。

ブロックを値として渡したい場合は、`Ractor.shareable_proc`（lambda 版は `Ractor.shareable_lambda`）で shareable な Proc を作ります。

```ruby
pr = Ractor.shareable_proc { |x| x * 2 }
p Ractor.shareable?(pr)               #=> true
p Ractor.new(pr) {|pr| pr.call(21) }.value  #=> 42
```

`Ractor.shareable_proc` でも、外側の変数の扱いには制限があります。「後から代入され得る変数」や「shareable でない値を持つ変数」を参照しているとエラーになります。

```ruby
s = "mutable"
Ractor.shareable_proc { s }
#=> cannot make a shareable Proc because it can refer unshareable object "mutable"
#   from variable 's' (Ractor::IsolationError)
```

```ruby
a = 1
pr = Ractor.shareable_proc { a }  # OK: a は shareable で、もう代入されない（値が埋め込まれます）
p Ractor.new(pr) {|pr| pr.call }.value #=> 1
```

```ruby
a = 1
pr = Ractor.shareable_proc { a }  # ここでエラーになります
a = 2                             # 後で代入されるため
#=> cannot make a shareable Proc because the outer variable 'a' may be reassigned.
#   (Ractor::IsolationError)
```

## 演習 4: メッセージを送る（デフォルトポート）

Ractor 同士は、メッセージをやりとりして協調します。それぞれの Ractor は「デフォルトポート」を持っていて、`Ractor#send` で送り、`Ractor.receive` で受け取ります。

```ruby
r = Ractor.new do
  msg = Ractor.receive      # メッセージが来るまで待つ
  "received: #{msg}"
end

r.send("hello")
p r.value  #=> "received: hello"
```

* `Ractor#send(obj)`（`<<` も同じ）は、相手が受け取る準備をしているかどうかに関わらず、すぐに返ります（キューに積まれます）。
* `Ractor.receive` は、メッセージが来るまでそのスレッドを止めます。`Ractor.receive(timeout: 1)` のようにタイムアウトを指定でき、時間切れなら `nil` を返します。

## 演習 5: `Ractor::Port`

Ruby 4.0 から `Ractor::Port` が入りました。ポートは「メッセージの受け口」で、作った Ractor だけが `receive` できます。送るほうは、ポートオブジェクトさえ持っていれば誰でも送れます。

複数のワーカから結果を 1 か所に集める、といった使い方が素直に書けます。

```ruby
port = Ractor::Port.new

rs = 3.times.map do |i|
  Ractor.new(port, i) do |port, i|
    port << "worker #{i} finished"
  end
end

3.times { p port.receive }
rs.each(&:join)
port.close
```

実行結果（順番は実行のたびに変わります）:

```
"worker 0 finished"
"worker 1 finished"
"worker 2 finished"
```

* ポートは `Ractor::Port.new` で作ります。作った Ractor だけが `receive` できます（受信者が 1 つに決まっていることの意味は、演習 9 で説明します）。
* `port.close` で閉じます。閉じたポートへ送ると `Ractor::ClosedError` です。キューに残っているメッセージは、閉じたあとでも受け取れます。
* `port.receive(timeout: 秒)` も使えます。

閉じられるのは、そのポートを持っている Ractor です。「Ractor が」なので、**同じ Ractor の別スレッドからでも閉じられます**。そして、待っている `receive` は `Ractor::ClosedError` で起きます。

```ruby
port = Ractor::Port.new
Thread.new { sleep 0.1; port.close }

begin
  port.receive     # 0.1 秒待ってから…
rescue Ractor::ClosedError => e
  p e.message      #=> "The port was already closed"
end
```

「誰からもメッセージが来ないまま `receive` で止まっている」を外から終わらせる、定番の手です（この「閉じたら待っている人を起こす」挙動は 2026 年 9 月に入ったものです）。他の Ractor から閉じることはできません（`Ractor::Error (closing port by other ractors is not allowed)`）。

## 演習 6: 複数の Ractor を待つ（`Ractor.select` と `Ractor#monitor`）

終わった順に結果を処理したいときは `Ractor.select` です。Ractor とポートを混ぜて渡せます。

```ruby
rs = 3.times.map {|i| Ractor.new(i) {|i| i * 10 } }

until rs.empty?
  r, v = Ractor.select(*rs)
  rs.delete(r)
  p v
end
#=> 0, 10, 20 が終わった順に表示される
```

`Ractor.select(*ports, timeout: 秒)` と書くと、時間切れで `nil` が返ります。

「終わったことだけ知りたい」場合は `Ractor#monitor` が使えます。終了を知らせるメッセージが、指定したポートに届きます。

```ruby
port = Ractor::Port.new

r = Ractor.new { :ok }
r.monitor port
p port.receive  #=> [#<Ractor:#2 test.rb:3 terminated>, :exited]

r = Ractor.new { raise "oops" }
r.monitor port
p port.receive  #=> [#<Ractor:#3 test.rb:7 terminated>, :aborted]
```

どの Ractor が終わったかが分かるので、ひとつのポートで複数の Ractor を見張れます。落ちた（`:aborted`）ものだけ作り直す、といった「スーパーバイザ」が書けます。

## 演習 7: 共有・コピー・移動

どのオブジェクトが共有できるかは `Ractor.shareable?` で確認できます。

```ruby
p Ractor.shareable?(1)                  #=> true
p Ractor.shareable?("foo")              #=> false
p Ractor.shareable?("foo".freeze)       #=> true
p Ractor.shareable?([Object.new].freeze) #=> false （中身を freeze していない）
```

`Ractor.make_shareable(obj)` は、`obj` とそこから辿れるオブジェクトをまとめて freeze して、shareable にします。

```ruby
ary = ["hello", "world"]
Ractor.make_shareable(ary)
p [ary.frozen?, ary[0].frozen?]  #=> [true, true]
```

shareable でないオブジェクトを送ると、既定では**コピー**されます（deep copy）。

```ruby
str = "hello"
r = Ractor.new { obj = Ractor.receive; [obj, obj.object_id] }
r.send(str)
obj, oid = r.value
p str.object_id == oid  #=> false （別のオブジェクトになっている）
```

コピーが重い（もしくはコピーできない）場合は `move: true` で**移動**できます。移動したオブジェクトは、送った側からは触れなくなります。

```ruby
str = "world"
r = Ractor.new { Ractor.receive }
r.send(str, move: true)
p r.value        #=> "world"

str.upcase
#=> can not send any methods to a moved object (Ractor::MovedError)
```

## 演習 8: 何が禁止されているのかを見る

Ractor の制限は、エラーメッセージで教えてくれます。実際に踏んで、メッセージを読んでみましょう（下記は、1 つずつ別々に実行してみてください。例外が出た時点でスクリプトが止まります）。

```ruby
GOOD = 'good'.freeze
BAD  = 'bad'.dup

Ractor.new { p GOOD }.join   #=> "good"（shareable な定数は読める）

Ractor.new { p BAD }.join
#=> can not access non-shareable objects in constant Object::BAD of a class/module
#   created by another Ractor. (Ractor::IsolationError)

Ractor.new { String.class_eval { def foo; end } }.join
#=> can not modify String because it is created by another Ractor (Ractor::IsolationError)

Ractor.new { at_exit { puts "bye" } }.join
#=> can not call at_exit from non-main Ractors (Ractor::IsolationError)
```

一方、次のようなことはできます。

```ruby
# Ractor の中でクラスを作って使う（その Ractor が「持ち主」になります）
r = Ractor.new { c = Class.new { def hello = "hello" }; c.new.hello }
p r.value  #=> "hello"

# require もできます
r = Ractor.new { require 'json'; JSON.generate({"a" => 1}) }
p r.value  #=> "{\"a\":1}"
```

> Note: 「クラス・モジュールは、それを作った Ractor だけが変更できる」という制限は、開発中の 4.1 で入ったものです（[Feature #22226]）。メインの Ractor が作ったクラス（`String` などの組み込みクラスや、`require` したライブラリを含む）を、他の Ractor から書き換えることはできません。その代わり、自分が作ったクラスは自由に使えます。

## 演習 9: まとめ — ワーカプールを書いてみる

ここまでの部品で、簡単なワーカプールが書けます。

```ruby
def fib(n) = n < 2 ? n : fib(n-1) + fib(n-2)

RN = 4                       # ワーカの数
result_port = Ractor::Port.new

workers = RN.times.map do
  Ractor.new(result_port) do |result_port|
    while n = Ractor.receive # nil が来たら終了
      result_port << [n, fib(n)]
    end
  end
end

jobs = (25..32).to_a
jobs.each_with_index {|n, i| workers[i % RN] << n }
workers.each {|w| w << nil }

results = jobs.size.times.map { result_port.receive }
workers.each(&:join)
result_port.close

pp results.sort
```

* 各ワーカは自分のデフォルトポートで仕事を受け取り、結果は共通の `result_port` へ送ります。
* ポートを `receive` できるのは、そのポートを作った Ractor だけです。制限に見えますが、**受け取る人が 1 人に決まっている**ことには利点があります。
    * **メッセージの行き先が、実行するまでもなく決まっています。** 送ったオブジェクトを次に触るのがどの Ractor なのかが、コードを読めば分かります。`move: true` で渡したものの行き先が一意なのも同じ性質です。「1 本のキューを全員で取り合う」設計だと、どのワーカがそれを取るかは走らせてみるまで決まりません。
    * **そのワーカに状態を持たせられます。** 接続、キャッシュ、開いたファイル……「この仕事はこの Ractor がやる」と決まっているからできることです（punions の「1 接続 1 Ractor」も、この形です）。
    * **排他制御が簡単になります。** ロックが無くなるわけではありません（キューは送る側と受け取る側で共有するので、MRI の中では受信側 Ractor のロックを取っています）。簡単になるのは、**取るべきロックが「受信側 Ractor のロック」の 1 つに決まる**からです。キューから取り出すのは所有者だけ（`ractor_sync.c` の `ractor_queue_deq()` には `VM_ASSERT(GET_RACTOR() == r)` が入っています）、読み手どうしの調停は無し、所有者のスレッドどうしは自分の GVL で直列化されているのでロックを取らずに済む経路もある、という具合です。読み手が複数いると、この全部が複雑になります。
* その代わり、仕事の配り方は自分で決めることになります。ここでは順番に配っていますが、「空いたワーカに次を渡す」形にするには、ワーカ側から「空きました」と知らせてもらう必要があります（実際に書いてみると、この手の面倒くささが分かります。それを引き受けるのが、後述する ractor-pipeline のようなライブラリです。あちらは、ワーカが「あと 2 個までなら受け取れます」という札を配る、pull 型のスケジューリングになっています）。

## よくつまづくところ

* **Ractor の中の例外は `Ractor::RemoteError` に包まれます。** 元の例外は `#cause` で取れます。

    ```ruby
    r = Ractor.new { raise ArgumentError, "boom" }
    begin
      r.value
    rescue Ractor::RemoteError => e
      p [e.cause.class, e.cause.message]  #=> [ArgumentError, "boom"]
    end
    ```

* **`Ractor#value` は 1 回だけ。** 2 回目は `Ractor::Error (The value was already taken)` です。単に終了を待ちたいだけなら `Ractor#join` を使いましょう。
* **`IO` は shareable にできません。** `Ractor.make_shareable(STDOUT)` は `Ractor::Error` です（`puts` などは使えます）。
* **ブロックに渡した引数はコピーされます。** 巨大な配列を渡すと、その分の時間とメモリを使います。`move: true` を検討してください。
* **止まったように見えるとき**は、だいたい `receive` で待っています。誰も送っていない、もしくはポートを閉じ忘れている、というのがありがちです。待つのをやめさせたいときは、`receive(timeout: 秒)` を使うか、同じ Ractor の別スレッドからそのポートを `close` します（演習 5 参照）。

### LLM に聞くときのコツ

Ractor でも、LLM やコーディングエージェントはどんどん使ってください。ただ、Ractor は Ruby 4.0 で API が大きく変わったばかりなので、**学習した時点の古い API でコードを書いてくることがあります**。`Ractor#take` や `Ractor.yield`、`Ractor#close_incoming` が出てきたら、それは 4.0 で削除されたものです。

そういうときは、手元のソースを見せるのが手っ取り早いです。

* `ractor.rb`：いまの API とその rdoc が全部書いてあります
* `NEWS.md`、`doc/NEWS/NEWS-4.0.0.md`：何が変わったか
* `test/ruby/test_ractor.rb`：実際に動く書き方の実例

エラーメッセージをそのまま貼るのも有効です。Ractor のエラーメッセージは、何が禁止されているのかをかなり具体的に教えてくれます。

## Ruby 4.0 / 4.1 での変更点

Ractor は絶賛開発中なので、少し前の記事やサンプルコードは、そのままでは動かないことがあります。主な変更点を挙げておきます。

**Ruby 4.0**

* `Ractor::Port` が入りました [[Feature #21262]](https://bugs.ruby-lang.org/issues/21262)。
* これに伴い、`Ractor.yield` と `Ractor#take` は**削除**されました。`Ractor#close_incoming` / `#close_outgoing` も削除されています。
    * 昔のコードの `r.take` は、多くの場合 `r.value`（終了値）か、ポート経由の受信に書き換えることになります。
* `Ractor#join` と `Ractor#value` が入りました（`Thread#join` / `Thread#value` に相当）。
* `Ractor#monitor` / `#unmonitor`、`Ractor#default_port` が入りました。
* `Ractor.select` が受け付けるのは Ractor と Port だけになりました。
* `Ractor.shareable_proc` / `Ractor.shareable_lambda` が入りました。

**Ruby 4.1（開発中）**

* **GC が Ractor ごとに動くようになりました。** それぞれの Ractor が自分のヒープを自分で回収するので、オブジェクトをたくさん作る並列プログラムが、プロセスを fork したときのようにスケールします。
* `Ractor#monitor` が送るメッセージが、`:exited` / `:aborted` という Symbol から `[ractor, :exited]` という Array になりました。どの Ractor が終わったのか分かるようになっています。
* クラス・モジュールは、それを作った Ractor だけが変更できるようになりました [[Feature #22226]](https://bugs.ruby-lang.org/issues/22226)。
* 非メイン Ractor での `at_exit` / `END {}` は `Ractor::IsolationError` になりました [[Feature #22139]](https://bugs.ruby-lang.org/issues/22139)。
* `Ractor::Port#receive`、`Ractor.receive`、`Ractor.select` に `timeout:` が付きました [[Feature #22255]](https://bugs.ruby-lang.org/issues/22255)。時間切れなら `nil` を返します。`timeout: 0` は「待たない」の意味で、すでに届いていれば受け取り、無ければすぐ `nil` です（時計も読みません）。

M:N スレッドスケジューラにも、4.1 でいろいろ入っています（次の節で触ります）。

最新の状況は、ソースツリーの `NEWS.md` と [`doc/NEWS/`](https://github.com/ruby/ruby/tree/master/doc/NEWS) を見てください。

## おまけ: M:N スレッドスケジューラを触る

Ractor のスレッドは、**M:N スレッドスケジューラ**の上で動いています。Ruby のスレッド M 本を、少数のネイティブスレッド N 本に載せる仕組みです。これも環境変数で切り替えられるので、ついでに触ってみましょう（下記は Linux の例です）。

`RUBY_MN_THREADS` で、どこまでを M:N にするかを選べます。

| | メインスレッド | メイン Ractor の他のスレッド | Ractor のスレッド |
|---|---|---|---|
| `-1` | 1:1 | 1:1 | 1:1 |
| `0`（既定） | 1:1 | 1:1 | M:N |
| `1` | 1:1 | M:N | M:N |
| `2` | M:N | M:N | M:N |

`-1` と `2` は Ruby 4.1 で増えました。

### 演習: ネイティブスレッドを数える

Ruby のスレッドを 1000 本作って、OS から見えるスレッドの数を見てみましょう。

```ruby
N = 1000
t = Time.now
ths = N.times.map { Thread.new { sleep 3 } }
created = Time.now - t

native = File.read("/proc/self/status")[/^Threads:\s*(\d+)/, 1]
rss    = File.read("/proc/self/status")[/^VmRSS:\s*(\d+)/, 1].to_i / 1024

puts "RUBY_MN_THREADS=#{ENV['RUBY_MN_THREADS'] || '(unset)'}: " \
     "#{N} ruby threads, #{native} native threads, #{rss} MB, created in #{created.round(3)} sec"
ths.each(&:kill)
```

```
$ for v in -1 0 1 2; do RUBY_MN_THREADS=$v ./ruby -W:no-experimental mn.rb; done
RUBY_MN_THREADS=-1: 1000 ruby threads, 1002 native threads, 41 MB, created in 1.686 sec
RUBY_MN_THREADS=0: 1000 ruby threads, 1002 native threads, 41 MB, created in 1.982 sec
RUBY_MN_THREADS=1: 1000 ruby threads, 3 native threads, 29 MB, created in 0.092 sec
RUBY_MN_THREADS=2: 1000 ruby threads, 2 native threads, 29 MB, created in 0.124 sec
```

（16 コアの Linux での例です。手元でも走らせてみてください。生成時間はマシンの混み具合で大きく動くので、安定して見られるのはネイティブスレッドの本数とメモリのほうです）

ネイティブスレッドが 1000 本から 3 本になり、生成にかかる時間が 20 分の 1 になりました。「待っているだけのスレッドを大量に持つ」プログラム（接続ごとに 1 スレッド、のようなサーバ）で効いてくる差です。

### 演習: 既定でも Ractor の中は M:N

`RUBY_MN_THREADS` を設定しなくても、**Ractor の中のスレッドは M:N** です。

```ruby
r = Ractor.new do
  ths = 1000.times.map { Thread.new { sleep 3 } }
  native = File.read("/proc/self/status")[/^Threads:\s*(\d+)/, 1]
  ths.each(&:kill)
  native
end
puts "in a Ractor: 1000 ruby threads, #{r.value} native threads"
```

```
$ ./ruby -W:no-experimental mn2.rb
in a Ractor: 1000 ruby threads, 3 native threads

$ RUBY_MN_THREADS=-1 ./ruby -W:no-experimental mn2.rb
in a Ractor: 1000 ruby threads, 1003 native threads
```

`-1` は「Ractor のスレッドも M:N にしない」という、4.1 で増えた選択肢です。M:N を切った状態と比べられるので、「これは M:N のおかげなのか」を確かめるのに使えます。

ネイティブスレッドの本数の上限は `RUBY_MAX_CPU` で変えられます（既定は CPU のコア数）。

> Note: `RUBY_MN_THREADS=2` はメインスレッドまで M:N にします。メインスレッドが 1 本の OS スレッドに固定されなくなるので、OS スレッドごとに状態を持つ C 拡張は `rb_thread_lock_native_thread()` を呼ぶ必要があり、プロセスの最初のスレッドでしか動かないもの（macOS の AppKit など）は動きません。

### 4.1 で M:N まわりに入ったもの

開発中の 4.1 では、このスケジューラにいろいろ入っています（詳しくは `NEWS.md` の "M:N thread scheduler"）。

* **待っているスレッドの数と Ractor の数に対してスケールする**ようになりました。時間つきの待ちは階層タイマーホイールに入り（以前は締切順のリストを線形に走査して挿入していました）、fd は待つたびに付け外しせずスケジューラの backend に登録したままになり、io 待ちの管理は fd ごとに分割され、コンテキストスイッチや共有プールへの出入りでスケジューラ全体のロックを取らなくなりました。
* `RUBY_MN_THREADS` に `-1` と `2` が増えました（上の表）。
* **M:N スレッドでは、OS スレッドの名前を Ruby のスレッド名に合わせなくなりました。** 1 本のネイティブスレッドが多数の Ruby スレッドを回すので、意味がないためです。これは外から見えます。

    ```ruby
    t = Thread.new { Thread.current.name = "worker"; sleep 2 }
    sleep 0.3
    p Dir.glob("/proc/self/task/*/comm").map { File.read(it).chomp }.tally
    t.kill
    ```

    ```
    $ RUBY_MN_THREADS=-1 ./ruby -W:no-experimental tn.rb
    {"ruby" => 2, "worker" => 1}
    $ RUBY_MN_THREADS=1 ./ruby -W:no-experimental tn.rb
    {"ruby" => 3}
    ```

## 実装を覗いてみる

「使う」だけでなく、実装も覗いてみましょう。Ractor 関連のファイルは次のとおりです。

| ファイル | 中身 |
|---|---|
| `ractor.rb` | `Ractor` クラスの Ruby レベルの定義と、rdoc のドキュメント。`Ractor.new`、`Ractor#value`、`Ractor::Port` などの入口はここです。`__builtin_` や `Primitive.` と書いてあるところが C の実装に繋がっています |
| `ractor.c` | Ractor の本体。Ractor の生成・終了、メッセージのコピーと移動、shareable 判定など |
| `ractor_sync.c` | ポートとメッセージのやりとり（送信・受信・待ち合わせ）の実装 |
| `ractor_core.h` | `rb_ractor_t` — Ractor のデータ構造。1 つの Ractor が何を持っているかが分かります |
| `internal/ractor.h` | MRI 内部から使う Ractor 関連の宣言 |
| `thread.c`, `thread_pthread.c` | スレッドの実装。Ractor は自分のスレッドで動くので、M:N スレッドスケジューラの話もここです |
| `gc/`, `gc.c` | GC。4.1 の「Ractor ごとの GC」はこのあたり |
| `bootstraptest/test_ractor.rb`, `test/ruby/test_ractor.rb` | テスト。**「Ractor が実際にどう振る舞うべきか」が一番正確に書いてある場所**です。動かして眺めるだけでも勉強になります |
| [`doc/language/ractor.md`](https://github.com/ruby/ruby/blob/master/doc/language/ractor.md) | 設計ドキュメント。この章より詳しい説明と、たくさんの例があります |

最初の一歩としておすすめなのは、`ractor.rb` を眺めて、気になったメソッドの実装を `ractor.c` / `ractor_sync.c` に追いかけることです。([(3) 演習：メソッドの追加](3_practice.md) でやったように) `printf` を入れて `make runruby` すれば、いつ何が呼ばれているかが見えます。

## もっと遊ぶ：Ractor でアプリを書く

ここからは、Ractor を「アプリケーションを書く道具」として使ってみましょう。笹田が書いている 3 つを紹介します。どれも最新の Ruby が必要です。

### 準備：gem を入れる

ビルドした ruby に対して入れます（システムの ruby ではなく、**自分でビルドした ruby** に入れるのがポイントです）。

```
$ cd workdir/build
$ make install                                        # workdir/install/ に入ります
$ ../install/bin/gem install ractor-pipeline ractor-sharing
$ ../install/bin/ruby -W:no-experimental sample.rb
```

`ractor-sharing` は C 拡張を含むので、`gem install` の中でビルドされます。以下の実行例は、`ractor-pipeline 0.2.0` と `ractor-sharing 0.3.0` を `ruby 4.1.0dev (master d568c61094)` に入れて確認しました。

### ractor-pipeline：並列パイプラインを組む

[ko1/ractor-pipeline](https://github.com/ko1/ractor-pipeline) は、Unix のパイプのように処理をつないで書くと、各段が **Ractor になって並列に動く**ライブラリです。演習 9 で面倒だったワーカの管理（仕事を配る、結果を集める、終わらせる）を、ライブラリ側が引き受けてくれます。

```text
stream(src) ──> pipe Ractor x lanes ──> Port ──> reduce（呼び出し側）
```

#### サンプル 1: ソースツリーを横断する grep

MRI のソースディレクトリ（`workdir/ruby/`）で動かしてみましょう。`*.c` を全部開いて、`Ractor` を含む行を数えます。

```ruby
require "ractor/pipeline"
include Ractor::Pipeline

files = Dir.glob("*.c")

hits = stream(files).
         flat_pipe{ File.foreach(it) }.            # 1 ファイル -> N 行
         filter_pipe(lanes: 4){ it.include?("Ractor") }.   # 4 並列で絞り込み
         count

puts "#{files.size} files, #{hits} lines"
```

```
$ ../install/bin/ruby -W:no-experimental grep.rb
117 files, 572 lines
```

`grep -c Ractor *.c | awk -F: '{s+=$2} END{print s}'` と同じ数になるか、確かめてみてください。

#### サンプル 2: アクセスログ集計

「JSONL のアクセスログを読んで、パスごとにリクエスト数・エラー数・平均応答時間を出す」という、よくある集計です。

ポイントは **1 メッセージに 2000 行まとめて**渡し、**ワーカ側で小さな集計結果まで作ってしまう**ことです。呼び出し側は、レコードではなく「チャンクごとの集計結果」だけをマージします（Ractor 間のメッセージは 1 回ごとにコピーが発生するので、細かく送らないのがコツです）。

```ruby
require "ractor/pipeline"
require "json"
include Ractor::Pipeline

def aggregate(lines)                  # 2000 行 -> 小さな集計結果
  agg = {}
  lines.each do |line|
    rec = JSON.parse(line)
    st = (agg[rec["path"]] ||= [0, 0, 0.0])        # req, err, ms
    st[0] += 1
    st[1] += 1 if rec["status"] >= 500
    st[2] += rec["ms"]
  end
  agg
end

stats = stream(File.foreach("access.jsonl").each_slice(2000)).
          pipe(lanes: 8){ aggregate(it) }.
          reduce({}) do |acc, agg|
            agg.each do |path, (req, err, ms)|
              a = (acc[path] ||= [0, 0, 0.0])
              a[0] += req; a[1] += err; a[2] += ms
            end
            acc
          end

stats.sort_by{ -_2[0] }.each do |path, (req, err, ms)|
  puts "%-14s %7d req %5d err %6.1f ms avg" % [path, req, err, ms / req]
end
```

20 万行（8.6MB）のログでの出力例です。

```
/login           33510 req  1069 err  104.9 ms avg
/api/users       33430 req   995 err  140.0 ms avg
/api/search      33362 req   992 err  140.0 ms avg
/api/items       33276 req  1054 err  140.1 ms avg
/healthz         33246 req   964 err  104.4 ms avg
/                33176 req   986 err  105.1 ms avg
```

**同じ集計を `File.foreach` の単純なループで書いて、時間を比べてみましょう。** 手元の 16 コアのマシンでは、直列版 0.30 秒に対してパイプライン版 0.12 秒でした。コア数ぶんにはなりません（ファイルの読み込みと最後のマージは直列ですし、そもそも JSON パース以外は大した仕事をしていません）。**どこが直列に残っているか**を考えるのが、この手のプログラムの面白いところです。

> Note: ログファイルが手元にない場合は、[examples/logreport.rb](https://github.com/ko1/ractor-pipeline/blob/master/examples/logreport.rb) が 40 万行のサンプルログの生成から直列版との比較まで面倒を見てくれます。

#### サンプル 3: 無限ストリームを途中で止める

```ruby
require "ractor/pipeline"
include Ractor::Pipeline

p stream(1..).pipe{ it * it }.first(5)  #=> [1, 4, 9, 16, 25]
```

`first` は残りのストリームをキャンセルします（シェルのパイプで `head` を繋いだときと同じで、上流に「もういらない」が伝わります）。無限ストリームを流しても平気です。

#### つまづきどころ

* 各段のブロックは `Ractor.shareable_proc` で隔離されます。外側の**可変な**変数を掴もうとすると、実行時ではなく `.pipe` を書いた時点で `Ractor::IsolationError` になります（shareable な値はスナップショットされます）。
* ブロックが返す値は Port を通るので、送れないものは返せません。`Hash.new{ ... }` はデフォルト値として Proc を持つので送れません（`(h[k] ||= 0) += 1` のように、素の Hash を組み立てましょう）。

### ractor-sharing：どうしても共有したい状態を置く

[ko1/ractor-sharing](https://github.com/ko1/ractor-sharing) は、**Ractor 間で共有・更新できる状態**を提供するライブラリです。Ractor は「共有しない」ことで安全性を得ていますが、カウンタ、キャッシュ、レジストリのように「どうしても 1 つでないと困るもの」は出てきます。そこだけをこれで埋める、という使い方をします。

| クラス | どんなときに |
|---|---|
| `Ractor::TVar` | まずこれ。複数の変数を**まとめて**更新したい（`Ractor.atomically`）。ロック順を間違えようがなく、デッドロックしない |
| `Ractor::LockVar` | ブロックを**ちょうど 1 回**実行したい（ログを書く、送信する、など retry されると困る処理） |
| `Ractor::LockHash` | ハッシュ全体が 1 つのロック。複数のキーをまとめて変えたい |
| `Ractor::KeyLockHash` | キーどうしが独立（キャッシュ、メモ表、レジストリ）。読みはロック無しで並列に効く |
| `Ractor::ActiveObject` | freeze したくない状態に、メソッドを生やしたい。専用の Ractor に住まわせて、呼び出しを送る |
| `Ractor::ActorHash` | 同じく、ただの Hash で足りる場合 |

#### サンプル 4: 口座振替（`Ractor::TVar`）

「2 つの変数が、まとめて変わる」の例です。8 つの Ractor が、4 つの口座の間でお金を動かします。

```ruby
require "ractor/tvar"

ACCOUNTS = Ractor.make_shareable(4.times.map { Ractor::TVar.new(100) })

rs = 8.times.map do
  Ractor.new do
    500.times do
      from, to = ACCOUNTS.sample(2)
      Ractor.atomically do          # ここの中は、まとめて起こる（起こらない）
        if from.value > 0
          from.value -= 1
          to.value   += 1
        end
      end
    end
  end
end
rs.each(&:join)

p ACCOUNTS.map(&:value)   #=> [126, 92, 113, 69] （毎回ちがう）
p ACCOUNTS.sum(&:value)   #=> 400 （合計は必ず保たれる）
```

`Ractor.atomically` のブロックが競争に負けると、巻き戻して実行し直されます。ロックを取る順番を考えなくて良いので、デッドロックしません。

#### サンプル 5: ページキャッシュ（`Ractor::KeyLockHash`）

「同じキーは 1 回だけ計算して、あとはみんなで使い回す」という、キャッシュそのものです。8 つの Ractor が 4 種類のページを 3 回ずつ要求しますが、`render` は 4 回しか呼ばれません。

```ruby
require "ractor/keylockhash"
require "ractor/tvar"

CACHE  = Ractor::KeyLockHash.new   # キーごとに独立。読みはロック無し
RENDER = Ractor::TVar.new(0)       # render() が実際に呼ばれた回数

def render(page)                   # 重い処理のつもり
  Ractor.atomically { RENDER.value += 1 }
  sleep 0.05
  "<html>page #{page}</html>"
end

rs = 8.times.map do |i|
  Ractor.new(i) do |i|
    3.times.map do |j|
      page = (i + j) % 4                              # 4 ページを 8 Ractor で取り合う
      CACHE.update(page) {|html| html || render(page) }
    end
  end
end

p rs.flat_map(&:value).uniq.size   #=> 4  （24 回参照して、ページは 4 種類）
p RENDER.value                     #=> 4  （render は 1 ページにつき 1 回だけ）
```

同じキーに同時に殺到しても、計算するのは 1 つの Ractor だけで、残りはその結果を待って読みます。リポジトリ版（git の最新）には、これを直接書ける `store_if_absent(key){ ... }` もあります。

#### サンプル 6: スコアボード（`Ractor::ActiveObject`）

`TVar` などに入れた値は freeze されます。「freeze したくない状態（書き換え続けるふつうの Hash や、メソッドを持つオブジェクト）」を共有したいときは、**その状態を専用の Ractor に住まわせて、呼び出しのほうを送りつけます**。

```ruby
require "ractor/active_object"

class Scoreboard < Ractor::ActiveObject
  def initialize = @scores = Hash.new(0)

  async def add(player, points)    # 返事を待たない（速い）
    @scores[player] += points
  end

  sync def top(n)                  # 返事を待つ
    @scores.sort_by{ -_2 }.first(n)
  end
end

BOARD = Scoreboard.new             # この proxy は shareable。どの Ractor からでも使える

players = %w[ko1 matz mame]
rs = 3.times.map do |i|
  Ractor.new(players[i]) do |name|
    100.times { BOARD.add(name, 1) }
    BOARD.top(3)
  end
end
rs.each(&:value)

p BOARD.top(3)  #=> [["ko1", 100], ["matz", 100], ["mame", 100]]
```

状態は 1 つの Ractor が持っていて、呼び出しは 1 件ずつ順番に実行されます。ロックはどこにもありません。代わりに、呼び出しごとにメッセージの往復があります（`sync` で数 µs）。返事が要らないものは `async` にすると、その往復がなくなります。

`examples/` に 19 本のサンプル（銀行、座席予約、フィーチャーフラグ、LRU キャッシュ、API ゲートウェイ、pub/sub など）があるので、自分の用途に近いものを探してみてください。

### punions：Ractor でアプリケーションサーバを書く

[ko1/punions](https://github.com/ko1/punions) は、**Ractor でアプリケーションサーバを書くとどうなるか**を確かめるための実験場です。Puma の部品を使って作った 2 つのサーバと、共通の WebSocket / Action Cable レイヤ、そして 12 個のデモゲームが入っています。

| | 作り |
|---|---|
| Puma | スレッドプール ＋ リアクタ（そのまま） |
| PuMaNy | 接続ごとに 1 スレッド（M:N スケジューラ任せ） |
| Punicorn | **接続ごとに 1 Ractor**（接続ごとに GVL がある） |

同じゲームが 3 つのバックエンドで動くので、設計の違いをそのまま比べられます。

```sh
$ git submodule update --init                  # puma/
$ tools/build_exts.sh /path/to/ruby            # puma_http11 + ws_mask
$ gem install rack
$ /path/to/ruby punicorn/bin/punicorn --cable -p 9292 examples/ws/demos.ru
```

ブラウザで `http://localhost:9292/` を開くとデモの一覧が出ます。花火、Pong、シューティング、もぐらたたき、早押し、フラクタル、Life、chat……と、それぞれ別の並行性の形（ブロードキャスト、部屋ごとの Ractor、共有ワールド、接続ごとの CPU 並列）を見せるために作られています。**複数のタブ（できれば複数人）で開くと面白いです。**

見どころを 2 つだけ。

* **接続を「持ち続ける」とどうなるか**：WebSocket を 5 本張った状態で、普通の HTTP ページを取りに行ってみてください。`puma -t 5` ではスレッドプールが尽きて HTTP が返らなくなります（だから Action Cable は Rack からソケットを hijack して自前のループを回しています）。接続ごとにスレッド／Ractor を持つ 2 つは、そのまま返ってきます。
* **`examples/ws/mini_db.rb`**：Ractor そのものが KV ストアになっています。問い合わせはメッセージなので、ロック無しで `incr` や `setnx` がアトミックです。1 プロセスで全コアを使える Punicorn だから、プロセス内の actor が共有ストアとして成立する、という例です（`puma -w 8` なら Redis が要るところです）。

各サーバの README（[punicorn/README.md](https://github.com/ko1/punions/blob/master/punicorn/README.md)、[pumany/README.md](https://github.com/ko1/punions/blob/master/pumany/README.md)）に、設計の議論と計測結果が入っています。

## 発展課題

* サンプル 2 のログ集計を、**自分の手元にある本物のログ**で動かしてみる。`lanes:` や `each_slice` の数を変えると、どこで頭打ちになるか。
* 自分がよく書く処理（ログの集計、画像の変換、テキストの検索など）を Ractor で並列化してみて、どのくらい速くなるか測る。速くならなかったら、なぜかを調べる（送っているオブジェクトが大きい？ 直列の部分が残っている？）。
* サンプル 9（ワーカプール）を、ractor-pipeline を使わずに「空いたワーカに次の仕事を渡す」形に書き直してみる。そのうえで ractor-pipeline の実装（`lib/ractor/pipeline.rb`）を読んで、どうやっているか見比べる。
* punions のデモを動かして、ゲームを 1 つ読んでみる。別のゲームを足してみる。
* Ractor で書こうとして「書けなかった」ことを整理して、[Redmine](https://bugs.ruby-lang.org/projects/ruby-master/issues) に投げる。エラーメッセージが不親切だった、という報告も歓迎です。
* `test/ruby/test_ractor.rb` を読んで、テストされていない挙動を見つけ、テストを追加する。
* `ractor.rb` の rdoc を読んで、実際の挙動と食い違っているところを見つけて直す（experimental な機能なので、ドキュメントが実装に追いついていないことがあります）。

なお、Ruby にはもう 1 つ experimental な「分ける」仕組みがあります。Ractor が状態を分けるのに対して、定義（クラス・モジュール・定数）を分けるのが `Ruby::Box` です。[(8) Ruby::Box を触ってみよう](8_box.md) をどうぞ。
