require "entity_store"

class Shortcut
  include Cronofy::Entity

  def self.create(by, at1, action, name)
    shortcut = Shortcut.new
    shortcut.record_event ShortcutCreated.new(
      at2: at1,
      by: by,
      action: action,
      name: name,
    )

    shortcut
  end

  attr_accessor :at, :by, :action, :name

  class ShortcutCreated
    include Cronofy::EntityEvent

    attr_accessor :at2, :by, :action, :name

    def apply(entity)
      entity.at = @at2
      entity.by = @by
      entity.action = @action
      entity.name = @name
    end
  end
end
