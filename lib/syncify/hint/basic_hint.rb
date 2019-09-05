module Syncify
  module Hint
    class BasicHint < Syncify::Hint::Hint
      attr_accessor :from_class, :association, :to_class, :allowed
      alias :allowed? :allowed

      def initialize(from_class: nil, association: nil, to_class: nil, allowed:)
        @from_class = from_class
        @association = association
        @to_class = to_class
        @allowed = allowed
      end

      def applicable?(candidate_association)
        evaluate_from(candidate_association) &&
          evaluate_association(candidate_association) &&
          evaluate_to_class(candidate_association)
      end

      def allowed?(candidate_association)
        allowed
      end

      private

      def evaluate_from(candidate_association)
        from_class.nil? || candidate_association.active_record == from_class
      end

      def evaluate_association(candidate_association)
        return true if association.nil?

        if association.is_a? Regexp
          candidate_association.name =~ association ? true : false
        else
          Array.wrap(association).include? candidate_association.name
        end
      end

      def evaluate_to_class(candidate_association)
        return true if to_class.nil?

        if candidate_association.polymorphic?
          associated_classes = Syncify::Association::PolymorphicAssociation.identify_to_classes(
            candidate_association.active_record,
            candidate_association.name
          )

          associated_classes.include?(to_class)
        else
          candidate_association.klass == to_class
        end
      end
    end
  end
end
