module Syncify
  class IdentifyAssociations < ActiveInteraction::Base
    object :klass, class: Class

    def execute
      return nil if associations.empty?
      return associations.first.name if associations.size == 1

      identified_associations = associations.
        reject(&method(:ignored_association?)).
        map(&method(:describe_association))

      return identified_associations.first if identified_associations.size == 1
      identified_associations
    end

    private

    def describe_association(association)
      associated_class = association.class_name.constantize
      if associated_class.reflect_on_all_associations.any?
        { association.name => :counties }
      else
        association.name
      end
    end

    def ignored_association?(association)
      return true if association.class == ActiveRecord::Reflection::ThroughReflection

      false
    end

    def associations
      @associations ||= klass.reflect_on_all_associations
    end
  end
end
