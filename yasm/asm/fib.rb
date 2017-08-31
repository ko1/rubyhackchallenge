def fib(n)
  if n < 2
    1
  else
    fib(n-2) + fib(n-1)
  end
end

n = Integer(ARGV.shift || 35)
puts "fib(#{n}) = #{fib(n)}"
