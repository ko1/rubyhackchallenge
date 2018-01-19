# (1) Introduction of MRI development culture

## About this document

This document introduces about MRI development cultures. MRI: Matz Ruby Interpreter (a.k.a. ruby command you are using) is OSS: Open Source Software. Development of MRI is started since 1993 (published at Dec. 1995). Because MRI is OSS, everyone can join development. Howeve if you don't know anything about MRI development, it is hard to join. So that this article introduces how we develop MRI.

This document contains:

* How to develop MRI (development flow and suppoprt tools)
* How to manage bug tickets
* How to know MRI internals and how to get community information
* What kind of unsolved issues are there in MRI.

## MRI development flow

Ruby is OSS so that people can join.

"Ruby development" has two meanings:

* Ruby's specification.
* MRI implementation which is one of Ruby implementation.

MRI is the reference implementation of Ruby language, so that approved Ruby features are implemented on MRI. If we fix MRI's bug, it means we change the Ruby's specification (so that we decide bug fix carefully to avoid incompatibility issues). To be exact, there are several features are MRi specific (such as Virtual machine instructions and so on) so that all of MRI's change doesn't mean Ruby's change.

### Repository and Ruby committers

Ruby's primary repository is manged by Subversion <https://www.ruby-lang.org/en/documentation/repository-guide/>. Some people can modify this repository and we call then "Ruby committers". Now we have about 80 Ruby committers all over the world (but active members are not so many. If you become a Ruby committer, you can't throw away the title of "Ruby committer").

Committers can modify all of source code of MRi. However each committer has area in charge. If someone want to modify other area, he/she may need to ask other committers and respect them. For example, ko1 is a VM developer, so that if someone want to change the VM drastically, I want to be asked before commit it.

There are no code review system. Sometimes we check committed patches and point out some issues. Sometimes we use `git bisect` (or similar technique) to find out the issue. If we have big change, we ask other committers to review it.s

BTW, there is a Git mirror on GitHub <https://github.com/ruby/ruby/>.

## Ticket management

Discussions about specification changes, fixing bugs and so on are (should be) filed in a ticket.
Any changes about tickets are delivered into mailing list.
There are ruby-dev mailing list (for Japanese language users) and ruby-core mailing list (for English language users)
<https://www.ruby-lang.org/en/community/mailing-lists/>。

Most of important issues/proposals are filed in English language.
There are several tickets written in Japanese. They should be easy and small issues.

Tickets can be devided into two categories. "Feature request" and "Bug repport".

* Feature requests 
  * Requests for Ruby language itself.
  * BTW, bug tracker's URL <https://bugs.ruby-lang.org/projects/ruby-trunk/> contains "bugs" :)
* Bug reports
  * Strange behaviour, performance issue and so on. All except about specification.

When you submit a ticket, then you need to choose description language (English or Japanese). A mailing list is chosen by this specified language (ruby-core or ruby-dev).

Good bug report should contains the following topics:

* Summary
* Reproducible code and environment information to reproduce it (the result of ruby -v, OS, compiler's version and so on)
* Expected behavior.
* Actual return value.
* A patch which solves the issue (if it is possible).

For details, please check <https://bugs.ruby-lang.org/projects/ruby/wiki/HowToReport> (English)
or Japanese version <https://bugs.ruby-lang.org/projects/ruby/wiki/HowToReportJ.

Good feature request should contains the following topics:

* Abstract (short summary)
* Background (What is the issue you want to solve and why. Use-cases)
* Proposal
* Implementation (if possible)
* Evaluation
* Discussion
* Summary
If you submit a proposal "Feature request", then you will be asked about "what is your actual use cases?"
For example, if you proposed that "this feature should be changed because of inconsistency, but I don't use this feature any more", then your proposal will be rejected (fixing inconsistency is not important than compatibility)..

For further information, please check <https://bugs.ruby-lang.org/projects/ruby/wiki/HowToRequestFeatures>.

Issues or Pull Requests on GitHub will be checked sometimes. In other words, sometimes they are ignored.
I recommend you to make a new ticket on Redmine and refer to GitHub issues and so on.
(Or contact to Ruby committers directly)

## CI on MRI

MRI is big and complex software, so that we need a Quality Assurance (QA) by automatic tests. We have about tests in 5,000 files, 450,000 lines.

We also need to prepare variety of environments we can run tests. For example, Linux, Mac OSX, Windows are popular OSs.
Also we have *BSD, Solaris and so on. Usually we use Intel x86/64 CPU or ARM processors, but there are other processors.
Ruby defines supported platforms: <https://bugs.ruby-lang.org/projects/ruby-trunk/wiki/SupportedPlatforms>

Like this, MRI is used on many enviroments, it is preferable to run tests on variety of environments.
Now a day, it is general to use CI framework for automatic tests. We have prepared CI environments.

We use popular Travis-CI service. We also prepare <http://rubyci.org> site to collect test results on variety of environments.
Usually, a CI system uses own computing resources. However we don't have so many computers.
Instead of preparing all kind of computers, we gather test results on people's computers.
A software "Chkbuild" achieves this kind of collection.
Chkbuild can output with diff style so that we can know difference between the last test result and the current test resullt.


"chkbuild" is good test/CI framework but it has several issues (for example, chkbuild downloads source code each time) and execution time becomes longer (?0 mins).
So we prepare another CI system <http://ci.rvm.jp/> and run many tests with some techniques: Don't remove last build results and reuse them if it is possible, use parallel builds and tests and so on.
Sometimes repeating tests can reveal timing bugs sometimes.

Ruby committers should run tests on their own machines.
If a Ruby committer introduce a bug, at first, <http://ci.rvm.jp/> show alerts.

## Unresolved issues on MRI

Ruby / MRI has many unresolved issues. The following issues are examples of them.

* Specification
  * Ruby 2.6, ...
  * Ruby 3
    * JIT compilation (only for performance? drop backward compatibility?)
    * Static checking
    * Concurrent execution
* Performance
  * Benchmarking framework and benchmarks
  * Performance imprivements
* Documentation
* Bug fixes

The following issues are internal problems I want to fix:

* Improve performance and quality of bytecode serializer.
* Improve method dispatch mechanism.
* Inlining code.
* Increase generational GC supported objects (especially on `T_DATA`).
* Provide CI service to tests gems on trunk.

## Information about Ruby development

### How to hack MRI internals

Please check (../bib.md).

If you want to hack MRI deeply, you need to know C language.

### Communication channlel

* Ruby's redmine: https://bugs.ruby-lang.org/projects/ruby/
    * Ticket
    * Wiki
* Mailing list
    * https://www.ruby-lang.org/en/community/mailing-lists/ (En) https://www.ruby-lang.org/ja/community/mailing-lists/ (Ja)
    * ruby-core (English)
    * ruby-dev (Japanese)
* Conference, meetup
    * RubyConf and other international conferences
    * Japan domestic
        * RubyKaigi
        * RegionalRubyKaigi
        * Asakusa.rb, *.rb
* Ruby developpers meeting (Monthly meeting at Tokyo)
* Contact individually
    * Twitter
        * @yukihiro_matz
        * ...
* Gitter <https://gitter.im/ruby/ruby>

## Important note

This article introduces several rules. However, we interpreter developers make a point of "Hacking".
If you contribute a great patch, we will support your contribution if you don't satisfy the above rules.

Wirte a code with fun.
