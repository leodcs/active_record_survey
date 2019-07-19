# frozen_string_literal: true

module ActiveRecordSurvey
  # Checkbox question - multiple choices
  class Node::Answer::Checkbox < Node::Answer
    include Answer::Chained::InstanceMethods
    extend Answer::Chained::ClassMethods

    # Checkbox answers are considered answered if they have text entered
    def is_answered_for_instance?(instance)
      if (instance_node = instance_node_for_instance(instance))
        # Answered if has text
        !instance_node.value.to_s.strip.empty?
      else
        false
      end
    end
  end
end
