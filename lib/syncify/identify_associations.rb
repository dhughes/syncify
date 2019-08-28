module Syncify
  class IdentifyAssociations < ActiveInteraction::Base
    object :klass, class: Class
    object :referral_chain, class: Array, default: []
    object :cache, class: Hash, default: {}

    def execute
      return nil if associations.empty?
      return associations.first if associations.size == 1

      associations
    end

    private

    def describe_association(association)
      chain_key = [klass.name, association.name]
      cache[chain_key] ||= begin
        puts ">>>> #{chain_key}"
        if association.polymorphic?
          describe_polymorphic_association(association)
        elsif nested_associations?(association)
          describe_nested_associations(association)
        else
          association.name
        end
      end
    end

    def nested_associations?(association)
      associated_class = association.klass
      associated_class.reflect_on_all_associations.any?
    end

    def describe_polymorphic_association(association)
      polymorphic_associated_classes = cache[[klass, association.name]] ||= association.
        active_record.
        select(association.foreign_type).
        distinct.
        pluck(association.foreign_type).
        compact.
        map(&:constantize)

      Syncify::PolymorphicAssociation.new(
        association.name,
        polymorphic_associated_classes.inject({}) do |mappings, foreign_class|
          mappings[foreign_class] = IdentifyAssociations.run!(
            klass: foreign_class,
            referral_chain: [*referral_chain, klass],
            cache: cache
          )
          mappings
        end
      )
    end

    def describe_nested_associations(association)
      associated_associations = IdentifyAssociations.run!(
        klass: association.klass,
        referral_chain: [*referral_chain, klass],
        cache: cache
      )
      return association.name if associated_associations.nil?

      { association.name => associated_associations }
    end

    def exists_in_referral_chain?(association)
      return false if association.polymorphic?
      referral_chain.include? association.klass
    end

    def ignored_association?(association)
      return true if association.class == ActiveRecord::Reflection::ThroughReflection

      false
    end

    def associations
      @associations ||= klass.reflect_on_all_associations.
        reject(&method(:ignored_association?)).
        reject(&method(:exists_in_referral_chain?)).
        map(&method(:describe_association))
    end
  end
end
