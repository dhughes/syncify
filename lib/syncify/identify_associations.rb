module Syncify
  class IdentifyAssociations < ActiveInteraction::Base
    object :klass, class: Class
    symbol :remote_database, default: nil
    array :hints, default: []

    attr_accessor :association_registry, :identified_associations

    def execute
      @association_registry = Set[]
      @identified_associations = {}

      remote do
        identify_associations(klass, identified_associations)

        simplify_associations(traverse_associations)
      end
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

    def identify_associations(from_class, destination, parents = [])
      applicable_associations(from_class).each do |association|
        puts "Inspecting #{from_class.name}##{association.name}"
        pending_association = if association.polymorphic?
                                Syncify::Association::PolymorphicAssociation.new(
                                  from_class: from_class,
                                  association: association,
                                  destination: destination,
                                  parents: parents + [association.hash]
                                )
                              else
                                Syncify::Association::StandardAssociation.new(
                                  from_class: from_class,
                                  association: association,
                                  destination: destination,
                                  parents: parents + [association.hash]
                                )
                              end

        # TODO: figure out how to detect if we have a circular association.
        # see https://www.geeksforgeeks.org/detect-loop-in-a-linked-list/ for an idea
        # this won't work with how we're tracking associations yet, since we don't know if we're
        # traversing the _exact same_ association. But, maybe I could replace `parents` being a list
        # of previous classes in the association chain, but instead be a hash of the actual rails
        # association. That way, if this association's parent rails association hash appears in the
        # list, then we know it's circular. (Sorry future me if this is word salad. I'm whipped
        # right now. It's been a long week. :) )
        next if pending_association.circular?

        association_registry << pending_association
      end
    end

    def traverse_associations
      while (association = next_untraversed_association)
        association.traversed = true

        next if should_ignore_association?(association)

        if association.polymorphic?
          association.to_classes.each do |to_class|
            identify_associations(
              to_class,
              association.create_destination(to_class),
              association.parents
            )
          end
        else
          identify_associations(
            association.to_class,
            association.create_destination(association.name),
            association.parents
          )
        end
      end

      identified_associations
    end

    def should_ignore_association?(association)
      # ignore if association is the inverse of an association that has already been traversed
      traversed_associations.find do |traversed_association|
        traversed_association.inverse_of?(association)
      end
    end

    def traversed_associations
      association_registry.select { |association| association.traversed }
    end

    def next_untraversed_association
      association_registry.find { |association| !association.traversed }
    end

    def applicable_associations(klass)
      klass.
        reflect_on_all_associations.
        reject(&method(:inapplicable_associations))
    end

    def inapplicable_associations(association)
      return true if association.class == ActiveRecord::Reflection::ThroughReflection

      hints.each do |hint|
        return !hint.allowed? if hint.applicable?(association)
      end

      false
    end

    # TODO: this is duplicated from Sync. Consider refactoring
    def remote
      run_in_environment(remote_database) { yield }
    end

    def run_in_environment(environment)
      initial_config = ActiveRecord::Base.connection_config
      ActiveRecord::Base.establish_connection environment
      yield
    ensure
      ActiveRecord::Base.establish_connection initial_config
    end
  end
end
