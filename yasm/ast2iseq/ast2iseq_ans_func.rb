$label_no = 0
def gen_label
  :"label_#{$label_no+=1}"
end

# function version
def ast2iseq_rec node, yasm
  case node
  when ProgramNode
    ast2iseq_rec node.seq_node, yasm
    yasm.leave

  when SequenceNode
    nodes = node.nodes.dup
    last_node = nodes.pop
    nodes.each{|n|
      ast2iseq_rec n, yasm
      yasm.pop
    }
    if last_node
      ast2iseq_rec last_node, yasm
    else
      yasm.putnil
    end

  when SendNode
    ast2iseq_rec node.receiver_node, yasm
    node.argument_nodes.each{|arg|
      ast2iseq_rec arg, yasm
    }
    if node.type == :fcall
      yasm.send node.method_id, node.argument_nodes.size, YASM::FCALL
    else
      yasm.send node.method_id, node.argument_nodes.size
    end

  when SelfNode
    yasm.putself

  when LiteralNode
    yasm.putobject node.obj

  when NilNode
    yasm.putnil

  when IfNode
    else_label = gen_label()
    end_label = gen_label()

    ast2iseq_rec node.cond_node, yasm
    yasm.branchunless else_label
    ast2iseq_rec node.body_node, yasm
    yasm.jump end_label
  yasm.label else_label
    ast2iseq_rec node.else_node, yasm
  yasm.label end_label
    # end

  when WhileNode
    begin_label = gen_label()
    end_label = gen_label()

  yasm.label begin_label
    ast2iseq_rec node.cond_node, yasm
    yasm.branchunless end_label
    ast2iseq_rec node.body_node, yasm
    yasm.pop
    yasm.jump begin_label
  yasm.label end_label
    yasm.putnil

  when DefNode
    method_iseq = ast2iseq(node)
    
    yasm.putspecialobject 1
    yasm.putobject node.name
    yasm.putiseq method_iseq.to_a
    yasm.send :"core#define_method", 2

  when LvarAssignNode
    ast2iseq_rec node.value_node, yasm
    yasm.dup
    yasm.setlocal node.lvar_id

  when LvarNode
    yasm.getlocal node.lvar_id

  else
    raise "unsupported: #{node.class}"
  end
end

def ast2iseq node
  if DefNode === node
    yasm = YASM.new label: node.name.to_s, type: :method, parameters: node.parameters
    node = node.body
  else
    yasm = YASM.new
  end

  ast2iseq_rec node, yasm
  yasm.to_iseq
end
