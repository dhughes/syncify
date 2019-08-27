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
      return describe_polymorphic_association(association) if association.polymorphic?
      return describe_nested_associations(association) if nested_associations?(association)

      association.name
    end

    def nested_associations?(association)
      associated_class = association.class_name.constantize
      associated_class.reflect_on_all_associations.any?
    end

    def describe_polymorphic_association(association)
      polymorphic_associated_classes = association.
        active_record.
        select(association.foreign_type).
        distinct.
        pluck(association.foreign_type).
        map(&:constantize)

      Syncify::PolymorphicAssociation.new(
        association.name,
        polymorphic_associated_classes.inject({}) do |mappings, foreign_class|
          mappings[foreign_class] = IdentifyAssociations.run!(
            klass: foreign_class,
            referrer_class: klass
          )
          mappings
        end
      )
    end

    def describe_nested_associations(association)
      associated_associations = IdentifyAssociations.run!(
        klass: association.class_name.constantize,
        referrer_class: klass
      )
      return association.name if associated_associations.nil?

      { association.name => associated_associations }
    end

    def associated_to_referrer_class?(association)
      return false if association.polymorphic?
      association.class_name.constantize == referrer_class
    end

    def ignored_association?(association)
      return true if association.class == ActiveRecord::Reflection::ThroughReflection

      false
    end

    def associations
      @associations ||= klass.reflect_on_all_associations.
        reject(&method(:ignored_association?)).
        reject(&method(:associated_to_referrer_class?)).
        map(&method(:describe_association))
    end
  end
end
