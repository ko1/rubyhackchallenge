require 'fiddle'
require 'pp'
require 'rbconfig'

RubyVM::InstructionSequence.compile_option = false

class RubyVM
  class InstructionSequence
    handle = Fiddle::Handle.new
    address = handle['rb_iseq_load']
    func = Fiddle::Function.new(address, [Fiddle::TYPE_VOIDP] * 3, Fiddle::TYPE_VOIDP)

    define_singleton_method(:load) do |data, parent = nil, opt = nil|
      func.call(Fiddle.dlwrap(data), parent, opt).to_value
    end
  end
end unless RubyVM::InstructionSequence.respond_to? :load

class YASM

  attr_reader :seq

  def initialize type: :top,
                 label: nil,
                 path: nil,
                 first_line: 1,
                 parameters: []
    @type = type
    @parameters = parameters
    @local_variables = {}
    @parameters.each{|param|
      register_lvar param
    }
    @seq = [first_line]
    @label = label || "<compiled/yasm(#{type})>"
    @path = path || "<compiled/yasm>"
  end

  def label label
    @seq << label
  end

  def newline line
    @seq << line
  end

  def add insn, *operands
    @seq << [insn, *operands]
  end

  RubyVM::INSTRUCTION_NAMES.each{|insn|
    eval <<-EOS
    def #{insn}(*ops)
      add(:#{insn}, *ops)
    end
    EOS
  }
  undef send
  undef getlocal
  undef setlocal

  FCALL = 4
  VCALL = 8
  def send mid, argc, flag = 0
    add :send, {mid: mid, orig_argc: argc, flag: flag}, false, nil
  end

  def getlocal lid, level = 0
    register_lvar lid
    add :getlocal, lid, level
  end

  def setlocal lid, level = 0
    register_lvar lid
    add :setlocal, lid, level
  end

  def define_method_macro mid, *args, **kw, &b
    iseq = YASM.asm(*args, label: mid.to_s, type: :method, **kw, &b)

    self.putspecialobject 1
    self.putobject mid.to_sym
    self.putiseq iseq.to_a
    send :"core#define_method", 2
  end

  def asm &b
    self.instance_eval(&b)
    self
  end

  private

  def register_lvar lvar
    @local_variables[lvar] ||= @local_variables.size
  end

  def each_insn
    @seq.each.with_index do |item, idx|
      case item
      when Integer
        # ok (lineno)
      when Symbol
        # ok (label)
      when Array
        r = yield(*item)
        @seq[idx] = r if r
      else
        raise "unsupported seq entry: #{item.inspect}"
      end
    end
  end

  def seq2bytecode seq
    each_insn do |insn, *operands|
      case insn
      when :getlocal, :setlocal
        l, * = operands
        operands[0] = 2 + (@local_variables.size - @local_variables[l])
        [insn, *operands] # replace
      else
        nil
      end
    end

    # pp @seq
  end

  SIG, MAJOR, MINOR, FORMAT_TYPE, = RubyVM::InstructionSequence.compile('').to_a

  public

  def to_iseq
    bytecode = seq2bytecode(@seq)
    params = {}
    params[:lead_num] = @parameters.size unless @parameters.empty?
    ary = [SIG, MAJOR, MINOR, FORMAT_TYPE,
           { arg_size: @parameters.size,
             local_size: @local_variables.size,
             stack_max: @seq.size,
           },
           @label,
           @path,
           nil,
           1,
           @type,
           @local_variables.keys,
           params,
           [], # catch_table
           bytecode,
         ]
    RubyVM::InstructionSequence.load(ary)
  end

  def disasm
    to_iseq.disasm
  end

  def eval
    to_iseq.eval
  end

  def self.asm(**kw, &b)
    kw[:path] ||= caller(1).first
    self.new(**kw).asm(&b).to_iseq
  end

  def self.compile_and_disasm(script)
    puts RubyVM::InstructionSequence.compile(script).disasm
  end

  def self.compile_and_to_ary(script)
    pp RubyVM::InstructionSequence.compile(script).to_a
  end
end

if __FILE__ == $0

#### Your assmelber

iseq = YASM.asm do
  ####################
  # fill your asm here
  putobject :foo
  leave
end

# show your asm
puts iseq.disasm
# pp iseq.to_a
puts "== result " + "="*62
p iseq.eval

end
