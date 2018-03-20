# Task ideas

Here are some ideas for the Ruby Hack Challenge. 
Feel free to choose any of them or try your own hacks.

Before your hack, please file your hack topic as a Github issue.
This issue should contain:

* Hack topic summary
* Your name

## Run tests on your specific environment

Ruby has test suites (explained in lecture materials).
We run tests on some environments (you can check https://rubyci.org) periodically, but not all environments.

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

We file all issues on Redmine <https://bugs.ruby-lang.org/issues/> and there are many unresolved tickets.

(1) Bug tickets

We need to fix many bugs but there we dont have enough resources.
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

(2) Feature tickets

There are several feature-request tickets.

(2-1) Consider the feature request

Please consider new features and report your thoughts.
Concrete use-cases based on your experiences will be help us.
Conversely, thoughts on just your feelings is not usually enough.
Fact is preferable (for example, consistency with other features, other languages and so on).

(2-2) Try to implement a feature request

Some tickets contains patches to implement it. Try it and report how you like it or not.

(2-3) Implement feature requests

Some tickets do not contain patches.
Please implement them.

For example, ko1's ticket <https://bugs.ruby-lang.org/issues/14609> is very easy to implement.

## Visualization

Now you can modify MRI by yourself!
You can insert any "printf" into MRI c source code to see the behavior.
This is a very simple *Visualization*.

Add your original visualization feature on terminal, GUI, sound or something cool.

## Add your performance counter

ruby/debug_counter.[ch] provides a feature to add/show performance counters.
Read implementation and try them.
After that, feel free to add your performance counters to check the *true* behaviour.

