require 'ripper'
require 'pp'
require_relative './ruby_nodes'

module Ruby2AST
  class << self
    def to_ast(script)
      sexp = Ripper.sexp(script)
      sexp2ast sexp
    end

    def seq2ary node
      if SequenceNode === node
        node.nodes
      else
        [node]
      end
    end

    def seq nodes
      if nodes.nil?
        SequenceNode.new []
      else
        SequenceNode.new nodes.map{|node|
                                    sexp2ast node
                                  }
      end
    end

    def sexp2ast node
      type, *data = node

      case type
      when :program
        ProgramNode.new seq(data[0])
      when :void_stmt
        NilNode.new

      when :assign
        lhs = data[0]
        rhs = data[1]

        case lhs[0]
        when :var_field
          lvar_id = lhs[1][1].to_sym
          LvarAssignNode.new lvar_id, sexp2ast(rhs)
        else
          raise "unsupported #{lhs.inspect}"
        end

      when :opassign
        lhs, op, rhs = data
        lvar_name = lhs[1][1].to_sym
        optype = op[1].to_sym
        case optype
        when :'+='
          op = :+
        when :'-='
          op = :-
        else
          raise "unsupported opassign #{optype}"
        end

        # foo += exp
        # =>
        # foo = foo + exp
        args = seq2ary(sexp2ast(rhs))
        LvarAssignNode.new(lvar_name,
                           SendNode.new(:call,
                                        LvarNode.new(lvar_name),
                                        op,
                                        *args))
        #
      when :binary
        receiver = data[0]
        method_id = data[1]
        arg = data[2]

        SendNode.new(:call,
                     sexp2ast(receiver),
                     method_id,
                     sexp2ast(arg))

      when :method_add_arg
        call_info = data[0]
        call_type = call_info[0]

        args_info = data[1]
        args = seq2ary(sexp2ast(args_info))

        case call_type
        when :fcall
          method_id = call_info[1][1].to_sym
          args = seq2ary(sexp2ast(args_info))
          SendNode.new :fcall, SelfNode.new, method_id, *args
        when :call
          receiver = sexp2ast call_info[1]
          method_id = call_info[3][1].to_sym
          SendNode.new :call, receiver, method_id, *args
        end

      when :command
        method_name = data[0][1].to_sym
        args_info = data[1]
        SendNode.new :fcall, SelfNode.new, method_name, *seq2ary(sexp2ast(args_info))

      when :call
        receiver, _, (_, mid, _) = data
        SendNode.new :call, sexp2ast(receiver), mid.to_sym

      when :vcall
        method_name = data[0][1].to_sym
        SendNode.new :fcall, SelfNode.new, method_name

      when :arg_paren
        if data[0]
          sexp2ast data[0]
        else
          SequenceNode.new []
        end

      when :args_add_block
        seq data[0]

      when :var_ref
        vtype, vname, = data[0]
        case vtype
        when :@ident
          lvar = node[1][1].to_sym
          LvarNode.new lvar
        when :@kw
          case vname
          when 'self'
            SelfNode.new
          when 'nil'
            NilNode.new
          when 'true'
            LiteralNode.new true
          when 'false'
            LiteralNode.new false
          else
            raise "unsupported kw #{vname.inspect}"
          end
        else
          raise "unsupported: unkwnon node #{node[1][0]}"
        end

      when :if
        cond, body, (_, else_body) = data
        IfNode.new sexp2ast(cond), seq(body), seq(else_body)

      when :while
        cond, body = data
        WhileNode.new sexp2ast(cond), seq(body)

      when :def
        (_, name, _) = data[0]
        param_info = data[1]
        param_info = param_info[1] if param_info[0]
        (_, parameters, ) = param_info
        if parameters
          parameters = parameters.map{|e| e[1].to_sym}
        else
          parameters = []
        end
        body = data[2][1]

        DefNode.new name.to_sym, parameters || [], ProgramNode.new(seq(body))

      when :paren
        seq data[0]

      when :@int
        LiteralNode.new data.first.to_i
      when :symbol_literal
        LiteralNode.new data.first[1][1].to_sym
      when :string_literal
        StringLiteralNode.new data.first[1][1]
      else
        raise "unsuppoted: #{node.inspect}"
      end
    end
  end
end

if $0 == __FILE__
  script = <<-EOS

   def fib(n)
     if n < 2
       1
     else
       fib(n-2) + fib(n-1)
     end
   end
   fib(10)

__END__
  EOS
  ast = Ruby2AST.to_ast(script)
  pp ast
end
