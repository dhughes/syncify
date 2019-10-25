module Syncify
  module Association
    class PolymorphicAssociation
      attr_accessor :from_class, :to_classes, :name, :destination, :traversed, :parents

      def self.identify_to_classes(from_class, association_name)
        association = from_class.reflect_on_association(association_name)
        @cache ||= {}
        @cache[from_class] ||= {}
        @cache[from_class][association_name] ||= from_class.
          where("#{association.foreign_type} != ''").
          distinct.
          pluck(association.foreign_type).
          uniq.
          compact.
          map(&:constantize)
      end

      def initialize(from_class:, association:, destination:, parents: [])
        @from_class = from_class
        @to_classes = Syncify::Association::PolymorphicAssociation.identify_to_classes(from_class, association.name)
        @name = association.name
        @destination = destination
        @traversed = false
        @parents = parents
      end

      def polymorphic?
        true
      end

      def traversed?
        traversed
      end

      def circular?
        last_parent = parents[-1]
        previous_parents = parents[0..-2]
        previous_parents.include? last_parent
      end

      def inverse_of?(association)
        if association.polymorphic?
          association.to_classes.include?(from_class) &&
            to_classes.include?(association.from_class) &&
            self.parents == association.parents[0..-2]
        else
          from_class == association.to_class &&
            to_classes.include?(association.from_class) &&
            self.parents == association.parents[0..-2]
        end
      end

      def create_destination(association_name)
        destination[name] ||= {}
        destination[name][association_name] = {}
      end

      def hash
        "#{self.from_class.to_s}#{self.to_classes.map(&:to_s)}#{self.name}#{self.parents.hash}".hash
      end

      def eql?(other_association)
        return false unless other_association.is_a? PolymorphicAssociation
        self.from_class == other_association.from_class &&
          self.to_classes == other_association.to_classes &&
          self.name == other_association.name &&
          self.parents == other_association.parents
      end
    end
  end
end
