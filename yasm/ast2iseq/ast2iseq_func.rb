$label_no = 0
def gen_label
  :"label_#{$label_no+=1}"
end

# function version
def ast2iseq_rec node, yasm
  case node
  when ProgramNode
    raise "not supported (#{node.class})"

  when SequenceNode
    raise "not supported (#{node.class})"

  when SendNode
    raise "not supported (#{node.class})"

  when SelfNode
    raise "not supported (#{node.class})"

  when LiteralNode
    raise "not supported (#{node.class})"

  when NilNode
    raise "not supported (#{node.class})"

  when IfNode
    raise "not supported (#{node.class})"

  when WhileNode
    raise "not supported (#{node.class})"

  when DefNode
    method_iseq = ast2iseq(node)
    # call "core#define_method" explicitly
    # see define_method_macro at yasm.rb.
    raise "not supported (#{node.class})"

  when LvarAssignNode
    raise "not supported (#{node.class})"

  when LvarNode
    raise "not supported (#{node.class})"

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
