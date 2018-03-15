
# (5) Performance improvements

## About this article

This document will present several ideas and tips for performance improvements that can be used in MRI.

## What are performance improvements

When hearing "performance improvement" we most of the time think of increasing the speed of a program, which means usually shorting the execution time, don't you think?
Of course, speed is usually the most important performance factor, but there are others, depending on the given use-case.

There are many performance indicators, I'm writing down those that currently come to mind, but there are probably more.

* time related indicators
  * execution time (throughput)
  * real-time properties (latency)
  * start-up time

* resource related indicators
  * memory consumption
    * count of life objects
    * real memory usage to virtual memory usage gap size (e.g. TLB misses)
    * copy on write affinity of process forking
  * CPU usage (for the same execution time, less usage is better)
  * CPU utilisation probability (does performance improve when adding more CPU power/cores)
  * file descriptors needed for I/O 
  * disc space usage（binary size etc.）

Some of these indicators depend on each other, in correlation or in inverse correlation.

Examples of correletions:

* by dropping memory consumption, cache misses also drop, which improves throughput.
* by reducing the amount of created objects, throughput increases

Examples of inverse correlations:

* to improve the real-time rate, a real-time GC is needed → throughput declines
* having special code paths for often occurring values might increase memory or disc usage

It's important to be aware which of these indicators need to improve, what influence that will have on the other indicators and if that changes are still in acceptable limits.
Furthermore, as computers are constantly evolving, it might be important to reevaluate ones choices that were appropriate in the past.

For instance, a long time ago, memory was the main restriction, but the amount of memory we can use has constantly grown over time.
This time we might want to use cloud computing, which is billed per execution time, so maybe, memory consumption might not be so important now.

It's important to decide what needs improvement right now.

## Performance improvement mindset

### Measuring first

I know this is always said, but it is absolutely important to properly measure the current performance before trying to implement any improvements. 

In case of throughput improvement, it is vital to find the correct places inside the program that are slow.
To find out which parts of MRI need improvement, I use stackprof and the like for ruby-level analysis and Linux' perf command for system-level analysis.

(By the way, these tools don't always tell the truth. In the end, tools produced by humans can't be trusted 100% (especially because it's a difficult and hard to debug field). Sometimes when you have strange outputs you should doubt the tools. To clear your doubts, it's important to understand how these tools work and produce their results.)

### Algorithms and data structures

It's probably common sense that for performance optimization, exchanging the underlying algorithms can have the biggest impact.

For example, let's consider the problem of optimizing the computation of the n-th Fibonacci number. When sticking close to the mathematical definition, we write some code like this:

```
def fib(n)
  if n < 2
    1
  else
    fib(n-2) + fib(n-1)
  end
end

n = Integer(ARGV.shift || 35)
puts "fib(#{n}) = #{fib(n)}"
```
A general improvement would be to develop a JIT compiler (Just-in-Time compiler, compiling at run time), which would ease the workload by substituting the recursive method calls with jump instructions. But we would get a performance improvement of several times to hundred times at best (well, you could argue that that much of an improvement would be fine on its on). 

Of course, there's a faster algorithm to compute the Fibonacci numbers.

```
def fib n
  a, b = 1, 1
  n.times{
    a, b = b, a+b
  }
  a
end

n = Integer(ARGV.shift || 35)
puts "fib(#{n}) = #{fib(n)}"
```
For algorithm classification, we replaced an O(k^n) algorithm with an O(n) one. Depending on n, this algorithm can be much faster than only hundred times compared to the original algorithm.
(By the way, there is an algorithm that computes Fibonacci numbers with O(log n).)

In that sense, it is very important to evaluate whether it is possible to replace the given algorithm.

That is pretty base-level performance improvement knowledge, let me just mention a little bit more.

For instance if we have an algorithm to improve, but we know that the given n is small enough, there might be another algorithm that is more effective in this case (like linear search vs binary search).
Also it can be better to use a simpler and slower algorithm instead of a complex and fast one, because we get it to work earlier and with less bugs. It might not be so fast, but who would want to use an algorithm with (potentially more) bugs inside.
Also, consider we could write a program that runs for 3 seconds and needs 5 minutes development time, or we could write an improved version that runs in only 0.3 seconds, but which would need an hour development time, and let's say we need to run it only once. I guess you'd agree we'd choose the former.

Depending on the problem at hand, we have to be flexible with our methods.

## Adjusting MRI

These are places of MRI that can be improved

* Built-in class methods
  * See if we can improve their algorithms (not only for class methods though). Sometimes we are using ineffective algorithms out of convenience (which are simpler and have less bugs though).
  * Consider specializations for common values. We should optimize for the most used cases. For example, in `Array#[]` we have usually function arguments with small integers (index).
* Standard Extension Library（`lib/`）
  * In Ruby, reducing the allocation of unneeded objects can be effective. <https://github.com/ko1/allocation_tracer> is should be useful.
* Object management, garbage collector
  * Evaluating the GC algorithm. Yet another time?
  * Inspecting the object memory layout.
* VM
  * Review the instruction set.
  * Consider JIT compilation.
  * Consider optimizations of the compiler such as instruction replacement, inlining, etc.

And I think there are yet many other places.

(to be continued, maybe)
