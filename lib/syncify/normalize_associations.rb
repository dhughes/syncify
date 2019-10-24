# frozen_string_literal: true

module Syncify
  class NormalizeAssociations < ActiveInteraction::Base
    object :association, class: Object

    def execute
      normalize_associations(association)
    end

    private

    def normalize_associations(association)
      Array.wrap(
        case association
        when Symbol
          Hash[association, {}]
        when Array
          association.map { |node| normalize_associations(node) }
        when Hash
          association.reduce([]) do |memo, (key, value)|
            if polymorphic_values?(value)
              value = value.reduce({}, :merge) if value.is_a? Array
              memo << Hash[key, value]
            else
              values = normalize_associations(value)

              if values.empty?
                memo << Hash[key, {}]
              else
                values.each do |value|
                  memo << Hash[key, value]
                end
              end
            end

            memo
          end
        else
          association
        end
      ).flatten
    end

    private

    def polymorphic_values?(values)
      if values.is_a? Hash
        values.keys.all? { |key| key.is_a? Class }
      elsif values.is_a? Array
        return false unless values.all? { |value| value.is_a? Hash }
        return polymorphic_values?(values.reduce({}, :merge))
      else
        false
      end
    end
  end
end
