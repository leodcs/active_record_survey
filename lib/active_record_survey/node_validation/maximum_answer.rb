# frozen_string_literal: true

module ActiveRecordSurvey
  # Ensure the a maximum number of answers are made
  class NodeValidation::MaximumAnswer < NodeValidation
    # Validate the instance_node to ensure a maximum number of answers are made
    def validate_instance_node(instance_node, question_node = nil)
      # Only makes sense for questions to have maximum answers
      unless question_node.class.ancestors.include?(::ActiveRecordSurvey::Node::Question)
        return false
      end

      instance = instance_node.instance

      # Go through the node_map of this node
      total_answered = question_node.node_maps.collect do |question_node_map|
        # Get all children until a childs node isn't an answer
        question_node_map.children.collect do |i|
          i.children_until_node_not_ancestor_of(::ActiveRecordSurvey::Node::Answer)
        end.flatten.collect do |i|
          i.node.is_answered_for_instance?(instance)
        end
      end.flatten.select { |i| i }.count

      is_valid = (total_answered <= value.to_i)

      instance_node.errors[:base] << { nodes: { question_node.id => ['MAXIMUM_ANSWER'] } } unless is_valid

      is_valid
    end
  end
end
