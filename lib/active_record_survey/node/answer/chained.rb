# frozen_string_literal: true

module ActiveRecordSurvey
  class Answer
    module Chained
      module ClassMethods
        def self.extended(base); end
      end

      module InstanceMethods
        # Gets index relative to other chained answers
        def sibling_index
          if node_map = survey.node_maps.select do |i|
            i.node == self
          end.first
            return node_map.ancestors_until_node_not_ancestor_of(::ActiveRecordSurvey::Node::Answer).length - 1
          end

          0
        end

        # Chain nodes are different
        # They must also see if this answer linked to subsequent answers, and re-build the link
        def remove_answer(question_node)
          self.survey = question_node.survey

          # The node from answer from the parent question
          survey.node_maps.reverse.select do |i|
            i.node == self && !i.marked_for_destruction?
          end.each do |answer_node_map|
            answer_node_map.children.each do |child|
              answer_node_map.parent.children << child
            end

            answer_node_map.send(answer_node_map.new_record? ? :destroy : :mark_for_destruction)
          end
        end

        # Chain nodes are different - they must find the final answer node added and add to it
        # They must also see if the final answer node then points somewhere else - and fix the links on that
        def build_answer(question_node)
          self.survey = question_node.survey

          question_node_maps = survey.node_maps.select do |i|
            i.node == question_node && !i.marked_for_destruction?
          end

          answer_node_maps = survey.node_maps.select do |i|
            i.node == self && i.parent.nil? && !i.marked_for_destruction?
          end.collect do |i|
            i.survey = survey

            i
          end

          # No node_maps exist yet from this question
          if question_node_maps.length === 0
            # Build our first node-map
            question_node_maps << survey.node_maps.build(node: question_node, survey: survey)
          end

          last_answer_in_chain = (question_node.answers.last || question_node)

          # Each instance of this question needs the answer hung from it
          survey.node_maps.select do |i|
            i.node == last_answer_in_chain && !i.marked_for_destruction?
          end.each_with_index do |node_map, index|
            new_node_map = answer_node_maps[index] || survey.node_maps.build(node: self, survey: survey)

            # Hack - should fix this - why does self.survey.node_maps still think... yea somethigns not referenced right
            # curr_children = self.survey.node_maps.select { |j|
            #  node_map.children.include?(j) && j != new_node_map
            # }

            node_map.children << new_node_map

            # curr_children.each { |c|
            #  new_node_map.children << c
            # }
          end

          true
        end

        # Moves answer down relative to other answers by swapping parent and children
        def move_up
          # Ensure each parent node to this node (the goal here is to hit a question node) is valid
          !survey.node_maps.select do |i|
            i.node == self
          end.collect do |node_map|
            # Parent must be an answer - cannot move into the position of a Question!
            next unless !node_map.parent.nil? && node_map.parent.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer)

            # I know this looks overly complicated, but we need to always work with the survey.node_maps - never children/parent of the relation
            parent_node = survey.node_maps.select do |j|
              node_map.parent == j
            end.first

            parent_parent = survey.node_maps.select do |j|
              node_map.parent.parent == j
            end.first

            node_map.parent = parent_parent
            parent_parent.children << node_map

            survey.node_maps.select do |j|
              node_map.children.include?(j)
            end.each do |c|
              c.parent = parent_node
              parent_node.children << c
            end

            parent_node.parent = node_map
            node_map.children << parent_node
          end
        end

        # Moves answer down relative to other answers by swapping parent and children
        def move_down
          # Ensure each parent node to this node (the goal here is to hit a question node) is valid
          !survey.node_maps.select do |i|
            i.node == self
          end.collect do |node_map|
            # Must have children to move lower!
            # And the children are also answers!
            next unless !node_map.children.empty? && !node_map.children.select { |j| j.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer) }.empty?

            # I know this looks overly complicated, but we need to always work with the survey.node_maps - never children/parent of the relation
            parent_node = survey.node_maps.select do |j|
              node_map.parent == j
            end.first

            children = survey.node_maps.select do |j|
              node_map.children.include?(j)
            end

            children_children = survey.node_maps.select do |j|
              children.collect(&:children).flatten.include?(j)
            end

            children.each do |c|
              parent_node.children << c
            end

            children.each do |c|
              c.children << node_map
            end

            children_children.each do |i|
              node_map.children << i
            end
          end
        end
      end
    end
  end
end
