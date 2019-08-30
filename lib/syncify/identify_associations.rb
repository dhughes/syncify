module Syncify
  class IdentifyAssociations < ActiveInteraction::Base
    object :klass, class: Class

    attr_accessor :association_registry, :built_associations

    def execute
      @association_registry = Set[]
      @built_associations = {}

      identify_associations

      build_associations
    end

    def build_associations
      simplify_associations(traverse_associations)
    end

    private

    def simplify_associations(associations)
      simplified_associations = associations.each.reduce([]) do |memo, (association, nested_association)|
        simplified_association = if nested_association.empty?
                                   association
                                 else
                                   { association => simplify_associations(nested_association) }
                                 end

        memo << simplified_association
        memo
      end
      return simplified_associations.first if simplified_associations.size == 1
      return nil if simplified_associations.empty?

      simplified_associations
    end

    def identify_associations
      klass.reflect_on_all_associations.
        reject(&method(:ignored_association?)).
        each do |association|

        add_to_registry(
          Syncify::Association::StandardAssociation.new(
            from_class: klass,
            to_class: association.klass,
            name: association.name,
            destination: built_associations
          )
        )
      end
    end

    def add_to_registry(association)
      association_registry << association unless in_registry?(association)
    end

    def traverse_associations
      while (association = next_untraversed_association)
        association.traversed = true
        association.destination[association.name] = {}

        discover_nested_associations(association, association.destination[association.name])
      end

      built_associations
    end

    def next_untraversed_association
      association_registry.find do |association|
        !association.traversed
      end
    end

    def discover_nested_associations(association, destination)
      association.to_class.
        reflect_on_all_associations.
        reject(&method(:ignored_association?)).
        each do |nested_association|

        pending_association = Syncify::Association::StandardAssociation.new(
          from_class: association.to_class,
          to_class: nested_association.klass,
          name: nested_association.name,
          destination: destination
        )

        add_to_registry(pending_association) unless in_registry?(pending_association) || inverse_of_another_association?(pending_association)
      end
    end

    def inverse_of_another_association?(association)
      association_registry.find do |registered_association|
        association.to_class == registered_association.from_class &&
          association.from_class == registered_association.to_class
      end
    end

    def in_registry?(association)
      association_registry.find do |registered_association|
        association.equal?(registered_association)
      end
    end

    def ignored_association?(association)
      return true if association.class == ActiveRecord::Reflection::ThroughReflection

      false
    end

    # def identify_associations
    #   identified_associations = {}
    #
    #   queue_for_inspection(klass, identified_associations)
    #   inspect_queue
    #
    #   identified_associations
    # end
    #
    # def inspect_queue
    #   inspections_queue.each do |association_to_inspect|
    #     class_to_inspect = association_to_inspect.class_to_inspect
    #     destination = association_to_inspect.destination
    #     queue_for_inspection(class_to_inspect, destination)
    #   end
    # end
    #
    # def simplify_identified_associations(associations)
    #   simplified_associations = associations.each.reduce([]) do |memo, (association, nested_association)|
    #     simplified_association = if nested_association.is_a? PolymorphicAssociation
    #                                nested_association
    #                              elsif nested_association.empty?
    #                                association
    #                              else
    #                                { association => simplify_identified_associations(nested_association) }
    #                              end
    #
    #     memo << simplified_association
    #
    #     memo
    #   end
    #
    #   return simplified_associations.first if simplified_associations.size == 1
    #   return nil if simplified_associations.empty?
    #
    #   simplified_associations
    # end
    #
    # def queue_for_inspection(class_to_inspect, identified_associations_subset)
    #   class_to_inspect.reflect_on_all_associations.
    #     reject(&method(:ignored_association?)).
    #     each do |association_to_inspect|
    #
    #     # skip this inspection if this is a reciprocal association (EG: a belongs_to for a has_many)
    #     next if reciprocal?(association_to_inspect)
    #
    #     print '.' # TODO: delete this line
    #
    #     # if association_to_inspect.polymorphic?
    #     #   queue_polymoprphic_association(class_to_inspect, association_to_inspect, identified_associations_subset)
    #     # else
    #       queue_standard_association(class_to_inspect, association_to_inspect, identified_associations_subset)
    #     # end
    #   end
    # end
    #
    # def queue_polymoprphic_association(class_to_inspect, association_to_inspect, identified_associations_subset)
    #   polymorphic_associations = {}
    #
    #   identified_associations_subset[association_to_inspect.name] = PolymorphicAssociation.new(
    #     association_to_inspect.name,
    #     polymorphic_associations
    #   )
    #
    #   class_to_inspect.
    #     pluck(association_to_inspect.foreign_type).
    #     uniq.
    #     map(&:constantize).
    #     inject(polymorphic_associations) do |polymorphic_associations, type|
    #
    #     polymorphic_associations[type] = {}
    #
    #     queue_for_inspection(type, polymorphic_associations[type])
    #
    #     polymorphic_associations
    #   end
    # end
    #
    # def queue_standard_association(class_to_inspect, association_to_inspect, identified_associations_subset)
    #   # this is the location in the set of overall set of identified association where any
    #   # nested associations from this class being inspected are to be placed. Basically, this is
    #   # where the magic of building out or associations tree happens.
    #   destination = identified_associations_subset[association_to_inspect.name] = {}
    #
    #   # This is a queued association to inspect for this association's target class. (It may have
    #   # already been inspected!) If we can't find one, we create one.
    #   queued_association = find_or_create_queued_association(association_to_inspect.klass,
    #                                                          destination)
    #   # Record that the class we're inspecting referred to the referred-to class. We need this so
    #   # we can detect reciprocal associations.
    #   queued_association.referring_classes << class_to_inspect
    #
    #   inspections_queue << queued_association unless inspections_queue.include?(queued_association)
    # end
    #
    # def find_or_create_queued_association(referred_to_class, destination)
    #   inspections_queue.find { |association| association.for_class?(referred_to_class) } ||
    #     QueuedAssociation.new(class_to_inspect: referred_to_class, destination: destination)
    # end
    #
    # def reciprocal?(association)
    #   inspections_queue.find do |queued_association|
    #     queued_association.reciprocal?(association)
    #   end
    # end
  end
end
