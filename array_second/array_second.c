
#include <ruby/ruby.h>

static VALUE
ary_second(VALUE self)
{
  return rb_ary_entry(self, 1);
}

void
Init_array_second(void)
{
    rb_define_method(rb_cArray, "second", ary_second, 0);
}
