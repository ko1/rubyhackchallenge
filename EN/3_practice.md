# (3) Exercise: Add methods to Ruby

## About this document

Let's try adding some new methods to MRI. This document shows you how to add a new method, step by step. Please follow along in your own environment.

## `Array#second`

Let's add a `Array#second` method. `Array#first` returns the first element of an Array.
`Array#second` will return the second element of an Array.

Here is a definition in Ruby:

```ruby
# specification written in Ruby
class Array
  def second
    self[1]
  end
end
```

Steps:

1. Open `array.c` in your editor.
2. Add a `ary_second()` function definition into `array.c`. A good place to add it is before `Init_array()`.
3. Add the statement `rb_define_method(rb_cArray, "second", ary_second, 0)` to the body of the `Init_array()` function.
4. Write some sample code to try your new method in `ruby/test.rb`, then build and run with `make run`.
5. Add a test in `ruby/test/ruby/test_array.rb`. These tests are written in the minitest format.
6. `$ make test-all` will run the test code you wrote. However, it runs a tremendous number of ruby tests, so you may want to run only the Array-related tests.
  * `$ make test-all TESTS='ruby/test_array.rb'` will test only `ruby/test/ruby/test_array.rb`.
  * `$ make test-all TESTS='-j8'` will run in parallel with 8 processes.
7. Add rdoc documentation of `Array#second` by referencing the documentation of other methods in `array.c`.


One possible implementation of `ary_second()` is shown below. Line numbers may differ because `array.c` is likely to have changed since this document was written.

```diff
diff --git a/array.c b/array.c
index bd24216af3..79c1c1d334 100644
--- a/array.c
+++ b/array.c
@@ -6131,6 +6131,12 @@ rb_ary_sum(int argc, VALUE *argv, VALUE ary)
  *
  */
 
+static VALUE
+ary_second(VALUE self)
+{
+  return rb_ary_entry(self, 1);
+}
+
 void
 Init_Array(void)
 {
@@ -6251,6 +6257,8 @@ Init_Array(void)
     rb_define_method(rb_cArray, "dig", rb_ary_dig, -1);
     rb_define_method(rb_cArray, "sum", rb_ary_sum, -1);
 
+    rb_define_method(rb_cArray, "second", ary_second, 0);
+
     id_cmp = rb_intern("<=>");
     id_random = rb_intern("random");
     id_div = rb_intern("div");
```

A brief explanation follows:

* `ary_second()` is the implementation of the method.
* `VALUE` represents a type of Ruby object in C, and `self` is the method's receiver (i.e. for `ary.second`, the receiver is `ary`). All Ruby methods return a Ruby object, so the type of the return value should also be `VALUE`.
* `rb_ary_entry(self, n)` does the same thing as `self[n]` in Ruby. Therefore, `rb_ary_entry(self, 1)` returns the second element (note: C uses 0-based index).
* The function `Init_Array` is invoked by the interpreter at launch-time.
* The statement `rb_define_method(rb_cArray, "second", ary_second, 0);` defines the `second` method on the `Array` class.
  * `rb_cArray` points to the `Array` class object. The `rb_` prefix is used to indicate it is something Ruby-related, and the `c` means "Class". Therefore, we can infer that `rb_cArray` is Ruby's Array class object. BTW, the module object prefix is `m` (e.g. `rb_mEnumerable` == `Enumerable` module object) and the error class prefix is `e` (e.g. `rb_eArgError` == `ArgumentError` object).
  * `rb_define_method` is a function that defines instance methods.
  * This statement can be read as: "Define an instance method `second` on `rb_cArray`. When `Array#second` is called, then call the `ary_second` C function. This method accepts 0 arguments".

## `String#palindrome?`

Let's define a method `String#palindrome?` that checks if the string is a palindrome or not.

The following code is a sample Ruby implementation of `String#palindrome?` along with some tests.


```ruby
class String
  def palindrome?
    chars = self.gsub(/[^A-z0-9\p{hiragana}\p{katakana}]/, '').downcase
    # p chars
    !chars.empty? && chars == chars.reverse
  end
end

# Small sample program
# Sample palindrome from https://en.wikipedia.org/wiki/Palindrome
[# OK
 "Sator Arepo Tenet Opera Rotas",
 "A man, a plan, a canal - Panama!",
 "Madam, I'm Adam",
 "NisiOisiN",
 "わかみかものとかなかとのもかみかわ",
 "アニマルマニア",
 # NG
 "",
 "ab",
].each{|str|
  p [str, str.palindrome?]
}
```

Translate the above Ruby code into C code.
Please recall the procedure for implementing `Array#second`, and use this procedure to implement `String#palindrome?` in MRI.

Below is one possible solution for implementing `String#palindrome?`.

```diff
diff --git a/string.c b/string.c
index c140148778..0f170bd20b 100644
--- a/string.c
+++ b/string.c
@@ -10062,6 +10062,18 @@ rb_to_symbol(VALUE name)
     return rb_str_intern(name);
 }
 
+static VALUE
+str_palindrome_p(VALUE self)
+{
+  const char *pat = "[^A-z0-9\\p{hiragana}\\p{katakana}]";
+  VALUE argv[2] = {rb_reg_regcomp(rb_utf8_str_new_cstr(pat)),
+                  rb_str_new_cstr("")}; 
+  VALUE filtered_str = rb_str_downcase(0, NULL, str_gsub(2, argv, self, FALSE));
+  return rb_str_empty(filtered_str) ? Qfalse : 
+         rb_str_equal(filtered_str, rb_str_reverse(filtered_str));
+                                     
+}
+
 /*
  *  A <code>String</code> object holds and manipulates an arbitrary sequence of
  *  bytes, typically representing characters. String objects may be created
@@ -10223,6 +10235,8 @@ Init_String(void)
     rb_define_method(rb_cString, "valid_encoding?", rb_str_valid_encoding_p, 0);
     rb_define_method(rb_cString, "ascii_only?", rb_str_is_ascii_only_p, 0);
 
+    rb_define_method(rb_cString, "palindrome?", str_palindrome_p, 0);
+
     rb_fs = Qnil;
     rb_define_hooked_variable("$;", &rb_fs, 0, rb_fs_setter);
     rb_define_hooked_variable("$-F", &rb_fs, 0, rb_fs_setter);
```

Explanation:

* The suffix `_p` indicates a predicate method that returns true or false.
* `rb_reg_regcomp(pat)` compiles the `pat` C string into a RegExp object.
* `rb_str_new_cstr("")` generates an empty Ruby string.
* `str_gsub()` does the same replacement as `String#gsub`.
* `rb_str_downcase()` does the same replacement as `String#downcase`.
* `rb_str_empty()` does the same checking as `String#empty?`.
* `rb_str_reverse()` does the same reordering as `String#reverse`.
* `rb_str_equal()` does the same comparison as `String#==`.

Hopefully, you can see how the C implementation corresponds to the Ruby implementation.

## `Integer#add(n)`

Add a method `Integer#add(n)` which returns the result when `n` is added.

Ruby example definition:

```ruby
class Integer
  def add n
    self + n
  end
end

p 1.add(3) #=> 4
p 1.add(4.5) #=> 5.5
```

Below is one possible solution for implementing `Integer#add`:

```diff
Index: numeric.c
===================================================================
--- numeric.c	(Revision 59647)
+++ numeric.c	(Working copy)
@@ -5238,6 +5238,12 @@
     }
 }
 
+static VALUE
+int_add(VALUE self, VALUE n)
+{
+    return rb_int_plus(self, n);
+}
+
 /*
  *  Document-class: ZeroDivisionError
  *
@@ -5449,6 +5455,8 @@
     rb_define_method(rb_cInteger, "bit_length", rb_int_bit_length, 0);
     rb_define_method(rb_cInteger, "digits", rb_int_digits, -1);
 
+    rb_define_method(rb_cInteger, "add", int_add, 1);
+
 #ifndef RUBY_INTEGER_UNIFICATION
     rb_cFixnum = rb_cInteger;
 #endif
```

This method should accept 1 argument, so the last argument of `rb_define_method()` is `1` and the definition of `int_add()` accepts one parameter with `VALUE n`.

The actual addition is performed in `rb_int_plus()` so we don't need to write any complex code.

Let's try to modify this code to use our own implementation of addition if a given parameter is a `Fixnum` (numbers represented by `Fixnum` are small and can be easily translated both to and from a C `int`).

Note that Ruby 2.4 removed the `Fixnum` and `Bignum` classes. They are now unified into a single `Integer` class. However, MRI still uses Fixnum and Bignum as internal data structures for performance reasons. For example, `FIXNUM_P(bignum)` returns false.

```diff
Index: numeric.c
===================================================================
--- numeric.c	(Revision 59647)
+++ numeric.c	(Working copy)
@@ -5238,6 +5238,22 @@
     }
 }
 
+static VALUE
+int_add(VALUE self, VALUE n)
+{
+    if (FIXNUM_P(self) && FIXNUM_P(n)) {
+	/* c = a + b */
+	int a = FIX2INT(self);
+	int b = FIX2INT(n);
+	int c = a + b;
+	VALUE result = INT2NUM(c);
+	return result;
+    }
+    else {
+	return rb_int_plus(self, n);
+    }
+}
+
 /*
  *  Document-class: ZeroDivisionError
  *
```

`FIXNUM_P(self) && FIXNUM_P(n)` checks to see if `self` and `n` are both `Fixnum`.
If they are `Fixnum`, they are converted into C `int` values with `FIX2INT()`, and then addition is performed using C `int` values. The result is then converted from a C integer value back into Ruby's Integer value with `FIX2NUM()`.

Note: This definition has a bug. See the next document.

## `Time#day_before(n=1)`

Add a method to the Time class to return the time from `n` days ago (with a default value for `n` of 1).

Here is an example definition in Ruby. It returns a result with time reduced by the number of seconds in 24 hours * `n`. This is not a complete solution because it will occasionally be incorrect (e.g. when there are leap seconds, daylight saving time, etc). We'll ignore these problems here because this is simply an illustrative example.

```ruby
class Time
  def day_before n = 1
    Time.at(self.to_i - (24 * 60 * 60 * n))
  end
end

p Time.now               #=> 2017-08-24 14:48:44 +0900
p Time.now.day_before    #=> 2017-08-23 14:48:44 +0900
p Time.now.day_before(3) #=> 2017-08-21 14:48:44 +0900
```

Here is a definition written in C:

```diff
Index: time.c
===================================================================
--- time.c	(Revision 59647)
+++ time.c	(Working copy)
@@ -4717,6 +4717,22 @@
     return time;
 }
 
+static VALUE
+time_day_before(int argc, VALUE *argv, VALUE self)
+{
+    VALUE nth;
+    int n, sec, day_before_sec;
+
+    rb_scan_args(argc, argv, "01", &nth);
+    if (nth == Qnil) nth = INT2FIX(1);
+    n = NUM2INT(nth);
+
+    sec = NUM2INT(time_to_i(self));
+    day_before_sec = sec - (60 * 60 * 24 * n);
+
+    return rb_funcall(rb_cTime, rb_intern("at"), 1, INT2NUM(day_before_sec));
+}
+
 /*
  *  Time is an abstraction of dates and times. Time is stored internally as
  *  the number of seconds with fraction since the _Epoch_, January 1, 1970
@@ -4896,6 +4912,8 @@
 
     rb_define_method(rb_cTime, "strftime", time_strftime, 1);
 
+    rb_define_method(rb_cTime, "day_before", time_day_before, -1);
+
     /* methods for marshaling */
     rb_define_private_method(rb_cTime, "_dump", time_dump, -1);
     rb_define_private_method(rb_singleton_class(rb_cTime), "_load", time_load, 1);
```

Explanation:

* To define a method that accepts optional arguments, `-1` is specified as the last argument of `rb_define_method()`. This means this function does not know how many methods it will receive until it is called.
* The function `time_day_before(int argc, VALUE *argv, VALUE self)` is the definition of the method. `argc` is the number of arguments given when it was called, and `argv` is a pointer to a C array of size `argc` objects of type `VALUE`.
* `rb_scan_args()` is called to check the method arguments. `"01"` means that the number of required parameters is 0 and optional parameters is 1. This means that this method accepts 0 or 1 parameters. If 1 argument is passed, then it is stored in `nth`. If there are no arguments, then `nth` will contain `Qnil` (the C representation of Ruby's `nil`).
* To call Ruby's method `Time.at()`, `rb_funcall(recv, mid, argc, ...)` is used.
  * The first argument is the method's receiver (`recv` in `recv.mid(...)`). In the case of `Time.at`, the receiver is `Time`.
  * The name of the method called by `rb_funcall` is specified by its `ID`, a Symbol. To generate the `ID` in C, we use `rb_intern("...")`. An `ID` is a unique value for a C string in a Ruby process. In Ruby it is called a Symbol, and in Java it is an `intern`ed string.
  * We want to call `Time.at` with 1 argument, so we specify `1` and pass the actual argument `INT2NUM(day_before_sec)` as the final parameter.

There are a number of problems with this implementation. Try comparing it with Ruby's actual implementation and see if you can understand the differences.

## Extension libraries

C extension libraries allow us to extend the functionality of MRI without modifying MRI itself.
We can make C extension libraries using almost the same process as we use to hack on MRI internals.

For example, let's make an extension library to add the `Array#second` method instead of modifying MRI itself.

Steps to make an `.so` file (extension library):

1. Make a directory named `array_second/`.
2. Make a file named `array_second/extconf.rb`.
  * In this file, `require 'mkmf'` to enable the mkmf library. We can use mkmf to generate a Makefile and perform any configuration needed for the library.
  * After adding configuration (in this case, we don't have any configuration), call `create_makefile('array_second')`. This method creates a Makefile.
3. Make a file named `array_second.c`.
  * Add the line `#include <ruby/ruby.h>` to the top of the file to enable the MRI C-API.
  * This file should contain (1) method body and (2) code that adds the method into `Array`.
  * (1) is the same as `ary_second()` written earlier.
  * (2) should be the `Init_array_second()` function, which calls `rb_define_method()`. The name `Init_array_second` is inferred from the argument passed to `create_makefile` in `extconf.rb`.
4. Run `$ ruby extconf.rb` to generate the Makefile.
5. Run `$ make` to build `array_second.so`. You will then be able to `require` this file. Example: `$ ruby -r ./array_second -e 'p [1, 2].second'` will show `2`.
6. `$ make install` installs .so file into install directory.

A sample `array_second` directory is available in this repository for you to reference.

Except for the `extconf.rb` and the installation steps, the Ruby extensions are defined in exactly the same way as Ruby's embedded methods and classes.

To distribute extension libraries, the minimum requirement is to create a package with the files made in step 2 and 3. It's probably more convenient for your users if you package your extension as a RubyGem.

## Tips: Debugging

Please refer to https://docs.ruby-lang.org/en/2.5.0/extension_rdoc.html for a detailed explanation of writing Ruby extensions.

Browse through the MRI source code to find methods which perform functions that are similar to what you want to add.

When you write Ruby programs, you probably already use `p(obj)` to inspect objects. In C, you can use `rb_p(obj)` to perform the equivalent function.

If you can use gdb, breakpoints will help you.
If you add the line `#include "vm_debug.h"`, you will be able to use the `bp()` macro to set a breakpoint. `make gdb` will stop on this macro, similar to when you use `binding.pry` or `binding.irb`.

gdb allows you to use `p expr` to show the value of `expr` (for example, you can see a value of a variable `foo` with `p foo`). The type `VALUE` is just an integer value in C, so it may be difficult to determine what kind of Object it is and what data it represents. The special command `rp` for gdb (defined in `ruby/.gdbinit`) is provided to give a human-readable representation for VALUE-type data.


## Advanced Exercises

Try solving the following challenges. `grep` will help you to find similar implementations in the source code of MRI.

* Implement `Integer#sub(n)` which subtracts n from an integer value.
* `Array#second` returns `nil` if there is no second element. This is because `rb_ary_entry()` returns `nil` when the specified index exceeds the size of an array. Instead, raise an exception when there is no second element. Use `rb_raise()` function to raise an error.
* `String#palindrome?` is an inefficient implementation. Identify which part is inefficient and consider how to resolve the inefficiency. Try implementing a solution to improve its performance.
* `Time#day_before` is an awkward name. Think of a better method name.
* Let's play a trick on MRI. For example, change the behaviour of `Integer#+` to perform subtraction instead. This hack will break your ruby build, so make a new git branch and experiment to see what happens.
* Use your imagination and try to add an interesting new method.

The following topics are discussed in next chapter, but try to explore them yourself before proceeding:

* I described that `Integer#add(n)` had a bug.
  * Write a test which fails due to this bug.
  * Solve the issue and make the test pass.
* What is a problem with our implementation of `Time#day_before`? There is a similar problem in `Integer#add(n)`.
