require_relative './ruby2ast'
require_relative './ast2iseq'

# [[program, expected_result], ...]
[['1',         1],
 ['1_000_000', 1_000_000],
 [':ok',       :ok],
 [':ng',       :ng],
 ['"hello"',   "hello"],
 ['a=1; a',    1],
 ['self',      self],
 ['nil',       nil],
 ['p(1)',      1],
 ['1 < 10',    true],
 ['1 - 2 * 3', -5],
 ['a = 1; b = 2; c = 3; a - b * c', -5],
 ['a = 10; p(a > 1)', true],
 ['p("foo".upcase)', 'FOO'],
 [%q{
   a = 10
   if a > 1
     p :ok
   else
     p :ng
   end
  }, :ok],
 [%q{
   a = 10
   if a > 1
     p :ok
   end
  }, :ok],
 [%q{
   a = 10
   if a < 1
     p :ok
   end
  }, nil],
 [%q{
   a = 0
   while(a < 10)
     p a
     a += 1 #=> a = a.+(1)
   end
   a #=> 10
  }, 10],
 [%q{
   def foo()
   end
  }, :foo],
 [%q{
   def foo(a)
     a
   end
   foo(100)
  }, 100],
 [%q{
   def fib(n)
     if n < 2
       1
     else
       fib(n-2) + fib(n-1)
     end
   end
   fib(10)
  }, 89],
].each do |script, expected|
  begin
    # puts script; STDOUT.flush

    ast = Ruby2AST.to_ast(script)
    iseq = ast2iseq(ast)
    actual = iseq.eval

    if actual == expected
      puts "==> OK"
    else
      puts "==> NG: the following code doesn't show correct answer (expected: #{expected.inspect}, actual: #{actual.inspect})"
      puts script
    end
  rescue Exception => e
    puts "==> Error: #{e.message} (#{e.class})"
    puts "script: #{script.inspect}"
    puts e.backtrace.join("\n")
    exit 1
  end
end
