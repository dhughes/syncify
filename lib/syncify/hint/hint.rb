module Syncify
  module Hint
    class Hint
      def applicable?(candidate_association)
        false
      end

      def allowed?
        true
      end
    end
  end
end
