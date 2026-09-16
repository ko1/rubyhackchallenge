# EURUKO 2026: Let's try Ractor with the latest Ruby

* Event: [EURUKO 2026](https://2026.euruko.org/), Brno, Czech Republic
* Conference days: September 17 (Thu) and 18 (Fri), 2026 (the BRUG meetup and welcome drinks are on the 16th)
* This workshop: one of the workshops on **Friday afternoon, September 18**
* Agenda and workshop registration: <https://2026.euruko.org/agenda.html>
* Material: [(7) Let's try Ractor](../EN/7_ractor.md)

## What we will do

Ractor is Ruby's mechanism for parallel programming, and it is still experimental — the API changed in Ruby 4.0 and is changing again in 4.1. In this workshop we run Ractors on the **latest Ruby (the `master` branch)**, together, and see what works, what doesn't, and what is awkward.

Roughly:

1. Check your build of `master` (see "Before you come" below)
2. Create Ractors, and confirm that they really run in parallel (and that threads don't)
3. Send messages: the default port, `Ractor::Port`, `Ractor.select`, `Ractor#monitor`
4. Shareable objects, copying and moving
5. Run into the restrictions on purpose, and read the error messages
6. Write a small worker pool
7. A look at where Ractor lives in the MRI source code
8. Play with [ractor-pipeline](https://github.com/ko1/ractor-pipeline), [ractor-sharing](https://github.com/ko1/ractor-sharing) and [punions](https://github.com/ko1/punions)
9. If there is time: `Ruby::Box`, the other experimental feature of Ruby 4.0 — two versions of one library in one process ([(8) Let's try Ruby::Box](../EN/8_box.md))

The full material is in [(7) Let's try Ractor](../EN/7_ractor.md). You can work through it on your own, before or after the workshop.

**What we want from you**: what you wanted to write and couldn't, error messages that didn't tell you enough, and programs that didn't get faster. Ractor needs reports from actual use more than anything else right now, and ko1 (the author of Ractor) will be in the room.

## Before you come

**Please build Ruby from the `master` branch before the workshop.** The conference network will not enjoy 40 people cloning `ruby/ruby` at the same time, and a build takes a while.

```
$ sudo apt-get install git ruby autoconf gcc make zlib1g-dev libffi-dev libreadline-dev libgdbm-dev libssl-dev libyaml-dev  # Debian/Ubuntu
$ git clone https://github.com/ruby/ruby.git
$ cd ruby && ./autogen.sh && cd ..
$ mkdir build && cd build
$ ../ruby/configure --prefix=$PWD/../install --enable-shared
$ make -j
$ ./ruby -v   #=> ruby 4.1.0dev (...) [x86_64-linux]
```

Then check that Ractor runs:

```
$ ./ruby -W:no-experimental -e 'p Ractor.new{ 42 }.value'  #=> 42
```

For the last part of the workshop we write small applications with two gems. Installing them beforehand saves the conference network again:

```
$ make install                                        # into workdir/install/
$ ../install/bin/gem install ractor-pipeline ractor-sharing
```

See [(2) MRI source code structure](../EN/2_mri_structure.md) for the details, including macOS notes and what to do when the build fails.

**Using an LLM or a coding agent is encouraged** — before the workshop and during it. Paste your build error into one; ask it what a function in `ractor.c` does; have it draft a parallel version of your program. We would much rather you spend the afternoon finding out what Ractor can and cannot do than fighting a missing `libyaml-dev`. Two things to keep in mind: check what you are told by running it (that is what the whole workshop is about), and remember that Ractor's API changed in Ruby 4.0, so agents tend to suggest the removed `Ractor#take` / `Ractor.yield` — showing them `ractor.rb` from your checkout fixes that.

And if you are still stuck on the build, come anyway: we will sort it out at the beginning of the workshop.

## What to bring

* A laptop with the `master` build above (a Docker or devcontainer build is fine too; see [`docker/`](../docker/))
* Ideally, a small program of your own that you would like to make parallel

## About Ruby Hack Challenge

This workshop is part of the [Ruby Hack Challenge](https://github.com/ko1/rubyhackchallenge), a set of materials for hacking MRI (the Ruby interpreter) internals: building it, adding methods, fixing bugs, and improving performance. If you enjoy the workshop, the other chapters are there to take further.
