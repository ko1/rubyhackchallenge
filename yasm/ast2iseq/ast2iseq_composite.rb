$label_no = 0
def gen_label
  :"label_#{$label_no+=1}"
end

class ProgramNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class SequenceNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class NilNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class SelfNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class LiteralNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class StringLiteralNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class LvarAssignNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class LvarNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class SendNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class IfNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class WhileNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

class DefNode
  def process yasm
    raise "not supported (#{self.class})"
  end
end

def ast2iseq node
  if DefNode === node
    yasm = YASM.new label: node.name.to_s, type: :method, parameters: node.parameters
    node = node.body
  else
    yasm = YASM.new
  end

  node.process yasm
  yasm.to_iseq
end
