def fib n
  a, b = 1, 1
  n.times{
    a, b = b, a+b
  }
  a
end

n = Integer(ARGV.shift || 35)
puts "fib(#{n}) = #{fib(n)}"
