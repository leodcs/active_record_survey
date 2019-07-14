# frozen_string_literal: true

module ActiveRecordSurvey
  class Node::Question < Node
    scope :not_hidden, -> do
      left_outer_joins(:node_maps)
        .where('active_record_survey_node_maps.id IS NULL
               OR active_record_survey_node_maps.depth = 0')
    end

    def hidden?
      node_maps.present? && node_maps.none? { |map| map.depth.zero? }
    end

    def required?
      node_validations.any? do |validation|
        validation.type == 'ActiveRecordSurvey::NodeValidation::Presence'
      end
    end

    # Stop validating at the Question node
    def validate_parent_instance_node(instance_node, _child_node)
      !node_validations.collect do |node_validation|
        node_validation.validate_instance_node(instance_node, self)
      end.include?(false)
    end

    # Updates the answers of this question to a different type
    def update_question_type(klass)
      unless next_questions.empty?
        raise 'No questions can follow when changing the question type'
      end

      nm = survey.node_maps

      answers = self.answers.collect do |answer|
        nm.select do |i|
          i.node == answer
        end
      end.flatten.uniq.collect do |answer_node_map|
        node = answer_node_map.node
        answer_node_map.send(answer_node_map.new_record? ? :destroy : :mark_for_destruction)
        node
      end.collect do |answer|
        answer.type = klass.to_s
        answer = answer.becomes(klass)
        answer.save unless answer.new_record?

        answer
      end.uniq

      answers.each do |answer|
        answer.survey = survey

        build_answer(answer)
      end
    end

    # Removes an answer
    def remove_answer(answer_node)
      # A survey must either be passed or already present in self.node_maps
      if survey.nil?
        raise ArgumentError, 'A survey must be passed if ActiveRecordSurvey::Node::Question is not yet added to a survey'
      end

      unless answer_node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer)
        raise ArgumentError, '::ActiveRecordSurvey::Node::Answer not passed'
      end

      # Cannot mix answer types
      # Check if not match existing - throw error
      unless answers.include?(answer_node)
        raise ArgumentError, 'Answer not linked to question'
      end

      answer_node.send(:remove_answer, self)
    end

    # Build an answer off this node
    def build_answer(answer_node)
      # A survey must either be passed or already present in self.node_maps
      if survey.nil?
        raise ArgumentError, 'A survey must be passed if ActiveRecordSurvey::Node::Question is not yet added to a survey'
      end

      # Cannot mix answer types
      # Check if not match existing - throw error
      unless answers.reject do |answer|
        answer.class == answer_node.class
      end.empty?
        raise ArgumentError, 'Cannot mix answer types on question'
      end

      # Answers actually define how they're built off the parent node
      if answer_node.send(:build_answer, self)

        # If any questions existed directly following this question, insert after this answer
        survey.node_maps.select do |i|
          i.node == answer_node && !i.marked_for_destruction?
        end.each do |answer_node_map|
          survey.node_maps.select do |j|
            # Same parent
            # Is a question
            !j.marked_for_destruction? &&
              j.parent == answer_node_map.parent && j.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Question)
          end.each do |j|
            answer_node_map.survey = survey
            j.survey = survey

            answer_node_map.children << j
          end
        end

        answers.last
      end
    end

    # Removes the node_map link from this question all of its next questions
    def remove_link
      return true if (questions = next_questions).length === 0

      # Remove the link to any direct questions
      survey.node_maps.select do |i|
        i.node == self
      end.each do |node_map|
        survey.node_maps.select do |j|
          node_map.children.include?(j)
        end.each do |child|
          if child.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Question)
            child.parent = nil
            child.send(child.new_record? ? :destroy : :mark_for_destruction)
          end
        end
      end

      # remove link any answeres that have questions
      answers.collect(&:remove_link)
    end

    # Returns the questions that follows this question (either directly or via its answers)
    def next_questions
      list = []

      if question_node_map = survey.node_maps.select do |i|
        i.node == self && !i.marked_for_destruction?
      end.first
        question_node_map.children.each do |child|
          if !child.node.nil? && !child.marked_for_destruction?
            if child.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Question)
              list << child.node
            elsif child.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer)
              list << child.node.next_question
            end
          end
        end
      end

      list.compact.uniq
    end

    private

    # Before a node is destroyed, will re-build the node_map links from parent to child if they exist
    # If a question is being destroyed and it has answers - don't link its answers - only parent questions that follow it
    def before_destroy_rebuild_node_map
      survey.node_maps.select do |i|
        i.node == self
      end.each do |node_map|
        # Remap all of this nodes children to the parent
        node_map.children.each do |child|
          unless child.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer)
            node_map.parent.children << child
          end
        end
      end

      true
    end
  end
end
