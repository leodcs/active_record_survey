# frozen_string_literal: true

module ActiveRecordSurvey
  class Survey < ::ActiveRecord::Base
    self.table_name = 'active_record_surveys'
    has_many :node_maps, -> { includes(:node, parent: [:node]) }, class_name: 'ActiveRecordSurvey::NodeMap', foreign_key: :active_record_survey_id, autosave: true
    has_many :nodes, class_name: 'ActiveRecordSurvey::Node', foreign_key: :active_record_survey_id
    has_many :questions, class_name: 'ActiveRecordSurvey::Node::Question', foreign_key: :active_record_survey_id

    # Builds first question
    def build_first_question(question_node)
      unless question_node.class.ancestors.include?(::ActiveRecordSurvey::Node::Question)
        raise ArgumentError, 'must inherit from ::ActiveRecordSurvey::Node::Question'
      end

      question_node_maps = node_maps.select { |i| i.node == question_node && !i.marked_for_destruction? }

      # No node_maps exist yet from this question
      if question_node_maps.length === 0
        # Build our first node-map
        question_node_maps << node_maps.build(node: question_node, survey: self)
      end
    end

    # All the connective edges
    def edges
      node_maps.reject(&:marked_for_destruction?).select do |i|
        i.node && i.parent
      end.collect do |i|
        {
          source: i.parent.node.id,
          target: i.node.id
        }
      end.uniq
    end

    def as_map(*args)
      options = args.extract_options!
      options[:node_maps] ||= node_maps

      node_maps.select { |i| !i.parent && !i.marked_for_destruction? }.collect do |i|
        i.as_map(options)
      end
    end
  end
end
