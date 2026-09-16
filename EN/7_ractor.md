# (7) Let's try Ractor

## About this document

Ractor is Ruby's mechanism for parallel programming. The goal of this document is to **actually run Ractors on the latest Ruby (the `master` branch)**.

* What a Ractor is (what you can and can't do with it)
* Exercises: create Ractors, run them in parallel, send messages, share objects
* Where people get stuck
* What changed in Ruby 4.0 / 4.1
* Where to look in the implementation
* Material to play with further

Ractor is still an **experimental feature**. Using it prints a warning, and the API may still change. On the other hand, this is exactly the moment when **feedback from people who actually use it matters most**. "I wanted to write this but I couldn't", "this error message doesn't tell me what is wrong" — such impressions are valuable feedback for Ruby.

The examples in this document were checked with `ruby 4.1.0dev (2026-09-14T04:56:14Z master d568c61094)`.

> Note: this chapter was written for the workshop at [EURUKO 2026](https://2026.euruko.org/) (Brno, on the afternoon of September 18, 2026; [details](../events/euruko2026.md)). You can of course work through it on your own.

## Preparation

Build Ruby from the `master` branch, following [(2) MRI source code structure](2_mri_structure.md). Check the version of the Ruby you built:

```
$ ./ruby -v
ruby 4.1.0dev (2026-09-14T04:56:14Z master d568c61094) +PRISM [x86_64-linux]
```

Using Ractor prints this warning:

```
warning: Ractor API is experimental and may change in future versions of Ruby.
```

Pass `-W:no-experimental` when it gets in your way. The warning is omitted from the examples below.

```
$ ./ruby -W:no-experimental test.rb
```

Simple examples also run on `make run` (miniruby), but examples that use extension libraries (such as `require 'json'`) do not. Use `make runruby`, or the `./ruby` you built.

## What is a Ractor?

You can create several Ractors in one Ruby process. There are two key points:

* **They run in parallel.** In MRI, the GVL (Global VM Lock) is held per Ractor, so several Ractors really do run at the same time. Threads (within one Ractor) do not run Ruby code at the same time.
* **They don't share objects.** Ractors can't share most objects with each other. Only "shareable" objects (numbers, symbols, `true`/`false`/`nil`, frozen strings, classes and modules, ...) can be shared. Everything else is **copied** or **moved** when you pass it.

Thanks to this restriction, data races cannot happen. The class of bug where you forget a lock and corrupt your data is reported as an error — usually the moment you call `Ractor.new`, before anything runs.

|  | Thread | Ractor |
|---|---|---|
| Parallel execution of Ruby code | No (the GVL is shared) | Yes (one GVL per Ractor) |
| Object sharing | Everything is shared | Only shareable objects |
| Data races | Possible (lock it yourself) | Not possible |
| Cost of creating one | Small | Larger than a Thread |

## Exercise 1: Your first Ractor

```ruby
r = Ractor.new do
  puts "Hi, I am #{Ractor.current.inspect}"
  42
end

p r.value  #=> 42
```

Result:

```
Hi, I am #<Ractor:#2 test.rb:1 running>
42
```

* `Ractor.new{ ... }` starts a new Ractor which runs the given block.
* `Ractor#value` waits for the Ractor to finish and returns the value of the block (like `Thread#value`).
* If you don't need the value, use `Ractor#join` (like `Thread#join`).
* `Ractor.count` returns the number of running Ractors (the main Ractor counts as one).

> Note: `Ractor#value` can be used only once. The second call raises `Ractor::Error (The value was already taken)`. The termination value is *moved* rather than copied, so only one Ractor can receive it.

## Exercise 2: Check that they really run in parallel

Parallel execution is the main benefit of Ractor. Let's confirm it.

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

On a machine with 4 or more cores, `sequential` and `N threads` take about the same time, while `N ractors` is clearly faster. That is Ruby code not running in parallel on threads, and running in parallel on Ractors.

If you don't see a speedup, check:

* Do you have enough CPU cores (`nproc`)?
* Is another process using the CPU?
* Is `n` so small that creating the Ractors costs more than the work itself?

## Exercise 3: The block is isolated

The block passed to a Ractor is *isolated*: it can't refer to local variables of the outer scope.

```ruby
a = 1
Ractor.new { p a }
#=> can not isolate a Proc because it accesses outer variables (a). (Ractor::IsolationError)
```

The error is raised before the Ractor starts running (at `Ractor.new`). In other words, "oops, I shared something" is reported before anything can go wrong.

To pass a value, pass it as an argument and receive it as a block parameter:

```ruby
a = 1
r = Ractor.new(a) {|a| a + 1 }
p r.value  #=> 2
```

If the argument is not shareable, it is copied (see below).

To pass a block as a value, make a shareable Proc with `Ractor.shareable_proc` (or `Ractor.shareable_lambda`):

```ruby
pr = Ractor.shareable_proc { |x| x * 2 }
p Ractor.shareable?(pr)                     #=> true
p Ractor.new(pr) {|pr| pr.call(21) }.value  #=> 42
```

`Ractor.shareable_proc` has its own rules about outer variables: a variable that holds an unshareable value, or that may be reassigned, is an error.

```ruby
s = "mutable"
Ractor.shareable_proc { s }
#=> cannot make a shareable Proc because it can refer unshareable object "mutable"
#   from variable 's' (Ractor::IsolationError)
```

```ruby
a = 1
pr = Ractor.shareable_proc { a }  # OK: a is shareable and is never reassigned
p Ractor.new(pr) {|pr| pr.call }.value #=> 1
```

```ruby
a = 1
pr = Ractor.shareable_proc { a }  # the error is raised here,
a = 2                             # because a is reassigned later
#=> cannot make a shareable Proc because the outer variable 'a' may be reassigned.
#   (Ractor::IsolationError)
```

## Exercise 4: Sending messages (the default port)

Ractors cooperate by sending messages. Every Ractor has a "default port": `Ractor#send` sends to it and `Ractor.receive` receives from it.

```ruby
r = Ractor.new do
  msg = Ractor.receive      # waits until a message arrives
  "received: #{msg}"
end

r.send("hello")
p r.value  #=> "received: hello"
```

* `Ractor#send(obj)` (`<<` is the same) returns immediately, whether or not the other side is ready to receive: the message is queued.
* `Ractor.receive` blocks the current thread until a message arrives. `Ractor.receive(timeout: 1)` gives up after the given number of seconds and returns `nil`.

## Exercise 5: `Ractor::Port`

`Ractor::Port` was introduced in Ruby 4.0. A port is a place to receive messages, and only the Ractor which created it can `receive` from it. Anyone holding the port object can send to it.

This makes "collect the results of several workers in one place" straightforward:

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

Result (the order changes from run to run):

```
"worker 0 finished"
"worker 1 finished"
"worker 2 finished"
```

* Create a port with `Ractor::Port.new`. Only its creator can `receive` from it (what that single receiver buys you is discussed in Exercise 9).
* `port.close` closes it. Sending to a closed port raises `Ractor::ClosedError`. Messages already in the queue can still be received.
* `port.receive(timeout: seconds)` is available too.

The Ractor that owns the port is the one that may close it. "The Ractor" — so **another Thread of the same Ractor may close it too**, and a `receive` waiting on it wakes up with `Ractor::ClosedError`.

```ruby
port = Ractor::Port.new
Thread.new { sleep 0.1; port.close }

begin
  port.receive     # waits 0.1 seconds, then:
rescue Ractor::ClosedError => e
  p e.message      #=> "The port was already closed"
end
```

This is the usual way to end a `receive` that is waiting for a message nobody is going to send (waking the waiter on close landed in September 2026). Another Ractor still cannot close it: that raises `Ractor::Error (closing port by other ractors is not allowed)`.

## Exercise 6: Waiting for several Ractors (`Ractor.select` and `Ractor#monitor`)

To handle results in the order they finish, use `Ractor.select`. It accepts Ractors and ports.

```ruby
rs = 3.times.map {|i| Ractor.new(i) {|i| i * 10 } }

until rs.empty?
  r, v = Ractor.select(*rs)
  rs.delete(r)
  p v
end
#=> prints 0, 10 and 20 in the order they finish
```

`Ractor.select(*ports, timeout: seconds)` returns `nil` when the timeout passes.

If you only want to know that a Ractor has finished, use `Ractor#monitor`: a message is sent to the port you give it.

```ruby
port = Ractor::Port.new

r = Ractor.new { :ok }
r.monitor port
p port.receive  #=> [#<Ractor:#2 test.rb:3 terminated>, :exited]

r = Ractor.new { raise "oops" }
r.monitor port
p port.receive  #=> [#<Ractor:#3 test.rb:7 terminated>, :aborted]
```

Since the message names the Ractor, one port can watch a whole group of them. That is all you need to write a supervisor which restarts the ones that died (`:aborted`).

## Exercise 7: Sharing, copying and moving

`Ractor.shareable?` tells you whether an object can be shared.

```ruby
p Ractor.shareable?(1)                   #=> true
p Ractor.shareable?("foo")               #=> false
p Ractor.shareable?("foo".freeze)        #=> true
p Ractor.shareable?([Object.new].freeze) #=> false (the element is not frozen)
```

`Ractor.make_shareable(obj)` freezes `obj` and everything reachable from it, making it shareable.

```ruby
ary = ["hello", "world"]
Ractor.make_shareable(ary)
p [ary.frozen?, ary[0].frozen?]  #=> [true, true]
```

An unshareable object is **copied** (deep copy) when it is sent.

```ruby
str = "hello"
r = Ractor.new { obj = Ractor.receive; [obj, obj.object_id] }
r.send(str)
obj, oid = r.value
p str.object_id == oid  #=> false (it is a different object)
```

When copying is too expensive (or impossible), **move** the object with `move: true`. A moved object can no longer be touched by the sender.

```ruby
str = "world"
r = Ractor.new { Ractor.receive }
r.send(str, move: true)
p r.value        #=> "world"

str.upcase
#=> can not send any methods to a moved object (Ractor::MovedError)
```

## Exercise 8: See what is prohibited

Ractor's restrictions are explained by its error messages. Run into them on purpose and read what they say (run these one at a time: the script stops at the first exception).

```ruby
GOOD = 'good'.freeze
BAD  = 'bad'.dup

Ractor.new { p GOOD }.join   #=> "good" (a shareable constant can be read)

Ractor.new { p BAD }.join
#=> can not access non-shareable objects in constant Object::BAD of a class/module
#   created by another Ractor. (Ractor::IsolationError)

Ractor.new { String.class_eval { def foo; end } }.join
#=> can not modify String because it is created by another Ractor (Ractor::IsolationError)

Ractor.new { at_exit { puts "bye" } }.join
#=> can not call at_exit from non-main Ractors (Ractor::IsolationError)
```

These, on the other hand, work:

```ruby
# define a class inside a Ractor and use it (that Ractor owns it)
r = Ractor.new { c = Class.new { def hello = "hello" }; c.new.hello }
p r.value  #=> "hello"

# require works too
r = Ractor.new { require 'json'; JSON.generate({"a" => 1}) }
p r.value  #=> "{\"a\":1}"
```

> Note: "a class or module can be modified only by the Ractor which created it" is new in 4.1, which is under development ([Feature #22226]). Classes created by the main Ractor — built-in classes such as `String`, and everything `require`d — cannot be modified from another Ractor. In exchange, a Ractor has full use of the classes it creates itself.

## Exercise 9: Putting it together — a worker pool

With the parts above you can write a simple worker pool.

```ruby
def fib(n) = n < 2 ? n : fib(n-1) + fib(n-2)

RN = 4                       # number of workers
result_port = Ractor::Port.new

workers = RN.times.map do
  Ractor.new(result_port) do |result_port|
    while n = Ractor.receive # nil terminates the worker
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

* Each worker receives jobs on its own default port, and sends results to the shared `result_port`.
* Only the Ractor that created a port can receive from it. It looks like a restriction, but **having exactly one receiver** buys you something:
    * **The destination of a message is settled before the program runs.** Reading the code tells you which Ractor touches the object next — the same property that makes `move: true` meaningful. With "one queue everyone pulls from", which worker gets a job is decided only at run time.
    * **A worker can keep state**, because it owns its port: a connection, a cache, an open file. That only works when "this job goes to this Ractor" is decided rather than raced for (punions' one-Ractor-per-connection is this shape).
    * **The mutual exclusion is simpler.** Not absent: the queue is shared between sender and receiver, so MRI takes the receiving Ractor's lock. Simpler, because **the lock to take is always that one** — the receiver's. Only the owner dequeues (`ractor_queue_deq()` in `ractor_sync.c` asserts `GET_RACTOR() == r`), there is no arbitration between readers, and the owner's own threads are serialized by its GVL, so some paths need no lock at all. Several readers would complicate every one of those.
* In exchange, how the work is handed out is yours to decide. Here the jobs are simply dealt out in turn; to give the next job to whichever worker is free, the workers have to say that they are idle. Writing this yourself is a good way to feel where the tedious parts are — and that is what a library like ractor-pipeline (below) takes care of, with pull-based scheduling: a worker hands out tokens saying "I can take two more", and producers send only to a worker they hold a token for.

## Where people get stuck

* **An exception inside a Ractor arrives wrapped in `Ractor::RemoteError`.** The original exception is its `#cause`.

    ```ruby
    r = Ractor.new { raise ArgumentError, "boom" }
    begin
      r.value
    rescue Ractor::RemoteError => e
      p [e.cause.class, e.cause.message]  #=> [ArgumentError, "boom"]
    end
    ```

* **`Ractor#value` works only once.** The second call raises `Ractor::Error (The value was already taken)`. If you only want to wait for termination, use `Ractor#join`.
* **`IO` objects cannot be made shareable.** `Ractor.make_shareable(STDOUT)` raises `Ractor::Error` (but `puts` and friends work).
* **Arguments to the block are copied.** Passing a huge array costs the time and memory to copy it; consider `move: true`.
* **If your program seems to hang**, it is usually waiting in `receive`: nobody sent a message, or a port was not closed. To stop the waiting, use `receive(timeout: seconds)`, or `close` the port from another Thread of the same Ractor (see Exercise 5).

### A tip for asking an LLM

Please do use LLMs and coding agents for Ractor too. Note, though, that the API changed a lot in Ruby 4.0, so **they often write code with the API they learned earlier**. If you see `Ractor#take`, `Ractor.yield` or `Ractor#close_incoming`, those were removed in 4.0.

The quickest fix is to show them the source you have:

* `ractor.rb` — the current API with its rdoc
* `NEWS.md` and `doc/NEWS/NEWS-4.0.0.md` — what changed
* `test/ruby/test_ractor.rb` — working examples

Pasting the error message works well, too: Ractor's error messages are quite specific about what is not allowed.

## What changed in Ruby 4.0 / 4.1

Ractor is under active development, so slightly older articles and sample code may not run as they are. Here are the main changes.

**Ruby 4.0**

* `Ractor::Port` was introduced [[Feature #21262]](https://bugs.ruby-lang.org/issues/21262).
* As a result, `Ractor.yield` and `Ractor#take` were **removed**, and so were `Ractor#close_incoming` / `#close_outgoing`.
    * An old `r.take` usually becomes `r.value` (the termination value), or a receive through a port.
* `Ractor#join` and `Ractor#value` were added (like `Thread#join` / `Thread#value`).
* `Ractor#monitor` / `#unmonitor` and `Ractor#default_port` were added.
* `Ractor.select` now accepts only Ractors and ports.
* `Ractor.shareable_proc` / `Ractor.shareable_lambda` were added.

**Ruby 4.1 (under development)**

* **The GC now runs per Ractor.** Each Ractor collects its own heap, so allocation-heavy parallel programs scale like forked processes.
* `Ractor#monitor` now sends `[ractor, :exited]` (an Array) instead of the bare symbol `:exited` / `:aborted`, so the receiver knows which Ractor finished.
* A class or module can be modified only by the Ractor which created it [[Feature #22226]](https://bugs.ruby-lang.org/issues/22226).
* `at_exit` and `END {}` in a non-main Ractor raise `Ractor::IsolationError` [[Feature #22139]](https://bugs.ruby-lang.org/issues/22139).
* `Ractor::Port#receive`, `Ractor.receive` and `Ractor.select` take a `timeout:` keyword [[Feature #22255]](https://bugs.ruby-lang.org/issues/22255) and return `nil` when it passes. `timeout: 0` means "do not wait": it takes a message if one is already there and returns `nil` otherwise, without even reading the clock.

The M:N thread scheduler also got a lot of work in 4.1 (the next section plays with it).

For the current state, read `NEWS.md` and [`doc/NEWS/`](https://github.com/ruby/ruby/tree/master/doc/NEWS) in the source tree.

## Extra: try the M:N thread scheduler

A Ractor's threads run on the **M:N thread scheduler**: M Ruby threads carried by a smaller number N of native threads. It is switched with an environment variable, so let's try it too (the examples below are on Linux).

`RUBY_MN_THREADS` chooses how much is M:N.

| | main thread | the main Ractor's other threads | a Ractor's threads |
|---|---|---|---|
| `-1` | 1:1 | 1:1 | 1:1 |
| `0` (default) | 1:1 | 1:1 | M:N |
| `1` | 1:1 | M:N | M:N |
| `2` | M:N | M:N | M:N |

`-1` and `2` are new in Ruby 4.1.

### Exercise: count the native threads

Create 1000 Ruby threads and look at how many threads the OS sees.

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

(On a 16-core Linux machine. Run it on yours. The creation time moves a lot with what else the machine is doing; the native thread count and the memory are the steady numbers here.)

1000 native threads become 3, and creating them takes a twentieth of the time. That is the difference for a program that holds many threads which are only waiting — a server with a thread per connection, say.

### Exercise: inside a Ractor it is M:N by default

Even with `RUBY_MN_THREADS` unset, **the threads inside a Ractor are M:N**.

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

`-1` — "not even a Ractor's threads" — is the option added in 4.1. Being able to turn M:N off is what lets you check whether M:N is really what made a difference.

The number of native threads is capped by `RUBY_MAX_CPU` (the number of cores by default).

> Note: `RUBY_MN_THREADS=2` makes even the main thread an M:N thread. The main thread is then no longer bound to one OS thread, so a C extension that keeps state per OS thread has to call `rb_thread_lock_native_thread()`, and what must run on the process's initial thread (macOS AppKit, for instance) does not work.

### What landed around M:N in 4.1

The scheduler got a lot of work in 4.1 (see "M:N thread scheduler" in `NEWS.md`).

* **It scales with the number of waiters and of Ractors.** A timed wait now sits in a hierarchical timer wheel (it used to be inserted into a deadline-sorted list by a linear scan), an fd stays armed in the backend between waits instead of being added and removed around each one, the io-wait bookkeeping is sharded by fd, and a context switch — or leaving and rejoining the shared pool — no longer takes the scheduler's global lock.
* `RUBY_MN_THREADS` gained `-1` and `2` (the table above).
* **The OS thread name is no longer set from the Ruby thread for M:N threads**, because one native thread runs many of them over its life. You can see it from outside:

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

## A look at the implementation

Let's also look at how it is implemented. These are the Ractor-related files:

| File | Contents |
|---|---|
| `ractor.rb` | The Ruby-level definition of the `Ractor` class, with its rdoc. `Ractor.new`, `Ractor#value`, `Ractor::Port` and friends start here. The `__builtin_` and `Primitive.` parts connect to the C implementation |
| `ractor.c` | The core: creating and terminating Ractors, copying and moving messages, deciding what is shareable |
| `ractor_sync.c` | Ports and message passing (send, receive, waiting) |
| `ractor_core.h` | `rb_ractor_t` — the Ractor data structure. It shows what one Ractor owns |
| `internal/ractor.h` | Ractor declarations used inside MRI |
| `thread.c`, `thread_pthread.c` | Threads. A Ractor runs on its own thread, so the M:N thread scheduler lives here too |
| `gc/`, `gc.c` | The GC, including the per-Ractor GC of 4.1 |
| `bootstraptest/test_ractor.rb`, `test/ruby/test_ractor.rb` | The tests. **This is the most accurate description of how Ractor is supposed to behave.** Running and reading them teaches a lot |
| [`doc/language/ractor.md`](https://github.com/ruby/ruby/blob/master/doc/language/ractor.md) | The design document: more detail than this chapter, with many examples |

A good first step is to read `ractor.rb` and follow a method you are curious about into `ractor.c` / `ractor_sync.c`. As in [(3) Exercise: Add methods to Ruby](3_practice.md), inserting a `printf` and running `make runruby` shows you when things are actually called.

## Play with it further: writing an app with Ractors

From here on, let's use Ractor as a tool for writing applications. These are three things ko1 is working on. All of them need the latest Ruby.

### Setup: installing the gems

Install them into the Ruby **you built**, not your system Ruby:

```
$ cd workdir/build
$ make install                                        # installs into workdir/install/
$ ../install/bin/gem install ractor-pipeline ractor-sharing
$ ../install/bin/ruby -W:no-experimental sample.rb
```

`ractor-sharing` contains C extensions, which are built during `gem install`. The examples below were checked with `ractor-pipeline 0.2.0` and `ractor-sharing 0.3.0` on `ruby 4.1.0dev (master d568c61094)`.

### ractor-pipeline: build a parallel pipeline

[ko1/ractor-pipeline](https://github.com/ko1/ractor-pipeline) lets you connect stages like a Unix pipeline, and each stage **becomes a Ractor and runs in parallel**. The worker management that was tedious in Exercise 9 — handing out jobs, collecting results, shutting down — is the library's job.

```text
stream(src) ──> pipe Ractor x lanes ──> Port ──> reduce (in the caller)
```

#### Sample 1: grep across a source tree

Run this in the MRI source directory (`workdir/ruby/`): open every `*.c` and count the lines containing `Ractor`.

```ruby
require "ractor/pipeline"
include Ractor::Pipeline

files = Dir.glob("*.c")

hits = stream(files).
         flat_pipe{ File.foreach(it) }.                   # 1 file -> N lines
         filter_pipe(lanes: 4){ it.include?("Ractor") }.  # filtered on 4 Ractors
         count

puts "#{files.size} files, #{hits} lines"
```

```
$ ../install/bin/ruby -W:no-experimental grep.rb
117 files, 572 lines
```

Check that it agrees with `grep -c Ractor *.c | awk -F: '{s+=$2} END{print s}'`.

#### Sample 2: aggregating an access log

The everyday job: read a JSONL access log and report requests, errors and average response time per path.

The point is to put **2000 lines in one message** and to **let the worker pre-aggregate its chunk**. The caller then merges per-chunk aggregates rather than touching every record. (Every message between Ractors costs a copy, so sending fine-grained elements is what you avoid.)

```ruby
require "ractor/pipeline"
require "json"
include Ractor::Pipeline

def aggregate(lines)                  # 2000 lines -> one small aggregate
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

Output for a 200,000-line (8.6MB) log:

```
/login           33510 req  1069 err  104.9 ms avg
/api/users       33430 req   995 err  140.0 ms avg
/api/search      33362 req   992 err  140.0 ms avg
/api/items       33276 req  1054 err  140.1 ms avg
/healthz         33246 req   964 err  104.4 ms avg
/                33176 req   986 err  105.1 ms avg
```

**Write the same aggregation as a plain `File.foreach` loop and compare the times.** On a 16-core machine here, the serial version took 0.30 s and the pipeline 0.12 s. You don't get a speedup proportional to the cores: reading the file and the final merge are serial, and there is not much work per record besides the JSON parse. Working out **which part is still serial** is the interesting half of this kind of program.

> Note: if you have no log at hand, [examples/logreport.rb](https://github.com/ko1/ractor-pipeline/blob/master/examples/logreport.rb) generates a 400,000-line sample log and runs both implementations for you.

#### Sample 3: stopping an infinite stream

```ruby
require "ractor/pipeline"
include Ractor::Pipeline

p stream(1..).pipe{ it * it }.first(5)  #=> [1, 4, 9, 16, 25]
```

`first` cancels the rest of the stream — the "I've had enough" travels upstream, just like piping into `head` in a shell. An infinite `stream(1..)` is fine.

#### Where people get stuck

* Stage blocks are isolated with `Ractor.shareable_proc`. Capturing a **mutable** outer variable raises `Ractor::IsolationError` where you wrote `.pipe`, not when the pipeline runs (a shareable value is snapshotted instead).
* Whatever a block returns goes through a Port, so it has to be sendable. `Hash.new{ ... }` holds a Proc as its default and cannot cross — build plain hashes (`(h[k] ||= 0) += 1` style).

### ractor-sharing: a place for the state you do have to share

[ko1/ractor-sharing](https://github.com/ko1/ractor-sharing) provides **state that Ractors can share and update**. Ractors get their safety from not sharing, but a counter, a cache or a registry has to be one thing. This library fills exactly that hole and nothing else.

| Class | Reach for it when |
|---|---|
| `Ractor::TVar` | The default. Update several variables **together** (`Ractor.atomically`). No lock order to get wrong, so it cannot deadlock |
| `Ractor::LockVar` | The block must run **exactly once** — it logs, it sends, it does something a retry would repeat |
| `Ractor::LockHash` | One lock for the whole hash: several keys have to change together |
| `Ractor::KeyLockHash` | The keys are independent (caches, memo tables, registries). Reads take no lock and scale |
| `Ractor::ActiveObject` | The state must stay mutable and deserves methods of its own: it lives in a Ractor, and you send it the calls |
| `Ractor::ActorHash` | The same, when a plain Hash is all the interface you need |

#### Sample 4: transfers between accounts (`Ractor::TVar`)

"Two variables change together": eight Ractors move money between four accounts.

```ruby
require "ractor/tvar"

ACCOUNTS = Ractor.make_shareable(4.times.map { Ractor::TVar.new(100) })

rs = 8.times.map do
  Ractor.new do
    500.times do
      from, to = ACCOUNTS.sample(2)
      Ractor.atomically do          # all of this happens, or none of it
        if from.value > 0
          from.value -= 1
          to.value   += 1
        end
      end
    end
  end
end
rs.each(&:join)

p ACCOUNTS.map(&:value)   #=> [126, 92, 113, 69] (different every run)
p ACCOUNTS.sum(&:value)   #=> 400 (the total always holds)
```

A transaction that loses a race is rolled back and run again. There is no lock to take in the right order, so two transactions can never deadlock.

#### Sample 5: a page cache (`Ractor::KeyLockHash`)

"Compute each key once, then everyone reads it" — a cache, in other words. Eight Ractors ask for four pages three times each, and `render` runs four times.

```ruby
require "ractor/keylockhash"
require "ractor/tvar"

CACHE  = Ractor::KeyLockHash.new   # independent keys; reads take no lock
RENDER = Ractor::TVar.new(0)       # how many times render() actually ran

def render(page)                   # pretend this is expensive
  Ractor.atomically { RENDER.value += 1 }
  sleep 0.05
  "<html>page #{page}</html>"
end

rs = 8.times.map do |i|
  Ractor.new(i) do |i|
    3.times.map do |j|
      page = (i + j) % 4                               # 8 Ractors over 4 pages
      CACHE.update(page) {|html| html || render(page) }
    end
  end
end

p rs.flat_map(&:value).uniq.size   #=> 4  (24 lookups, 4 distinct pages)
p RENDER.value                     #=> 4  (rendered once per page)
```

When several Ractors miss the same key at once, one of them computes and the others wait for its result. The repository version (git HEAD) also has `store_if_absent(key){ ... }`, which says this directly.

#### Sample 6: a scoreboard (`Ractor::ActiveObject`)

Values put into a `TVar` and friends get frozen. When the state must stay mutable (a plain Hash you keep writing to, or an object with methods), **let it live in a Ractor of its own and send it the calls instead**.

```ruby
require "ractor/active_object"

class Scoreboard < Ractor::ActiveObject
  def initialize = @scores = Hash.new(0)

  async def add(player, points)    # fire-and-forget (fast)
    @scores[player] += points
  end

  sync def top(n)                  # wait for the answer
    @scores.sort_by{ -_2 }.first(n)
  end
end

BOARD = Scoreboard.new             # the proxy is shareable: usable from any Ractor

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

One Ractor owns the state and runs the calls one at a time. There is no lock anywhere; what there is instead is a message round trip per call (a few µs for `sync`). Calls whose answer you don't need become `async`, which drops the round trip.

`examples/` has 19 of these (a bank, seat booking, feature flags, an LRU cache, an API gateway, pub/sub, ...) — find the one closest to what you are building.

### punions: an application server written with Ractors

[ko1/punions](https://github.com/ko1/punions) is a place to find out **what happens when you write an application server with Ractors**. It holds two servers built from Puma's parts, a shared WebSocket / Action Cable layer, and twelve demo games.

| | Design |
|---|---|
| Puma | Thread pool + reactor (unmodified) |
| PuMaNy | One thread per connection (left to the M:N scheduler) |
| Punicorn | **One Ractor per connection** (a GVL per connection) |

The same games run on all three backends, so the designs are directly comparable.

```sh
$ git submodule update --init                  # puma/
$ tools/build_exts.sh /path/to/ruby            # puma_http11 + ws_mask
$ gem install rack
$ /path/to/ruby punicorn/bin/punicorn --cable -p 9292 examples/ws/demos.ru
```

Open `http://localhost:9292/` and you get the menu: fireworks, Pong, a shooter, whack-a-mole, a reflex game, a fractal, Life, chat. Each one exists to show a different concurrency shape (broadcast fan-out, a Ractor per match, a shared world, per-connection CPU parallelism). **Open several tabs — or better, play with several people.**

Two things worth looking at:

* **What it costs to *hold* a connection.** Open five WebSocket connections and then ask for an ordinary HTTP page. With `puma -t 5` the thread pool is exhausted and the HTTP request is not served (this is exactly why Action Cable hijacks the socket out of Rack and runs its own loop). The two one-per-connection designs answer as usual.
* **`examples/ws/mini_db.rb`.** The key-value store *is* a Ractor: queries are messages, so `incr` and `setnx` are atomic with no lock at all. Punicorn reaches every core in one process, which is what makes an in-process actor a legitimate shared store — where `puma -w 8` would need Redis.

Each server's README ([punicorn/README.md](https://github.com/ko1/punions/blob/master/punicorn/README.md), [pumany/README.md](https://github.com/ko1/punions/blob/master/pumany/README.md)) has the design discussion and the measurements.

## Advanced exercises

* Run Sample 2 against **a real log of your own**. Vary `lanes:` and the `each_slice` size and find where it stops helping.
* Take something you write often (aggregating logs, converting images, searching text) and parallelize it with Ractors. Measure how much faster it gets — and if it doesn't, find out why (are the objects you send too big? is there a serial part left?).
* Rewrite Exercise 9's worker pool so that the next job goes to whichever worker is free, without ractor-pipeline. Then read `lib/ractor/pipeline.rb` and compare it with what you did.
* Run the punions demos and read one of the games. Add another one.
* Write down what you wanted to write with Ractors but couldn't, and file it on [Redmine](https://bugs.ruby-lang.org/projects/ruby-master/issues). "This error message didn't tell me what was wrong" is a welcome report too.
* Read `test/ruby/test_ractor.rb`, find behavior that isn't tested, and add a test.
* Read the rdoc in `ractor.rb` and fix the places where it disagrees with the actual behavior (this is an experimental feature, so the documentation sometimes lags behind the implementation).

Ruby has one more experimental way of separating things: where Ractor separates state, `Ruby::Box` separates definitions — classes, modules and constants. See [(8) Let's try Ruby::Box](8_box.md).
