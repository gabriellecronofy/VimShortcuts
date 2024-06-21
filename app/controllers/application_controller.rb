class ApplicationController < ActionController::Base
  include Cronofy::Stores
      def entity_store
        @_entity_store ||= EntityStore::Store.new
      end
end
