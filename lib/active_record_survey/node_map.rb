# frozen_string_literal: true

module ActiveRecordSurvey
  class NodeMap < ::ActiveRecord::Base
    self.table_name = 'active_record_survey_node_maps'
    belongs_to :node, foreign_key: :active_record_survey_node_id
    belongs_to :survey, class_name: 'ActiveRecordSurvey::Survey', foreign_key: :active_record_survey_id
    acts_as_nested_set scope: [:active_record_survey_id]

    validates_presence_of :survey

    # Recursively creates a copy of this entire node_map
    def recursive_clone
      node_map = survey.node_maps.build(survey: survey, node: node)
      survey.node_maps.select { |i| i.parent == self && !i.marked_for_destruction? }.each do |child_node|
        child_node.survey = survey # required due to voodoo - we want to use the same survey with the same object_id
        node_map.children << child_node.recursive_clone
      end
      node_map
    end

    def as_map(options)
      node_maps = options[:node_maps]

      c = node_maps.nil? ? children : node_maps.select do |i|
        i.parent == self && !i.marked_for_destruction?
      end.sort { |a, b| a.left <=> b.left }

      result = {}
      result.merge!(id: id, node_id: (node.respond_to?(:id) ? node.id : '')) if !options[:no_ids] && !node.nil?
      result.merge!(
        type: (!node.nil? ? node.class.to_s : ''),
        children: c.collect do |i|
                    i.as_map(options)
                  end
      )

      result
    end

    # Whether decendant of a particular node_map
    def is_decendant_of?(node_map)
      # Hit ourselves
      return true if node_map == self

      # Recurse
      return parent.is_decendant_of?(node_map) if parent

      false
    end

    # Gets all the ancestor nodes until one is not an ancestor of klass
    def ancestors_until_node_not_ancestor_of(klass)
      return [] if !parent || !node.class.ancestors.include?(klass)

      [self] + parent.ancestors_until_node_not_ancestor_of(klass)
    end

    # Gets all the child nodes until one is not an ancestor of klass
    def children_until_node_not_ancestor_of(klass)
      return [] unless node.class.ancestors.include?(klass)

      [self] + children.collect do |i|
        i.children_until_node_not_ancestor_of(klass)
      end
    end

    # Check to see whether there is an infinite loop from this node_map
    def has_infinite_loop?(path = [])
      survey.node_maps.select { |i| i.parent == self && !i.marked_for_destruction? }.each do |i|
        # Detect infinite loop
        if path.include?(node) || i.has_infinite_loop?(path.clone.push(node))
          return true
        end
      end
      path.include?(node)
    end

    def mark_self_and_children_for_destruction
      removed = [self]
      mark_for_destruction
      children.each do |i|
        removed.concat(i.mark_self_and_children_for_destruction)
      end
      removed
    end
  end
end
