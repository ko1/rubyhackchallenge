# Ruby nodes

class Node
  def pretty_print q
    name = self.class.name.to_s.sub(/\A.+::/, '')
    q.breakable
    q.group 2, "#<#{name}" do
      instance_variables.each{|e|
        q.breakable
        q.text "#{e} => "
        q.pp instance_variable_get(e)
      }
    end
    q.text ">"
    # exit
  end

  def accept visitor
    visitor.visit(self)
  end
end

class ProgramNode < Node
  attr_reader :seq_node
  def initialize seq_node
    @seq_node = seq_node
  end
end

class SequenceNode < Node
  attr_reader :nodes
  def initialize nodes
    @nodes = nodes # Array
  end
end

class NilNode < Node
end

class SelfNode < Node
end

class LiteralNode < Node
  attr_reader :obj

  def initialize obj
    @obj = obj
  end
end

class StringLiteralNode < LiteralNode
end

class LvarAssignNode < Node
  attr_reader :lvar_id, :value_node
  def initialize lvar_id, value_node
    @lvar_id = lvar_id
    @value_node = value_node
  end
end

class LvarNode < Node
  attr_reader :lvar_id
  def initialize lvar_id
    @lvar_id = lvar_id
  end
end

class SendNode < Node
  attr_reader :receiver_node, :method_id, :argument_nodes, :type
  def initialize type, receiver_node, method_id, *argument_nodes
    @type = type # :call or :fcall
    @receiver_node = receiver_node
    @method_id = method_id
    @argument_nodes = argument_nodes # Array
  end
end

class IfNode < Node
  attr_reader :cond_node, :body_node, :else_node
  def initialize cond_node, body_node, else_node
    @cond_node = cond_node
    @body_node = body_node
    @else_node = else_node
  end
end

class WhileNode < Node
  attr_reader :cond_node, :body_node
  def initialize cond_node, body_node
    @cond_node = cond_node
    @body_node = body_node
  end
end

class DefNode
  attr_reader :name, :parameters, :body
  def initialize name, parameters, body
    @name = name
    @parameters = parameters
    @body = body
  end
end
