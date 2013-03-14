module Savon
  class BlockInterface

    def initialize(target)
      p "BlockInterface::initialize"
      
      @target = target
    end

    def evaluate(block)
      p "BlockInterface::evaluate"
      if block.arity > 0
        block.call(@target)
      else
        @original = eval("self", block.binding)
        instance_eval(&block)
      end
    end

    private

    def method_missing(method, *args, &block)
      p "BlockInterface::method_missing"
      @target.send(method, *args, &block)
    rescue NoMethodError
      @original.send(method, *args, &block)
    end

  end
end
