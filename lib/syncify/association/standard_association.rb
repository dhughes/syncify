module Syncify
  module Association
    class StandardAssociation
      attr_accessor :from_class, :to_class, :name, :destination, :traversed, :parents

      def initialize(from_class:, association:, destination:, parents: [])
        @from_class = from_class
        @to_class = association.klass
        @name = association.name
        @destination = destination
        @traversed = false
        @parents = parents
      end

      def polymorphic?
        false
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
            association.from_class == to_class &&
            self.parents == association.parents[0..-2]
        else
          association.to_class == from_class &&
            association.from_class == to_class &&
            self.parents == association.parents[0..-2]
        end
      end

      def create_destination(name)
        destination[name] = {}
      end

      def hash
        "#{self.from_class.to_s}#{self.to_class.to_s}#{self.name}#{self.parents.hash}".hash
      end

      def eql?(other_association)
        self.from_class == other_association.from_class &&
          self.to_class == other_association.to_class &&
          self.name == other_association.name &&
          self.parents == other_association.parents
      end
    end
  end
end
