# frozen_string_literal: true

module ActiveRecordSurvey
  # Boolean answers can have values true|false
  class Node::Answer::Boolean < Node::Answer
    include Answer::Chained::InstanceMethods
    extend Answer::Chained::ClassMethods

    # Only boolean values 'true' or 'false'
    def validate_instance_node(instance_node)
      # super - all validations on this node pass
      super &&
        ['true', 'false'].include?(instance_node.value.to_s)
    end

    # Boolean answers are considered answered if they have a boolean value
    def is_answered_for_instance?(instance)
      instance_node = instance_node_for_instance(instance)
      return unless instance_node.present?

      ['true', 'false'].include?(instance_node.value.to_s)
    end
  end
end
