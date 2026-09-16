# (1) Introduction of MRI development culture

## About this document

This document introduces the development culture of MRI. MRI: Matz's Ruby Interpreter (a.k.a. the ruby command you are using) is OSS: Open Source Software. Development of MRI started in 1993 (published in Dec. 1995). Because MRI is OSS, anyone can join in its development. However if you don't know anything about MRI development, it is hard to join. So, this article introduces how we develop MRI.

This document contains:

* How to develop MRI (development flow and support tools)
* How to manage bug tickets
* How to learn about MRI internals and how to get information about the community
* What kind of unsolved issues are there in MRI?

## MRI development flow

Ruby is OSS so that anyone can participate.

"Ruby development" has two meanings:

* Ruby language specification.
* MRI implementation which is one of Ruby implementation.

MRI is the reference implementation of the Ruby language, so that approved Ruby features are implemented on MRI. If we fix a bug in MRI, it means that we also change Ruby's specification. Therefore, when deciding whether to fix bugs, care must be taken to consider loss of compatibility. To be precise, several MRI-specific features exist, such as virtual machine instructions, so not all changes to MRI result in a change to Ruby's specification.

### Repository and Ruby committers

MRI is developed on GitHub: <https://github.com/ruby/ruby> (the repository is also available at <https://git.ruby-lang.org/ruby.git>). Some people have a right to modify this repository. We call them "Ruby committers". Now we have about 100 Ruby committers all over the world (but the number of active members is much smaller. If you become a Ruby committer, you can't throw away the title of "Ruby committer").

Committers can modify any of the source code of MRI. However, each committer has an area of responsibility. If a committer wants to modify another area, he/she is expected to ask and respect the advice of the responsible committers. For example, ko1 is a VM developer, so that if someone wants to change the VM drastically, he wants to be consulted before any changes are committed.

Changes used to be pushed directly to the repository. Nowadays, committers and non-committers alike propose changes as pull requests, CI runs on GitHub Actions, and the change is merged after review. This is not a rule, though: a committer may merge a change in their own area without a review. For a big change, we ask other committers for a review. We use `git bisect` (or similar techniques) to investigate problems (e.g. bug reports), as we always did.

## Ticket management

We use [Redmine](https://bugs.ruby-lang.org/issues/), a bug tracker, to discuss specification changes, bug reports, and so on. A ticket is filed for each issue.
Notifications of new tickets and any changes about tickets are delivered to the Ruby mailing lists.
There are mailing lists in  English (ruby-core) and Japanese (ruby-dev).
<https://www.ruby-lang.org/en/community/mailing-lists/>

Most important issues/proposals are filed in English.
Tickets written in Japanese are also acceptable for easy and small issues.

Tickets can be divided into two categories: "Feature request" and "Bug report".

* Feature requests
  * Requests for additions or changes to the Ruby language itself.
  * incidentally, Redmine's URL <https://bugs.ruby-lang.org/projects/ruby-master/> contains the word "bugs" :)
* Bug reports
  * Strange behaviour, performance issues and so on. Everything except for changes to the specification.

When you submit a ticket, you will be asked to choose a description language (English or Japanese). The forwarded mailing list is chosen by this specified language (ruby-core or ruby-dev).

Good bug reports should contain the following:

* Summary
* Reproducible code and environment information to reproduce it (the result of ruby -v, OS, compiler's version and so on)
* Expected behavior.
* Actual behaviour exhibited.
* A patch which solves the issue (if possible).

For details, please check <https://github.com/ruby/ruby/wiki/How-To-Report> (English)
or Japanese version <https://github.com/ruby/ruby/wiki/How-To-Report-JA>.

Good feature request should contain the following:

* Abstract (short summary)
* Background (What is the issue you want to solve and why. Use-cases)
* Proposal
* Implementation (if possible)
* Evaluation
* Discussion
* Summary

For example, if you submit a "Feature request", then you will certainly be asked "what are your actual use cases?"
This is an extreme example: if you proposed that "this feature should be changed because of inconsistency, but I don't use this feature any more", then your proposal will be rejected (fixing inconsistency is not more important than compatibility).

For further information, please check <https://github.com/ruby/ruby/wiki/How-To-Request-Features>.

Note that the issue tracker is disabled on <https://github.com/ruby/ruby>: Redmine is the primary place for bug reports and proposals. Pull requests, on the other hand, are used every day. If you have a bug fix, a documentation fix or a performance patch, sending a pull request is the most straightforward way to contribute.

However, a change of the language specification (a new feature, or an incompatible change) is not decided by a pull request. File a ticket on Redmine, discuss it there, and it will eventually be discussed at a developer meeting where matz makes the decision.
If your pull request gets no response, file a ticket on Redmine and link to it, or try to contact a Ruby committer directly.

## CI on MRI

MRI is a big and complex piece of software, so it is necessary to use automated testing for Quality Assurance (QA). At the time of writing, `ruby/test/` has about 900 files and 290,000 lines, and `ruby/spec/` has about 5,000 files and 360,000 lines.

We also need to prepare a variety of environments to run our tests. For example, well-known OSes such as Linux, macOS, Windows, as well as lesser known OSes \*BSD, Solaris and so on.
Usually we use Intel x86/64 CPU or ARM processors, but there are other processors that we try to test on.
The list of Ruby's supported platforms can be found at: <https://bugs.ruby-lang.org/projects/ruby-master/wiki/SupportedPlatforms> (the "Supported platforms" section of each release's NEWS also lists the changes).

Because MRI is used in many enviroments, it is preferable to run tests on as wide a variety of environments as possible.
It's common practice to use Continuous Integration (CI) to run automated tests. Ruby is no exception.

The first CI to report back in daily development is GitHub Actions. Every pull request to `ruby/ruby`, and every push to master, is built and tested on Linux (Ubuntu), macOS, Windows (MSVC/MinGW/Cygwin/WSL), several compilers, YJIT/ZJIT, WebAssembly and cross-compilation targets. The definitions are in `.github/workflows/`.

The environments GitHub Actions can offer are limited, though. To test on a wider variety of environments, we also run the <https://rubyci.org> site, which collects the results of tests performed elsewhere. Typically, a CI system uses its own computing resources. However, our resources are limited. So, instead of preparing and managing the computers for the multitude of environments we need, we gather the results from tests run by volunteers in the community who run tests on their own computing resources. The tool [chkbuild](https://github.com/ruby/chkbuild) builds Ruby, runs tests, generates results, and performs a diff on the output so that we can determine which versions of Ruby have particular bugs.

`chkbuild` is good test/CI framework but, for various reasons (for example, chkbuild downloads source code each time) it can be quite slow (typically tens of minutes). To overcome this limitation, we use another CI system <http://ci.rvm.jp/> that can reuse previous builds, and can build/test in parallel, reducing the time required for testing to the order of 2-3 minutes. This allows us to run our tests hundreds of times every day, which can be helpful for revealing hard-to-reproduce bugs (e.g. timing bugs).

Ruby committers are expected to run tests on their own machines.
If a Ruby committer accidentally merges a change that doesn't pass the tests, the error should be detected on GitHub Actions or <http://ci.rvm.jp/>, and committers are alerted on their Slack.

## Unresolved issues on MRI

Ruby / MRI has many unresolved issues. The following issues are examples of them.

* Specification
  * New features and incompatible changes for each release (Redmine tickets and developer meetings)
  * Turning experimental features into normal ones (Ractor, `Ruby::Box`, ...)
* Performance
  * Make ZJIT (the new JIT compiler introduced in Ruby 4.0) faster than YJIT and production-ready
  * Steady improvements of the interpreter, GC and method dispatch
  * Benchmarking framework and benchmarks
* Concurrency and parallelism
  * Graduate Ractor from "experimental" (stable API, performance, usable libraries)
  * The M:N thread scheduler and the Fiber scheduler
* Documentation
* Bug fixes

The following issues are problems I (ko1) want to fix:

* Make Ractor practical to use
  * Libraries to share state between Ractors (<https://github.com/ko1/ractor-sharing>)
  * A nicer API to write parallel programs with Ractors (<https://github.com/ko1/ractor-pipeline>)
  * Application servers written with Ractors (<https://github.com/ko1/punions>)
* Performance of the per-Ractor GC and of the M:N thread scheduler
* Provide a CI service to test and benchmark gems on master

## Information about Ruby development

### How to hack MRI internals

Please refer to the [Bibliography](../bib.md).

If you want to hack deeply into MRI, you need to know the C language.

### Communication channels

* Ruby's Redmine: https://bugs.ruby-lang.org/projects/ruby-master/
    * Ticket
    * Wiki
* GitHub: https://github.com/ruby/ruby
    * Pull requests and reviews (the issue tracker is disabled)
* Mailing lists
    * https://www.ruby-lang.org/en/community/mailing-lists/ (En) https://www.ruby-lang.org/ja/community/mailing-lists/ (Ja)
    * ruby-core (English)
    * ruby-dev (Japanese)
* Conferences, meetups
    * RubyConf, EURUKO and other international conferences
    * Japan domestic
        * RubyKaigi
        * Regional RubyKaigi
        * Asakusa.rb, *.rb
* Ruby developers meeting (monthly)
    * The agenda is collected in advance on a "DevMeeting" ticket on Redmine. If you have something to ask, write it there and it will be discussed.
* Chat
    * The chat rooms of the Ruby community (Discord and others) are listed on <https://www.ruby-lang.org/en/community/>.
* Contact individually
    * Social networks (matz is @yukihiro_matz on X, for example)

## Important note

This article introduces several rather pedantic "rules". However, what we interpreter developers value the most is "Hacking".
If you contribute a great patch, we will support your contribution, even if you don't strictly abide by the above rules.

Write code, and have fun!
