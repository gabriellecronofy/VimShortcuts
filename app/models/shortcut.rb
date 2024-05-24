require "entity_store"

class Shortcut
  include Entity

  def self.create(by, at1, shortcut, shortcut_name)
    shortcut = Shortcut.new
    shortcut.record_event ShortcutCreated.new(
      at2: at1,
      by: by,
      shortcut_name: shortcut_name,
    )
  end

  def created_at=(value)
    @at = value
  end

  def created_by=(value)
    @by = value
  end

  def shortcut_name=(value)
    @shortcut_name = value
  end

  class ShortcutCreated
    include EntityEvent

    attr_accessor :at2, :by, :shortcut_name

    def apply(entity)
      entity.created_at = @at2
      entity.created_by = @by
      entity.shortcut_name = @shortcut_name
    end
  end
end
