# frozen_string_literal: true

module ActiveRecordSurvey
  # Ensure the instance_node has a value less than the maximum
  class NodeValidation::MaximumValue < NodeValidation
    # Validate the instance_node value is less than the maximum
    def validate_instance_node(instance_node, answer_node = nil)
      is_valid = (!instance_node.value.to_s.empty? && instance_node.value.to_f <= value.to_f)

      instance_node.errors[:base] << { nodes: { answer_node.id => ['MAXIMUM_VALUE'] } } unless is_valid

      is_valid
    end
  end
end
