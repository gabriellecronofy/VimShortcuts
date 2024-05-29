module Cronofy
  module EntityEvent
    def self.included(klass)
      klass.class_eval do
        include EntityStore::Event
        include Cronofy::CronofyAttributes

        attr_accessor :by
        time_attribute :at
      end
    end
  end
end
