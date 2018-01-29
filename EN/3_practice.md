# (3) Exercise: Add methods

## About this document

Let's add some new methods into MRI. This document shows how to add a method by step by step. Write codes by yourself.

## `Array#second`

Let's add `Array#second` method. `Array#first` returns first element of  an Array.
`Array#second` returns a second element of an Array.

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

1. Open `array.c`.
2. Add a `ary_second()` function definition into `array.c`. Just before `Init_array()` should be good place to add.
3. Add a line `rb_define_method(rb_cArray, "second", ary_second, 0)` in `Init_array()` function.
4. Build it, write a sample code in `ruby/test.rb` and run with `make run`.
5. Add a test in `ruby/test/ruby/test_array.rb`. These tests are written in minitest format.
6. `$ make test-all` will run write code. However it runs all tremendous number of ruby tests, so you may want to run only Array related tests.
  * `$ make test-all TESTS='ruby/test_array.rb'` and test only `ruby/test/ruby/test_array.rb`.
  * `$ make test-all TESTS='-j8'` and run in parallel with 8 processes.
7. Add a rdoc documentation of `Array#second` by checking other documents.


`ary_second()` should be the following definition (line number should be wrong because `array.c` shold be modified after writing up this document).

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

Explanations:

* `ary_second()` is an implementation of the method.
* `VALUE` represents a type of Ruby objects in C and `self` is the receiver (`ary` where `ary.second`). All Ruby methods return a Ruby object, so the type of return value should be `VALUE`.
* `rb_ary_entry(self, n)` does the same thing `self[n]` in Ruby and `rb_ary_entry(self, 1)` returns the second element (note: C uses 0-based index).
* The function `Init_Array` is invoked at interpreter at the setting up time.
* `rb_define_method(rb_cArray, "second", ary_second, 0);` defines `second` method in `Array` class.
  * `rb_cArray` points the `Array` class object. `rb_` prefix means Ruby related stuff and `c` represents "Class". So we can see `rb_cArray` is Ruby's Array class object. BTW, a module object prefix is `m` (such as `rb_mEnumerable` == `Enumerable` module object) and error classes use `e` prefix (such as `rb_eArgError` == `ArgumentError` object).
  * `rb_define_method` defines instance methods.
  * This line means "define `Array#second` method. If the `Array#second` is called, then call `ary_second` C function. This method accepts 0 arguments".

## `String#palindrome?`

Let's define a method `String#palindrome?` that checks if the string is a palindrome or not.

The following code is a sample definition of `String#palindrome?` with several tests.


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
Please remember the steps of `Array#second` and implement this method into MRI.

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

Explanations:

* `rb_reg_regcomp(pat)` compiles `pat` C string into a RegExp object.
* `rb_str_new_cstr("")` generates an empty Ruby string.
* `str_gsub()` does the same replacement as `String#gsub`.
* `rb_str_downcase()` does the same replacement as `String#downcase`.
* `rb_str_empty()` does the same checking as `String#empty?`.
* `rb_str_reverse()` does the same reordering as `String#reverse`.
* `rb_str_equal()` does the same comparison as `String#==`.

Maybe you can understand corresponding Ruby code and C code.

## `Integer#add(n)`

Add a method `Integer#add(n)` which returns an added result with `n`.

Ruby example definition.

```ruby
class Integer
  def add n
    self + n
  end
end

p 1.add(3) #=> 4
p 1.add(4.5) #=> 5.5
```

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

Actual addition is executed in `rb_int_plus()` so we don't see any complex code.

Let's try to modify this code to add by ourselves if a given parameter is `Fixnum` (small nubmer, easy to translate from C `int` and also translate to).

Note that Ruby 2.4 removed `Fixnum` and `Bignum` classes. They are unified into `Integer` class. However, MRI internal uses Fixnum and Bignum as internal data structure (performance reason). For example, `FIXNUM_P(bignum)` returns false.

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

`FIXNUM_P(self) && FIXNUM_P(n)` checks if `self` and `n` are `Fixnum`.
If they are `Fixnum`, they can be converted into C `int` values so this method returns calculated value with converted integer values.
Calculated value is converted from C integer value into Ruby's Integer value with `FIX2NUM()`.

Note: This definition has a bug. See next document.

## `Time#day_before(n=1)`

Add a method into Time class which returns `n` days ago (default value of `n` is 1).

Here is an example definition in Ruby. It returns reduced time with seconds of 24 hours * `n`.
To be exact, it will be wrong time (because of complex time calculation, such as leap seconds). But we don't care such details because it is an example.

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

Explanations:

* To accept optional arguments (0 or 1 arguments), specify `-1` at the last argument of `rb_define_method()`. It means this function accepts any number of arguments.
* The function `time_day_before(int argc, VALUE *argv, VALUE self)` defines the method. `argc` is a number of given arguments and `argv` is a pointer to a C array of `VALUE` sized `argc`.
* Checking arguments with `rb_scan_args()`. `"01"` means the number of required parameters is 0 and optional parameters is 1. So it means this method accepts 0 or 1 parameters. If 1 parameter is passed, then `nth` points given parameter, and if there are no arguments, then `nth` points `Qnil` (C representation of Ruby's `nil`).
* To call Ruby's method `Time.at()`, `rb_funcall(recv, mid, argc, ...)` is used.
  * The first argument is a receiver (`recv` in `recv.mid(...)`). A receiver of `Time.at` is `Time`.
  * Method name should be `ID` for `rb_funcall`. To generate `ID` in C, we can use `rb_intern("...")`. `ID` is a unique value for a C string in a Ruby process. Ruby's symbol and Java's intern'ed string.
  * We want to call `Time.at` with 1 argument, so we specify `1` and pass actual one argument `INT2NUM(day_before_sec)`.

This implementation has several problems. Let's compare it with a Ruby's implementation.

## Extension libraries

C extension libraries can extend MRI's feature after building MRI.
We can make C extension libraries with the same process with MRI internal hack.

For example, let's make an extension library to add `Array#second` method instead of modifying MRI itself.

Steps to make `.so` file (extension libarary):

1. Make a directory `array_second/`.
2. Make a file `array_second/extconf.rb`.
  * Write `require 'mkmf'` to enable mkmf library. We can use mkmf to make Makefile. We can add configurations with this library. This case we don't need any configurations.
  * After adding configuration (in this case, we can omit configurations), call `create_makefile('array_second')`. This method creates a Makefile.
3. Make a file `array_second.c`.
  * At first, write `#include <ruby/ruby.h>` to enable MRI C-API.
  * This file should contain (1) method body and (2) code that adds the method into `Array`.
  * (1) is the same as `ary_second()` written above.
  * (2) should be `Init_array_second()` function which calls `rb_define_method()`. The name `Init_array_second` should be the same as a parameter of `create_makefile` method in `extconf.rb`.
4. `$ ruby extconf.rb` and generate Makefile.
5. `$ make` and build `array_second.so`. You will be able to `require` this file. Example: `$ ruby -r ./array_second -e 'p [1, 2].second'` will show `2`.
6. `$ make install` installs .so file into install directory.

You can see `array_second` directory in this repository.

Except `extconf.rb` and install steps, the definitions of Ruby's embedded methods/classes are the same.

To distribute extension libraries, you need to package with files made in step 2 and 3. But gem package is more useful for users.

## Tips: Debugging

https://docs.ruby-lang.org/en/2.5.0/extension_rdoc.html has details.

Check MRI source code which do similar thing you want to add.

When you write a Ruby program, you may use `p(obj)` to check the `obj`. In C, you can use `rb_p(obj)`.

If you can use gdb, break points will help you.
`#include "vm_debug.h"` enables you to use `bp()` macro and it becomes a break point. `make gdb` will stop on this macro, similar to `binding.pry` or `binding.irb`.

gdb allows you to use `p expr` to show the value of `expr` (for example, you can see a value of a variable `foo` with `p foo`). The type `VALUE` is just an integer value in C, so it is difficult to understand what kind of Object it is and what data it represents. Special command `rp` for gdb (defined in `ruby/.gdbinit`) is provided. It shows human readable representations for VALUE-type data.

## Advanced Exercises

Let's solve the following challenges. `grep` will help you to find out similar source code in MRI.

* Implement `Integer#sub(n)` which returns subtract value.
* `Array#second` returns `nil` if there is no second element. This is because `rb_ary_entry()` returns `nil` when the specified index exceeds the size of an array. So let's raise an exception when there is no second element. Use `rb_raise()` function to raise an error.
* `String#palindrome?` is an inefficient implementation. Point out which part is inefficient and how to solve it. Also improve the performance by solving issues.
* `Time#day_before` is a strange name. Think a better method name.
* Let's play a trick on MRI. For example, change the return value of `Integer#+` as subtracted value. This hack will break your ruby build steps so make a new git branch.
* Let's add your favorite methods by your imagination.

These topics are discussed in next chapter, but try to think about them:

* I described that `Integer#add(n)` had a bug.
  * Write a test which fails with this bug.
  * Solve an issue and check passing a test.
* What is a problem on `Time#day_before`? There is the same problem in `Integer#add(n)`.
