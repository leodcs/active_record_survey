# frozen_string_literal: true

module ActiveRecordSurvey
  # File answers are... file answers
  class Node::Answer::File < Node::Answer
    include Answer::Chained::InstanceMethods
    extend Answer::Chained::ClassMethods

    # File answers are considered answered if they have file entered
    def is_answered_for_instance?(instance)
      if (instance_node = instance_node_for_instance(instance))
        # Answered if has a file
        !instance_node.value.to_s.strip.empty?
      else
        false
      end
    end
  end
end
