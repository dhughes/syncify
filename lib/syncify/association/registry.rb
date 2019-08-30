module Syncify
  module Association
    class Registry
      attr_accessor :association_registry, :built_associations

      def initialize
        @association_registry = Set[]
        @built_associations = {}
      end

      def <<(association)
        association_registry << association unless in_registry?(association)
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

      def traverse_associations
        while association = next_untraversed_association
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

          self << pending_association unless in_registry?(pending_association) || inverse_of_another_association?(pending_association)
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

      # TODO: duplicated in Syncify::IdentifyAssociations
      def ignored_association?(association)
        return true if association.class == ActiveRecord::Reflection::ThroughReflection

        false
      end
    end
  end
end
