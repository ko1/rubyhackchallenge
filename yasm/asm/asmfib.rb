require_relative '../yasm'

# def fib
iseq = YASM.asm label: 'define-fib' do
  # copy your fib definition here
end

iseq.eval

n = Integer(ARGV.shift || 35)
puts "fib(#{n}) = #{fib(n)}"
