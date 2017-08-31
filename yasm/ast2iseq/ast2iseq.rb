require 'pp'
require_relative './ruby2ast'
require_relative '../yasm'

# recursive function version
# require_relative './ast2iseq_ans_func'
# See ./ast2iseq_func.rb for skelton

# composite pattern version
# require_relative './ast2iseq_ans_composite'
# See ./ast2iseq_composite.rb for skelton

# visitor pattern version
# require_relative './ast2iseq_ans_visitor'
# See ./ast2iseq_visitor.rb for skelton

# if you want to modify ast2iseq_visitor.rb, remove `#' of the following line.
require_relative 'ast2iseq_visitor'

def ast2iseq ast
  # define your ast2iseq method here
  raise "not implemented yet"
end unless defined?(ast2iseq)

if $0 == __FILE__
  script = <<-EOS
  # fill your script here
  
  1
  
  #######################
  EOS
  ast = Ruby2AST.to_ast(script)
  pp ast
  iseq = ast2iseq(ast)
  puts iseq.disasm
  p iseq.eval
end
