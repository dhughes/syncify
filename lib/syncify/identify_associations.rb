module Syncify
  class IdentifyAssociations < ActiveInteraction::Base
    object :klass, class: Class

    def execute
      identified_associations = {}
      @inspections_queue = []

      queue_for_inspection(klass, identified_associations)
      @inspections_queue.each do |association_to_inspect|
        associated_class = association_to_inspect[:associated_class]
        destination = association_to_inspect[:destination]
        queue_for_inspection(associated_class, destination)
      end

      simplify_identified_associations(identified_associations)
    end

    private

    def simplify_identified_associations(associations)
      simplified_associations = associations.each.reduce([]) do |memo, (association, nested_association)|
        simplified_association = if nested_association.empty?
                                   association
                                 else
                                   { association => simplify_identified_associations(nested_association) }
                                 end

        memo << simplified_association

        memo
      end

      return simplified_associations.first if simplified_associations.size == 1
      return nil if simplified_associations.empty?

      simplified_associations
    end

    def queue_for_inspection(klass, associations)
      klass.reflect_on_all_associations.
        reject(&method(:ignored_association?)).
        each do |association|

        # look for a hash in the inspection queue where the associated_class is the klass
        next if @inspections_queue.find { |assoc| assoc[:associated_class] == klass && assoc[:referred_to_by].include?(association.klass) }

        print '.'

        destination = associations[association.name] = {}

        association_to_inspect = @inspections_queue.find { |assoc| assoc[:associated_class] == association.klass }
        association_to_inspect ||= { associated_class: association.klass, destination: destination }

        association_to_inspect[:referred_to_by] ||= []
        association_to_inspect[:referred_to_by] << klass

        @inspections_queue << association_to_inspect unless @inspections_queue.include?(association_to_inspect)
      end
    end

    def ignored_association?(association)
      return true if association.class == ActiveRecord::Reflection::ThroughReflection

      false
    end
  end
end
