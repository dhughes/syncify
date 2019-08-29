module Syncify
  class IdentifyAssociations < ActiveInteraction::Base
    object :klass, class: Class

    attr_accessor :inspections_queue

    def execute
      @inspections_queue = []

      simplify_identified_associations(identify_associations)
    end

    private

    def identify_associations
      identified_associations = {}

      queue_for_inspection(klass, identified_associations)
      inspect_queue

      identified_associations
    end

    def inspect_queue
      inspections_queue.each do |association_to_inspect|
        class_to_inspect = association_to_inspect.class_to_inspect
        destination = association_to_inspect.destination
        queue_for_inspection(class_to_inspect, destination)
      end
    end

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

    def queue_for_inspection(class_to_inspect, identified_associations_subset)
      class_to_inspect.reflect_on_all_associations.
        reject(&method(:ignored_association?)).
        each do |association_to_inspect|

        # skip this inspection if this is a reciprocal association (EG: a belongs_to for a has_many)
        next if reciprocal?(association_to_inspect)

        print '.' # TODO: delete this line

        # if association.polymorphic?
        #   binding.pry
        # end

        # this is the location in the set of overall set of identified association where any
        # nested associations from this class being inspected are to be placed. Basically, this is
        # where the magic of building out or associations happens.
        destination = identified_associations_subset[association_to_inspect.name] = {}

        # This is a queued association to inspect for this association's target class. (It may have
        # already been inspected!) If we can't find one, we create one.
        queued_association = find_or_create_queued_association(association_to_inspect.klass,
                                                               destination)
        # Record that the class we're inspecting referred to the referred-to class. We need this so
        # we can detect reciprocal associations.
        queued_association.referring_classes << class_to_inspect

        inspections_queue << queued_association unless inspections_queue.include?(queued_association)
      end
    end

    def find_or_create_queued_association(referred_to_class, destination)
      inspections_queue.find { |association| association.for_class?(referred_to_class) } ||
        QueuedAssociation.new(class_to_inspect: referred_to_class, destination: destination)
    end

    def reciprocal?(association)
      inspections_queue.find do |queued_association|
        queued_association.reciprocal?(association)
      end
    end

    def ignored_association?(association)
      return true if association.class == ActiveRecord::Reflection::ThroughReflection

      false
    end
  end
end
