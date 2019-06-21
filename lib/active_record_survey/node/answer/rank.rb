# frozen_string_literal: true

module ActiveRecordSurvey
  # Rank in relation to parent/children of ActiveRecordSurvey::Node::Answer::Rank
  class Node::Answer::Rank < Node::Answer
    include Answer::Chained::InstanceMethods
    extend Answer::Chained::ClassMethods

    # Accept integer or empty values
    # Must be within range of the number of ranking nodes
    def validate_instance_node(instance_node)
      # super - all validations on this node pass
      super &&
        (instance_node.value.to_s.empty? || !instance_node.value.to_s.match(/^\d+$/).nil?) &&
        (instance_node.value.to_s.empty? || instance_node.value.to_i >= 1) &&
        instance_node.value.to_i <= max_rank
    end

    # Rank answers are considered answered if they have a value of greater than "0"
    def is_answered_for_instance?(instance)
      if instance_node = instance_node_for_instance(instance)
        # Answered if > 0
        instance_node.value.to_i > 0
      end
    end

    protected

    # Calculate the number of Rank nodes above this one
    def num_above
      count = 0
      node_maps.each do |i|
        # Parent is one of us as well - include it and check its parents
        if i.parent.node.class.ancestors.include?(self.class)
          count = count + 1 + i.parent.node.num_above
        end
      end
      count
    end

    # Calculate the number of Rank nodes below this one
    def num_below
      count = 0
      node_maps.each do |node_map|
        node_map.children.each do |child|
          # Child is one of us as well - include it and check its children
          if child.node.class.ancestors.include?(self.class)
            count = count + 1 + child.node.num_below
          end
        end
      end
      count
    end

    # Calculate the maximum rank value that is accepted
    def max_rank
      num_above + num_below + 1
    end
  end
end
