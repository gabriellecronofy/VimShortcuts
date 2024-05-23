    require 'hatchet'

    class SequelLogger
      include Hatchet

      [:debug, :info, :warn, :error, :fatal].each do |level|
        define_method(level) do |message|
          log.add(:debug, message)
        end
      end
    end

    class Hatchet::HatchetLogger
      def broadcast_to(msg)
        puts msg
      end
    end
