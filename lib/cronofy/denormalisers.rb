    module Cronofy
      module Denormalisers
        # require_relative 'denormalisers/accounts.rb'

        def self.all
          Denormalisers.constants
            .map    { |const_name| Denormalisers.const_get(const_name) }
            .select { |constant| constant.is_a?(Class) }
        end

      end
    end
