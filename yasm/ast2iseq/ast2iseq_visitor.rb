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
    visit(node.seq_node)
    @yasm.leave
  end

  def process_sequence node
    node.nodes.each{|n|
      visit(n)
    }
  end

  def process_send node
    raise "not implemented yet: #{node}"
  end

  def process_self node
    raise "not implemented yet: #{node}"
  end

  def process_literal node
    obj = node.obj
    @yasm.putobject obj
  end

  def process_stringliteral node
    raise "not implemented yet: #{node}"
  end

  def process_nil node
    raise "not implemented yet: #{node}"
  end

  def process_if node
    raise "not implemented yet: #{node}"
  end

  def process_while node
    raise "not implemented yet: #{node}"
  end

  def process_def node
    method_iseq = ast2iseq(node)

    # call "core#define_method" explicitly
    # see define_method_macro at yasm.rb.
    raise "not implemented yet: #{node}"
  end

  def process_lvarassign node
    raise "not implemented yet: #{node}"
  end

  def process_lvar node
    raise "not implemented yet: #{node}"
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
