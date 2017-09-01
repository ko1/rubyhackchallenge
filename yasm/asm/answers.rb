require_relative '../yasm'

def assert iseq, expected
  r = iseq.eval
  if r == expected
    puts "==> OK: #{iseq.label}@#{iseq.path} success."
  else
    puts "!" * 70
    puts "==> NG: #{iseq.label}@#{iseq.path} fails (epxected: #{expected.inspect}, actual: #{r.inspect})."
  end
end

# 1
iseq = YASM.asm label: 'integer:1' do
  putobject 1
  leave
end

assert iseq, 1

# 1_000_000
iseq = YASM.asm label: 'integer:1_000_000' do
  putobject 1_000_000
  leave
end

assert iseq, 1_000_000

# :ok
iseq = YASM.asm label: 'symbol:ok' do
  putobject :ok
  leave
end

assert iseq, :ok

# :ng
iseq = YASM.asm label: 'symbol:ng' do
  putobject :ng
  leave
end

assert iseq, :ng

# "hello"
iseq = YASM.asm label: 'string:hello' do
  putstring "hello"
  leave
end

assert iseq, "hello"

# a = 1; a
iseq = YASM.asm label: 'local_variables' do
  putobject 1
  setlocal :a
  getlocal :a
  leave
end

assert iseq, 1

# self
iseq = YASM.asm label: 'self' do
  putself
  leave
end

assert iseq, self

# nil
iseq = YASM.asm label: 'nil' do
  putnil
  leave
end

assert iseq, nil

# method call: 1 < 10 #=> true ( 1.<(10) #=> true )
iseq = YASM.asm label: '1.<(10)' do
  putobject 1
  putobject 10
  send :<, 1
  leave
end

assert iseq, true

# method call: p(1) #=> 1
iseq = YASM.asm label: 'p(1)' do
  putself
  putobject 1
  send :p, 1, YASM::FCALL
  leave
end

assert iseq, 1

# combination: 1 - 2 * 3 #=> -5
iseq = YASM.asm label: '1 - 2 * 3' do
  putobject 1
  putobject 2
  putobject 3
  send :*, 1
  send :-, 1
  leave
end

assert iseq, -5

# combination: a = 1; b = 2; c = 3; a - b * c #=> -5
iseq = YASM.asm label: 'a = 1; b = 2; c = 3; a - b * c' do
  putobject 1
  setlocal :a
  putobject 2
  setlocal :b
  putobject 3
  setlocal :c

  getlocal :a
  getlocal :b
  getlocal :c
  send :*, 1
  send :-, 1
  leave
end

assert iseq, -5

# combination: a = 10; p(a > 1) #=> true
iseq = YASM.asm label: 'a = 10; p(a > 1)' do
  # a = 10
  putobject 10
  setlocal :a

  putself        # receiver of p()

  # a > 1
  getlocal :a
  putobject 1
  send :>, 1

  # p(result)
  send :p, 1, YASM::FCALL

  leave
end

assert iseq, true

# combination: p(‘foo’.upcase) #=> 'FOO'
iseq = YASM.asm label: 'a = 1; b = 2; c = 3; a + b * c' do
  putself
  putstring 'foo'
  send(:upcase, 0)
  send(:p, 1, YASM::FCALL)
  leave
end

assert iseq, 'FOO'

# if statement
iseq = YASM.asm label: 'if' do
  # a = 10
  putobject 10
  setlocal :a

  # a > 1
  getlocal :a
  putobject 1
  send :>, 1

  # conditional jump
  branchunless :if_else

  # p(:ok)
  putself
  putobject :ok
  send :p, 1, YASM::FCALL

  # jump to end
  jump :if_end

label(:if_else)
  # p(:ng)
  putself
  putobject :ng
  send :p, 1, YASM::FCALL

label(:if_end)
  leave
end

assert iseq, :ok

# if statement without else (1)
iseq = YASM.asm label: 'if_without_else1' do
  # a = 10
  putobject 10
  setlocal :a

  # a > 1
  getlocal :a
  putobject 1
  send :>, 1

  # conditional jump
  branchunless :if_else

  # p(:ok)
  putself
  putobject :ok
  send :p, 1, YASM::FCALL

  # jump to end
  jump :if_end

label(:if_else)
  # nil
  putnil

label(:if_end)
  leave
end

assert iseq, :ok

# if statement without else (2)
iseq = YASM.asm label: 'if_without_else2' do
  # a = 10
  putobject 10
  setlocal :a

  # a > 1
  getlocal :a
  putobject 1
  send :<, 1

  # conditional jump
  branchunless :if_else

  # p(:ok)
  putself
  putobject :ok
  send :p, 1, YASM::FCALL

  # jump to end
  jump :if_end

label(:if_else)
  # nil
  putnil

label(:if_end)
  leave
end

assert iseq, nil

# while
iseq = YASM.asm label: 'while' do
  putobject 0
  setlocal :a

label :when_cond
  # condition
  getlocal :a
  putobject 10
  send :<, 1

  # conditional jump
  branchunless :when_end

  # p a
  putself
  getlocal :a
  send :p, 1, YASM::FCALL
  pop

  # a += 1 #=> a = a.+(1)

  # a.+(1)
  getlocal :a
  putobject 1
  send :+, 1

  # a = ...
  setlocal :a

  jump :when_cond

label :when_end
  getlocal :a
  leave
end

assert iseq, 10

# def foo(); end
iseq = YASM.asm label: 'def:foo()' do
  define_method_macro :foo do
    putnil
    leave
  end

  leave
end

assert iseq, :foo

# def foo(a); a; end; foo(100)
iseq = YASM.asm label: 'def:foo(a)' do
  define_method_macro :foo, parameters: [:a] do
    getlocal :a # as usual local variables
    leave
  end
  pop

  putself
  putobject 100
  send :foo, 1, YASM::FCALL

  leave
end

assert iseq, 100

# def fib
iseq = YASM.asm label: 'fib' do
  define_method_macro :fib, parameters: [:n] do
    # n < 2
    getlocal :n
    putobject 2
    send :<, 1

    branchunless :if_else

    # 1
    putobject 1
    jump :if_end

  label :if_else
    # fib(n-2)
    putself

    # n-2 => n.-(2)
    getlocal :n
    putobject 2
    send :-, 1

    # fib(n-2)
    send :fib, 1, YASM::FCALL

    # fib(n-1)
    putself

    # n-1 => n.-(1)
    getlocal :n
    putobject 1
    send :-, 1

    # fib(n-1)
    send :fib, 1, YASM::FCALL

    # fib() + fib()
    send :+, 1

  label :if_end
    leave
  end
  pop

  # fib(10)
  putself
  putobject 10
  send :fib, 1, YASM::FCALL

  leave
end

assert iseq, 89
