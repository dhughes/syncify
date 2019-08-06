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
            values = normalize_associations(value)

            if values.empty?
              memo << Hash[key, {}]
            else
              values.each do |value|
                memo << Hash[key, value]
              end
            end

            memo
          end
        else
          association
        end
      ).flatten
    end
  end
end
