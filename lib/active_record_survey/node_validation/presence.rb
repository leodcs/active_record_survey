# frozen_string_literal: true

module ActiveRecordSurvey
  # Ensure the instance_node has a present value.
  class NodeValidation::Presence < NodeValidation
    def validate_instance_node(instance_node, answer_node = nil)
      return true if instance_node.value.to_s.present?

      instance_node.errors[:base] <<
        { nodes: { answer_node.id => ['MUST_BE_PRESENT'] } }
      false
    end
  end
end
