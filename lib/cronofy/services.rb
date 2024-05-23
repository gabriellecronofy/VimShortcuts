    module Cronofy
      module Services
        # require_relative 'services/accounts.rb'

        def self.all
          Services.constants
            .map    { |const_name| Services.const_get(const_name) }
            .select { |constant| constant.is_a?(Class) }
        end
      end
    end
