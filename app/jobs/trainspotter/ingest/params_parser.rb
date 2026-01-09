require "prism"

module Trainspotter
  module Ingest
    class ParamsParser
      class ParseError < StandardError; end

      def self.parse(string)
        return {} if string.nil? || string.strip.empty?

        result = Prism.parse(string)
        raise ParseError, result.errors.first.message unless result.success?

        evaluate(result.value.statements.body.first)
      end

      def self.evaluate(node)
        case node
        when Prism::HashNode
          node.elements.to_h { |assoc| [evaluate(assoc.key), evaluate(assoc.value)] }
        when Prism::ArrayNode
          node.elements.map { |el| evaluate(el) }
        when Prism::StringNode
          node.unescaped
        when Prism::IntegerNode, Prism::FloatNode
          node.value
        when Prism::NilNode then nil
        when Prism::TrueNode then true
        when Prism::FalseNode then false
        else
          raise ParseError, "Unsafe node type: #{node.class}"
        end
      end
    end
  end
end
