# Ruby Hack Challenge (RHC)

## Upcoming events

* [EURUKO 2026](https://2026.euruko.org/) (Brno, Czech Republic, Sep 17-18, 2026): workshop **"Let's try Ractor with the latest Ruby"**, on Friday afternoon, Sep 18
  * details: [events/euruko2026.md](events/euruko2026.md) (**please build Ruby `master` before you come**)
  * material: [(7) Let's try Ractor](EN/7_ractor.md)

## About RHC

"Ruby Hack Challenge" (RHC) is a short guide to hack MRI (Matz Ruby Interpreter) internals.

Periodically we hold an event "RHC" at conferences, companies and other places.

* [Matz, Koichi and Mame celebrate “Ruby Week” at Cookpad, Bristol](https://sourcediving.com/matz-koichi-and-mame-celebrate-ruby-week-at-cookpad-bristol-b1efbde8007)

If you want to hold a RHC event, please ask us.

We provide lecture materials:

* [(1) Introduction of MRI development culture](EN/1_culture.md)
* [(2) MRI source code structure](EN/2_mri_structure.md)
* [(3) Exercise: Add methods to Ruby](EN/3_practice.md)
* [(4) Fixing bugs](EN/4_bug.md)
* [(5) Performance improvements](EN/5_performance.md)
* [(7) Let's try Ractor](EN/7_ractor.md)
* [(8) Let's try Ruby::Box](EN/8_box.md)
* [Task ideas](EN/task_ideas.md)

(chapter (6), about code coverage, is available in Japanese only)

The materials assume the latest MRI: the `master` branch of <https://github.com/ruby/ruby>.

Working through them with an LLM or a coding agent is encouraged — building MRI, reading unfamiliar C code and finding your way around a huge source tree are exactly what they are good at. See [Use LLMs and coding agents as much as you like](EN/2_mri_structure.md#use-llms-and-coding-agents-as-much-as-you-like).

Questions are welcome on [this repository's issues](https://github.com/ko1/rubyhackchallenge/issues).
For general Ruby questions, the [Ruby community page](https://www.ruby-lang.org/en/community/) lists chat rooms and mailing lists.

## (Japanese Guide) RHC とは

### 開催予定

* [EURUKO 2026](https://2026.euruko.org/)（チェコ・ブルノ、2026/9/17-18）で、ワークショップ「Let's try Ractor with the latest Ruby」を 9/18（金）午後に行います
  * 案内: [events/euruko2026.md](events/euruko2026.md)（**参加される方は、事前に Ruby の `master` をビルドしてきてください**）
  * 教材: [(7) Ractor を触ってみよう](JA/7_ractor.md) / [(7) Let's try Ractor](EN/7_ractor.md)


"Ruby Hack Challenge" (RHC) とは、MRI (Matz Ruby Interpreter) の内部をハックするためのガイドです。

定期的に RHC イベントを、カンファレンスや企業、その他の場所で開催しています。

* [Cookpad Ruby Hack Challenge 開催報告](https://techlife.cookpad.com/entry/2017/09/29/224024)
* [Rubyのなかを覗いてみよう！池澤あやかが「Cookpad Ruby Hack Challenge」に参加してみた](https://next.rikunabi.com/journal/20180601_c11/)

「うちでもイベントを開催したい」といったお話があればご一報ください。

教材を用意しています。

* [(1) MRI 開発文化の紹介](JA/1_culture.md)
* [(2) MRI ソースコードの構造](JA/2_mri_structure.md)
* [(3) 演習：メソッドの追加](JA/3_practice.md)
* [(4) バグの修正](JA/4_bug.md)
* [(5) 性能向上](JA/5_performance.md)
* [(6) コードカバレッジを用いた MRI の品質向上](JA/6_coverage.md)
* [(7) Ractor を触ってみよう](JA/7_ractor.md)
* [(8) Ruby::Box を触ってみよう](JA/8_box.md)
* [発展課題](JA/tasks.md)

教材は、最新の MRI（<https://github.com/ruby/ruby> の `master` ブランチ）を前提としています。

LLM やコーディングエージェントと一緒に進めるのを歓迎します。MRI のビルド、慣れない C のコードを読むこと、巨大なソースツリーの歩き方は、まさに彼らの得意分野です。[LLM・コーディングエージェントを使い倒しましょう](JA/2_mri_structure.md#llmコーディングエージェントを使い倒しましょう) もご覧ください。

質問などがあれば、[このリポジトリの issue](https://github.com/ko1/rubyhackchallenge/issues) へお気軽にどうぞ。
Ruby 一般の質問先は [Ruby コミュニティのページ](https://www.ruby-lang.org/ja/community/) にまとまっています。
