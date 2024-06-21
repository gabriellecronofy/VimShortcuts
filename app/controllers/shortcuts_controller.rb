# require "entity_store

class ShortcutsController < ApplicationController
  def show
      id = "66744938a5db6f75840ca57b"
      @shortcut = entity_store.get(id)
  rescue => e 
    rails.logger.error "It doesn't work, the reason is #{e.message} and #{e.class}"
  end
end

# class ShortcutsController < ApplicationController
#   def show
#     @shortcuts = []
    # entity_store.all_ids({}) do |id|
      # entity = entity_store.get(id)
      # @shortcuts << entity if entity.is_a? Shortcut
  #   end
  # end
# end
