# Task ideas

Here are some ideas for the Ruby Hack Challenge. 
Feel free to choose any of them or try your own hacks.

Before your hack, please file your hack topic as a Github issue.
This issue should contain:

* Hack topic summary
* Your name (or names. Group work is also welcome)

After your hack, close this ticket with your achievement summary.

## Run tests on your specific environment

Ruby has test suites (explained in lecture materials).
We run tests on some environments (GitHub Actions for every pull request, and https://rubyci.org and http://ci.rvm.jp/ periodically), but not all environments.

Please try and run the test suite on your environment, and if you have any trouble:

(1) write a report about it.
(2) fix the issues.

## Libraries

`ruby/lib/` contains libraries written in Ruby.
You can modify them without any C knowledge.
Find out your issue and try to fix them.

## Documentation

Ruby's documentation is written in RDoc.
As you can see, RDoc documentation is written in .rb and .c files.

Please add information such as examples and so on.

## Check unresolved issues

We file all issues on Redmine <https://bugs.ruby-lang.org/projects/ruby-master/issues> and there are many unresolved tickets.

(1) Bug tickets

We need to fix many bugs but there we don't have enough resources.
Please help us.

(1-1) Check if the bug is reproducible or not

There are resolved tickets but not closed because of many reasons (for example, forgot to close the issue, resolved accidentally with other issues, and so on).

Please check the bug is reproducible on new versions and report them.
It should be very important information.

(1-2) Make small reproducible code

If a bug report contains a long explanation and reproducible process (for example, install xxx and yyy, run it with zzz and wait for several minutes...), it is very difficult to debug it.

Please try and find out how to reproduce with a small example.
Reproducible code with `make run` is excellent.

(1-3) Try to fix a bug.

Of course, a patch is very welcome.

(1') report new bug ticket you found

And do (1-1) to (1-3).

(2) Feature tickets

There are several feature-request tickets.

(2-1) Consider the feature request

Please consider new features and report your thoughts.
Concrete use-cases based on your experiences will help us.
Conversely, thoughts on just your feelings are not usually enough.
Fact is preferable (for example, consistency with other features, other languages and so on).

(2-2) Try to implement a feature request

Some tickets contains patches to implement it. Try it and report how you like it or not.

(2-3) Implement feature requests

Some tickets do not contain patches.
Please implement them.

Open feature tickets are listed at <https://bugs.ruby-lang.org/projects/ruby-master/issues?set_filter=1&tracker_id=2>. Some of them are small enough to be a good first hack; an implementation often moves a stalled discussion forward.

(2') Make your own feature request

And do (2-1) to (2-3).

For example, there are many methods in ActiveSupport but not in Ruby builtin/standard libary.
Porting them is one topic (but you need to persuade Matz to introduce it).

## Visualization

Now you can modify MRI by yourself!
You can insert any "printf" into MRI c source code to see the behavior.
This is a very simple *Visualization*.

Add your original visualization feature on terminal, GUI, sound or something cool.

## Dig through unresolved tickets with an agent

Redmine has many bug tickets that stalled because nobody could reproduce them (see [(1)](1_culture.md)).
Handing a ticket to a coding agent — write a reproduction script from the description, run it on the Ruby you built, run `git bisect` once you have a lead — takes a lot of the mechanical work off you.

Then **check for yourself that it really reproduces, and that the cause is really the cause**, and comment on the ticket.
Pinning down a reproduction is more than half of solving the bug.

## Play with Ractor

See [(7) Let's try Ractor](7_ractor.md). Write a parallel program with Ractors, find something that doesn't work well (an error message that doesn't tell you enough, a library that can't be used from a Ractor, a case that doesn't scale), and report it. Reports from actual use are exactly what Ractor needs right now.

## Add your performance counter

ruby/debug_counter.[ch] provides a feature to add/show performance counters.
Read implementation and try them.
Try to set `USE_DEBUG_COUNTER` to 1 and run your script. You can see performance counters information.

After that, feel free to add your performance counters to check the *true* behaviour.
