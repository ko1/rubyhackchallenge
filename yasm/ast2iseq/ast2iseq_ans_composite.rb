$label_no = 0
def gen_label
  :"label_#{$label_no+=1}"
end

class ProgramNode
  def process yasm
    seq_node.process yasm
    yasm.leave
  end
end

class SequenceNode
  def process yasm
    nodes = self.nodes.dup
    last_node = nodes.pop
    nodes.each{|n|
      n.process yasm
      yasm.pop
    }
    if last_node
      last_node.process yasm
    else
      yasm.putnil
    end
  end
end

class NilNode
  def process yasm
    yasm.putnil
  end
end

class SelfNode
  def process yasm
    yasm.putself
  end
end

class LiteralNode
  def process yasm
    yasm.putobject self.obj
  end
end

class StringLiteralNode
  def process yasm
    yasm.putstring self.obj
  end
end

class LvarAssignNode
  def process yasm
    value_node.process yasm
    yasm.dup
    yasm.setlocal self.lvar_id
  end
end

class LvarNode
  def process yasm
    yasm.getlocal self.lvar_id
  end
end

class SendNode
  def process yasm
    self.receiver_node.process yasm
    self.argument_nodes.each{|e| e.process yasm}
    if self.type == :fcall
      yasm.send self.method_id, self.argument_nodes.size, YASM::FCALL
    else
      yasm.send self.method_id, self.argument_nodes.size
    end
  end
end

class IfNode
  def process yasm
    else_label = gen_label
    end_label = gen_label

    self.cond_node.process yasm
    yasm.branchunless else_label
    self.body_node.process yasm
    yasm.jump end_label
  yasm.label else_label
    self.else_node.process yasm
  yasm.label end_label
  end
end

class WhileNode
  def process yasm
    begin_label = gen_label
    end_label = gen_label

  yasm.label begin_label
    self.cond_node.process yasm
    yasm.branchunless end_label
    self.body_node.process yasm
    yasm.pop
    yasm.jump begin_label
  yasm.label end_label
    yasm.putnil
  end
end

class DefNode
  def process yasm
    method_iseq = ast2iseq(self)
    yasm.putspecialobject 1
    yasm.putobject self.name
    yasm.putiseq method_iseq.to_a
    yasm.send :"core#define_method", 2
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
