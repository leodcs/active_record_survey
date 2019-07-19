# frozen_string_literal: true

module ActiveRecordSurvey
  class InstanceNode < ::ActiveRecord::Base
    self.table_name = 'active_record_survey_instance_nodes'

    belongs_to :instance,
               class_name: 'ActiveRecordSurvey::Instance',
               foreign_key: :active_record_survey_instance_id
    belongs_to :node,
               class_name: 'ActiveRecordSurvey::Node',
               foreign_key: :active_record_survey_node_id

    validates_presence_of :instance

    validate do |instance_node|
      # No node to begin with!
      if node.nil?
        instance_node.errors[:base] << 'INVALID_NODE'
      else
        # Validate against the associated node
        unless node.validate_instance_node(self)
          instance_node.errors[:base] << 'INVALID'
        end
      end
    end
  end
end
