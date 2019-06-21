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
        # This instance_node has no valid path to the root node
        unless node.instance_node_path_to_root?(self)
          instance_node.errors[:base] << 'INVALID_PATH'
        end

        parent_nodes = node.survey.node_maps.select { |i| i.node == node }.collect(&:parent)

        # Two instance_nodes on the same node for this instance
        if instance.instance_nodes.reject(&:marked_for_destruction?).reject do |i|
             # And the two arrays
             # Two votes share a parent (this means a question has two answers for this instance)
             (i.node.survey.node_maps.select { |j| i.node == j.node }.collect(&:parent) & parent_nodes).empty?
           end.length > 1
          instance_node.errors[:base] << 'DUPLICATE_PATH'
        end

        # Validate against the associated node
        unless node.validate_instance_node(self)
          instance_node.errors[:base] << 'INVALID'
        end
      end
    end
  end
end
