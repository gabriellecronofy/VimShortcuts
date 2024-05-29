require 'securerandom'

class Account
  include Assertive
  include Entity

  simple_attribute :email
  attr_accessor :hashed_password

  def self.create(at, options = {})
    account = Account.new
    account.record_event AccountCreated.new(at: at)
    account.add_email(account, at, options[:email]) if options[:email]
    account
  end

  def add_email(by, at, address, calendar_profile_id = nil)
    assert! address, 'address cannot be nil'
    address.downcase!

    record_event AccountEmailSet.new(by: by.id, at: at, email: address) if email.nil?
  end

  class AccountCreated
    include Cronofy::EntityEvent

    def apply(entity)
      entity.created_at = at
    end
  end
end
