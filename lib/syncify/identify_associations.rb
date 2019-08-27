module Syncify
  class IdentifyAssociations < ActiveInteraction::Base
    object :klass, class: Class
    object :referrer_class, class: Class, default: nil

    def execute
      return nil if associations.empty?
      return associations.first if associations.size == 1

      associations
    end

    private

    def describe_association(association)
      associated_class = association.class_name.constantize

      if associated_class.reflect_on_all_associations.any?
        associated_associations = IdentifyAssociations.run!(
          klass: associated_class,
          referrer_class: klass
        )
        return association.name if associated_associations.nil?

        { association.name => associated_associations }
      else
        association.name
      end
    end

    def association_back_to_referrer_class?(association)
      association.class_name.constantize == referrer_class
    end

    def ignored_association?(association)
      return true if association.class == ActiveRecord::Reflection::ThroughReflection

      false
    end

    def associations
      @associations ||= klass.reflect_on_all_associations.
        reject(&method(:ignored_association?)).
        reject(&method(:association_back_to_referrer_class?)).
        map(&method(:describe_association))
    end
  end
end
