# frozen_string_literal: true

module ActiveRecordSurvey
  class Node::Answer < Node
    # Answer nodes are valid if their questions are valid!
    # Validate this node against an instance
    def validate_node(instance)
      # Ensure each parent node to this node (the goal here is to hit a question node) is valid
      !survey.node_maps.select do |i|
        i.node == self
      end.collect do |node_map|
        node_map.parent.node.validate_node(instance)
      end.include?(false)
    end

    # Returns the question that preceeds this answer
    def question
      survey.node_maps.select do |i|
        i.node == self
      end.collect do |node_map|
        if node_map.parent&.node
          # Question is not the next parent - recurse!
          if node_map.parent.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer)
            node_map.parent.node.question
          else
            node_map.parent.node
          end
          # Root already
        end
      end.first
    end

    # Returns the question that follows this answer
    def next_question
      survey.node_maps.select do |i|
        i.node == self && !i.marked_for_destruction?
      end.each do |answer_node_map|
        answer_node_map.children.each do |child|
          if !child.node.nil? && !child.marked_for_destruction?
            if child.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Question)
              return child.node
            elsif child.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer)
              return child.node.next_question
            end
          else
            return nil
          end
        end
      end
      nil
    end

    # Removes the node_map from this answer to its next question
    def remove_link
      # not linked to a question - nothing to remove!
      return true if (question = next_question).nil?

      count = 0
      to_remove = []
      survey.node_maps.each do |node_map|
        if node_map.node == question
          if count > 0
            to_remove.concat(node_map.self_and_descendants)
          else
            node_map.parent = nil
            node_map.move_to_root unless node_map.new_record?
          end
          count += 1
        end

        node_map.children = [] if node_map.node == self
      end

      survey.node_maps.each do |node_map|
        if to_remove.include?(node_map)
          node_map.parent = nil
          node_map.mark_for_destruction
        end
      end
    end

    def build_link(to_node)
      if question.nil?
        raise ArgumentError, 'A question is required before calling #build_link'
      end

      super(to_node)
    end

    # Gets index in sibling relationship
    def sibling_index
      node_maps = survey.node_maps

      if node_map = node_maps.select { |i| i.node == self }.first
        parent = node_map.parent

        children = node_maps.select { |i| i.parent && i.parent.node === parent.node }

        children.each_with_index do |nm, i|
          return i if nm == node_map
        end
      end
    end

    def sibling_index=(index)
      current_index = sibling_index

      offset = index - current_index

      (1..offset.abs).each do |_i|
        send((offset > 0 ? 'move_down' : 'move_up'))
      end
    end

    # Moves answer up relative to other answers
    def move_up
      survey.node_maps.select do |i|
        i.node == self
      end.collect do |node_map|
        begin
          node_map.move_left
        rescue StandardError
        end
      end
    end

    # Moves answer down relative to other answers
    def move_down
      survey.node_maps.select do |i|
        i.node == self
      end.collect do |node_map|
        begin
          node_map.move_right
        rescue StandardError
        end
      end
    end

    private

    # By default - answers build off the original question node
    #
    # This allows us to easily override the answer removal behaviour for different answer types
    def remove_answer(question_node)
      # self.survey = question_node.survey

      # The node from answer from the parent question
      survey.node_maps.select do |i|
        !i.marked_for_destruction? &&
          i.node == self && i.parent && i.parent.node === question_node
      end.each do |answer_node_map|
        answer_node_map.send(answer_node_map.new_record? ? :destroy : :mark_for_destruction)
      end
    end

    # By default - answers build off the original question node
    #
    # This allows us to easily override the answer building behaviour for different answer types
    def build_answer(question_node)
      self.survey = question_node.survey

      answer_node_maps = survey.node_maps.select do |i|
        i.node == self && i.parent.nil?
      end.collect do |i|
        i.survey = survey

        i
      end

      question_node_maps = survey.node_maps.select { |i| i.node == question_node && !i.marked_for_destruction? }

      # No node_maps exist yet from this question
      if question_node_maps.length === 0
        # Build our first node-map
        question_node_maps << survey.node_maps.build(node: question_node, survey: survey)
      end

      # Each instance of this question needs the answer hung from it
      question_node_maps.each_with_index do |question_node_map, index|
        new_node_map = answer_node_maps[index] || survey.node_maps.build(node: self, survey: survey)

        question_node_map.children << new_node_map
      end

      true
    end
  end
end
