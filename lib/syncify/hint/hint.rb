module Syncify
  module Hint
    class Hint
      def applicable?(candidate_association)
        false
      end

      def allowed?(candidate_association)
        true
      end
    end
  end
end
