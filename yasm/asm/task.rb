require_relative '../yasm'

def assert iseq, expected
  r = iseq.eval
  if r == expected
    puts "==> OK: #{iseq.label}@#{iseq.path} success."
  else
    puts "!" * 70
    puts "==> NG: #{iseq.label}@#{iseq.path} fails (epxected: #{expected.inspect}, actual: #{r.inspect})."
    exit 1
  end
end

# 1
iseq = YASM.asm label: 'A-1: integer:1' do
  putobject :replace_me
  leave
end

assert iseq, 1

# 1_000_000
iseq = YASM.asm label: 'A-1: integer:1_000_000' do
  putobject :replace_me
  leave
end

assert iseq, 1_000_000

# :ok
iseq = YASM.asm label: "A-1': symbol:ok" do
  putobject :replace_me
  leave
end

assert iseq, :ok

# :ng
iseq = YASM.asm label: "A-1': symbol:ng" do
  putobject :replace_me
  leave
end

assert iseq, :ng

# "hello"
iseq = YASM.asm label: "A-1'': string:hello" do
  putobject :replace_me
  leave
end

assert iseq, "hello"

# a = 1; a
iseq = YASM.asm label: 'A-2: local_variables' do
  putobject :replace_me
  leave
end

assert iseq, 1

# self
iseq = YASM.asm label: 'A-3: self' do
  putobject :replace_me
  leave
end

assert iseq, self

# nil
iseq = YASM.asm label: 'A-3: nil' do
  putobject :replace_me
  leave
end

assert iseq, nil

# method call: 1 < 10 #=> true ( 1.<(10) #=> true )
iseq = YASM.asm label: 'A-4: 1.<(10)' do
  putobject :replace_me
  leave
end

assert iseq, true

# method call: p(1) #=> 1
iseq = YASM.asm label: 'A-4: p(1)' do
  putobject :replace_me
  leave
end

assert iseq, 1

# combination: 1 - 2 * 3 #=> -5
iseq = YASM.asm label: "A-4': 1 - 2 * 3" do
  putobject :replace_me
  leave
end

assert iseq, -5

# combination: a = 10; p(a > 1) #=> true
iseq = YASM.asm label: "A-4': a = 10; p(a > 1)" do
  putobject :replace_me
  leave
end

assert iseq, true

# combination: a = 1; b = 2; c = 3; a - b * c #=> -5
iseq = YASM.asm label: "A-4': a = 1; b = 2; c = 3; a - b * c" do
  putobject :replace_me
  leave
end

assert iseq, -5

# combination: p('foo'.upcase) #=> 'FOO'
iseq = YASM.asm label: "A-4': p('foo'.upcase)" do
  putobject :replace_me
  leave
end

assert iseq, 'FOO'

# if statement
iseq = YASM.asm label: 'A-5: if' do
  putobject :replace_me
  leave
end

assert iseq, :ok

# if statement without else (1)
iseq = YASM.asm label: "A-5': if_without_else1" do
  putobject :replace_me
  leave
end

assert iseq, :ok

# if statement without else (2)
iseq = YASM.asm label: "A-5': if_without_else2" do
  putobject :replace_me
  leave
end

assert iseq, nil

# while
iseq = YASM.asm label: "A-6: while" do
  putobject :replace_me
  leave
end

assert iseq, 10

# def foo(); end
iseq = YASM.asm label: "A-7: def:foo()" do
  putobject :replace_me
  leave
end

assert iseq, :foo

# def foo(a); a; end; foo(100)
iseq = YASM.asm label: 'A-7: def:foo(a)' do
  putobject :replace_me
  leave
end

assert iseq, 100

# def fib
iseq = YASM.asm label: 'A-7: fib' do
  putobject :replace_me
  leave
end

assert iseq, 89
