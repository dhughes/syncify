module Syncify
  class IdentifyAssociations < ActiveInteraction::Base
    object :klass, class: Class

    attr_accessor :association_registry, :identified_associations

    def execute
      @association_registry = Set[]
      @identified_associations = {}

      identify_associations(klass, identified_associations)

      simplify_associations(traverse_associations)
    end

    private

    def simplify_associations(associations)
      simplified_associations = associations.each.reduce([]) do |memo, (association, nested_association)|
        simplified_association = if association.is_a? Class
                                   { association => simplify_associations(nested_association) }
                                 elsif nested_association.empty?
                                   association
                                 else
                                   { association => simplify_associations(nested_association) }
                                 end

        memo << simplified_association
        memo
      end

      if simplified_associations.map(&:class).uniq == [Hash]
        return simplified_associations.inject({}) { |memo, association| memo.merge(association) }
      end
      return simplified_associations.first if simplified_associations.size == 1
      return nil if simplified_associations.empty?

      simplified_associations
    end

    def identify_associations(from_class, destination)
      applicable_associations(from_class).each do |association|
        # TODO: add support for polymorphic associations
        pending_association = if association.polymorphic?
                                Syncify::Association::PolymorphicAssociation.new(
                                  from_class: from_class,
                                  association: association,
                                  destination: destination
                                )
                              else
                                Syncify::Association::StandardAssociation.new(
                                  from_class: from_class,
                                  association: association,
                                  destination: destination
                                )
                              end

        association_registry << pending_association unless inverse_of_another_association?(pending_association)
      end
    end

    def traverse_associations
      while (association = next_untraversed_association)
        association.traversed = true

        # TODO: handle this correctly
        if association.polymorphic?
          association.to_classes.each do |to_class|
            identify_associations(
              to_class,
              association.create_destination(to_class)
            )
          end
        else
          identify_associations(
            association.to_class,
            association.create_destination(association.name)
          )
        end
      end

      identified_associations
    end

    def next_untraversed_association
      association_registry.find { |association| !association.traversed }
    end

    def applicable_associations(klass)
      klass.
        reflect_on_all_associations.
        reject(&method(:ignored_association?))
    end

    def inverse_of_another_association?(association)
      association_registry.find do |registered_association|
        association.inverse_of?(registered_association)
      end
    end

    def ignored_association?(association)
      # TODO: check if any hints explicitly allow this association. If so, return false.

      # TODO: check if any hints explicitly disallow this association. If so, return true.

      # TODO: extract this to a hint class? Maybe create an array of hints that we iterate through?
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
