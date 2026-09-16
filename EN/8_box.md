# (8) Let's try Ruby::Box

## About this document

`Ruby::Box` **separates class and module definitions inside one process**. It is an experimental feature introduced in Ruby 4.0 [[Feature #21311]](https://bugs.ruby-lang.org/issues/21311).

It may be easiest to read next to [(7) Let's try Ractor](7_ractor.md):

* Ractor separates **state** (objects).
* Box separates **definitions** (classes, modules, constants).

Both are experimental, and for both, reports from people who actually used them are what is missing most.

The examples in this document were checked with `ruby 4.1.0dev (2026-09-14T04:56:14Z master d568c61094)`.

## Preparation

Box is unavailable **unless the environment variable `RUBY_BOX=1` is set when ruby starts** (setting it after the program has started does nothing).

```
$ RUBY_BOX=1 ./ruby -W:no-experimental box.rb
```

Forget it and you get:

```ruby
p Ruby::Box.enabled?   #=> false
Ruby::Box.new
#=> Ruby Box is disabled. Set RUBY_BOX=1 environment variable to use Ruby::Box. (RuntimeError)
```

With `RUBY_BOX=1`, an experimental warning is printed at startup. `-W:no-experimental` hides it.

```
ruby: warning: Ruby::Box is experimental, and the behavior may change in the future!
See https://docs.ruby-lang.org/en/master/Ruby/Box.html for known issues, etc.
```

## What it is good for

In Ruby, your application, the libraries it loads and every monkey patch are all defined in **the same place** — one space of classes and constants. That is convenient, but:

* Two libraries that define a class of the same name cannot be used together.
* A monkey patch applied by one library affects the whole application.
* If library A needs one version of a gem and library B needs another, one of them breaks.

Box makes the classes, modules and constants defined by the files you load **belong to that box alone**.

## Exercise 1: load a library into a box

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

* `Ruby::Box.new` creates a box; `box.require`, `box.require_relative` and `box.load` load files into it. Whatever those files `require` goes into the same box.
* Constants and classes inside the box are reached through the box: `box::VERSION`, `box::Greeter`.
* Code running inside the box sees **the box's definitions** (the `VERSION` that `Greeter#hello` reads is `"1.0"`).

## Exercise 2: keep a monkey patch inside a box

`box.eval` runs code in the box without writing a file.

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

The change to `String` does not leak out of the box. "I want this library's monkey patches contained" is written directly.

## Exercise 3: two versions of one library at the same time

This is where Box earns its keep. Two incompatible versions, in one process:

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
  def self.calc(n) = n * 3     # an incompatible change
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
p b1::Lib.equal?(b2::Lib)               #=> false (different classes)
p defined?(Lib)                         #=> nil   (not defined outside)
```

Two classes named `Lib` coexist as different classes, and outside the boxes there is no `Lib` at all.

## Kinds of box

Writing code, there are only two to keep in mind.

* **main**: the box where `foo.rb` of `ruby foo.rb` runs. Created automatically at startup.
* **optional**: a box made by `Ruby::Box.new`. Technically the same thing as main.

```ruby
p Ruby::Box.enabled?          #=> true
p Ruby::Box.current           #=> #<Ruby::Box:3,user,main>
p Ruby::Box.current.main?     #=> true
p Ruby::Box.new.main?         #=> false
```

The last part of `box.inspect` (`optional` in `#<Ruby::Box:4,user,optional>`) is the kind.

> Note: the implementation has two more: **root**, where the built-in classes and modules are defined and run (one per process), and **master**, the "master copy" every box is made from, where no code runs. Using Box, you are unlikely to ever care.

That is the whole API:

* Class methods: `enabled?`, `current`, `main`, `root`, `master`
* Instance methods: `require`, `require_relative`, `load`, `eval`, `load_path`, `main?`, `root?`, `master?`, `inspect`

`box.load_path` is that box's own `$LOAD_PATH` (a different object from the outer one).

## What doesn't work yet

It is experimental, so some things don't work. The "Known issues" of [`doc/language/box.md`](https://github.com/ruby/ruby/blob/master/doc/language/box.md) are:

* `RUBY_BOX=1` is required (it is off by default)
* Under `RUBY_BOX=1`, installing native extensions can fail with stack level too deep in `extconf.rb`
* `require 'active_support/core_ext'` can fail
* A method defined in a box may not be visible to built-in methods written in Ruby

One more, found while writing this: **a non-main Ractor cannot create a box.**

```ruby
Ractor.new { Ruby::Box.new }.value
#=> can not set constants of classes/modules created by another Ractor (Ractor::IsolationError)
```

A box created by the main Ractor **can** be passed to a Ractor and used there, though:

```ruby
box = Ruby::Box.new
box.eval("class Worker; def self.work(n) = n * 2; end")

r = Ractor.new(box) {|box| box::Worker.work(21) }
p r.value  #=> 42
```

Only the people who try can find out how far this goes. If you find something that doesn't work, that is worth reporting.

## A look at the implementation

| File | Contents |
|---|---|
| `box.c` | The implementation (about 1300 lines). The methods of `Ruby::Box` are here |
| `internal/box.h` | The data structures |
| `load.c` | Doing `require` / `load` per box |
| `variable.c`, `class.c`, `vm.c`, `proc.c` | The other side: constant lookup, class definition, method lookup |
| `test/ruby/test_box.rb` | The tests (about 1500 lines). **The most accurate description of how far this works today** |
| [`doc/language/box.md`](https://github.com/ruby/ruby/blob/master/doc/language/box.md) | The design document, including known issues and TODOs |

## Advanced exercises

* Take a gem you actually use and `require` it into a box. If it works, good; if it doesn't, **report what happened** — right now that is the most valuable contribution here.
* Pick one TODO from `doc/language/box.md` and start on it.
* Read `test/ruby/test_box.rb`, find behavior that isn't covered, and add a test.
* Combine Box with Ractor and see how far it goes. Can you write "one Ractor per box"?
