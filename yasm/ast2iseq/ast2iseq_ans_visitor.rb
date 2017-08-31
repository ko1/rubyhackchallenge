$label_no = 0
def gen_label
  :"label_#{$label_no+=1}"
end

class NodeVisitor
  def initialize yasm
    @yasm = yasm
  end

  def to_iseq
    @yasm.to_iseq
  end

  def visit node
    node_type = node.class.name.to_s.sub(/Node/, '').downcase
    send("process_#{node_type}", node)
  end

  def process_program node
    visit node.seq_node
    @yasm.leave
  end

  def process_sequence node
    nodes = node.nodes.dup
    last_node = nodes.pop
    nodes.each{|n|
      visit n
      @yasm.pop
    }

    if last_node
      visit last_node
    else
      @yasm.putnil
    end
  end

  def process_send node
    visit node.receiver_node
    node.argument_nodes.each{|arg|
      visit arg
    }
    if node.type == :fcall
      @yasm.send node.method_id, node.argument_nodes.size, YASM::FCALL
    else
      @yasm.send node.method_id, node.argument_nodes.size
    end
  end

  def process_self node
    @yasm.putself
  end

  def process_literal node
    @yasm.putobject node.obj
  end

  def process_stringliteral node
    @yasm.putstring node.obj
  end

  def process_nil node
    @yasm.putnil
  end

  def process_if node
    else_label = gen_label()
    end_label = gen_label()

    visit node.cond_node
    @yasm.branchunless else_label
    visit node.body_node
    @yasm.jump end_label
  @yasm.label else_label
    visit node.else_node
  @yasm.label end_label
    # end
  end

  def process_while node
    begin_label = gen_label()
    end_label = gen_label()

  @yasm.label begin_label
    visit node.cond_node
    @yasm.branchunless end_label
    visit node.body_node
    @yasm.pop
    @yasm.jump begin_label
  @yasm.label end_label
    @yasm.putnil
  end

  def process_def node
    method_iseq = ast2iseq(node)
    @yasm.putspecialobject 1
    @yasm.putobject node.name
    @yasm.putiseq method_iseq.to_a
    @yasm.send :"core#define_method", 2
  end

  def process_lvarassign node
    visit node.value_node
    @yasm.dup
    @yasm.setlocal node.lvar_id
  end

  def process_lvar node
    @yasm.getlocal node.lvar_id
  end
end

def ast2iseq node
  if DefNode === node
    yasm = YASM.new label: node.name.to_s, type: :method, parameters: node.parameters
    node = node.body
  else
    yasm = YASM.new
  end
  visitor = NodeVisitor.new(yasm)
  visitor.visit node
  visitor.to_iseq
end
