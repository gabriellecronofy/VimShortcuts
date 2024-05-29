require 'tzinfo'
require 'csv'
require 'uri'

module Cronofy
  class Utils
    include Assertive

    READABLE_CHARS = 'ACDEFHJKMNPQRWXYZ2349'.freeze
    NON_READABLE_CHARS_REGEXP = Regexp.new("[^#{READABLE_CHARS}]").freeze
    GENERIC_EMAIL_DOMAINS_FILE = File.join(File.dirname(__FILE__), "data/generic_email_domains_list.csv").freeze

    ONE_MINUTE_IN_SECONDS = 60
    ONE_HOUR_IN_SECONDS = 60 * ONE_MINUTE_IN_SECONDS
    ONE_DAY_IN_SECONDS = 24 * ONE_HOUR_IN_SECONDS
    ONE_WEEK_IN_SECONDS = 7 * ONE_DAY_IN_SECONDS

    def self.diff_lines(before:, after:)
      before_set = lines_set(before)
      after_set = lines_set(after)

      {
        added: (after_set - before_set).sort,
        removed: (before_set - after_set).sort,
        normalized: after_set.sort.join("\n"),
      }
    end

    def self.lines_set(value)
      value.to_s.split("\n").map(&:strip).reject(&:empty?).sort.to_set
    end

    def self.split_text_area_items(value)
      [value].flatten
        .flat_map { |v| Utils.lines_set(v).to_a }
        .map { |v| Utils.strip_all_whitespace(v) }
        .uniq
    end

    def self.readable_random_string(args = {})
      length = args.fetch(:length, 16)
      separator = args.fetch(:separator, '-')

      chars = (1..length).map { READABLE_CHARS[SecureRandom.random_number(READABLE_CHARS.length)] }

      chars.each_slice(4).map(&:join).join(separator)
    end

    def self.readable_random_string_match?(left, right)
      return false unless left && right

      left.upcase.gsub(NON_READABLE_CHARS_REGEXP, '') == right.upcase.gsub(NON_READABLE_CHARS_REGEXP, '')
    end

    def self.equal_sets?(left, right)
      left_set = Set.new(left)
      right_set = Set.new(right)

      left_set == right_set
    end

    def self.get_type_constant(type_name)
      type_name.split('::').inject(Object) { |obj, name| obj.const_get(name) }
    end

    def self.set_type_constant(type_name)
      type_name.split('::').inject(Object) do |obj, name|
        obj.const_defined?(name) ? obj.const_get(name) : obj.const_set(name, Class.new)
      end
    end

    def self.camelcase(term)
      term.to_s.split("_").collect { |s| s.slice(0, 1).capitalize + s.slice(1..-1) }.join
    end

    def self.nil_if_empty(value)
      value && value.empty? ? nil : value
    end

    def self.empty?(value)
      value.nil? || value.empty?
    end

    def self.blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def self.valid_tzid?(value)
      return false if blank?(value)

      begin
        TimeZoneHelper.get(value)
        true
      rescue
        false
      end
    end

    SECONDS_IN_DAY = 24 * 60 * 60

    def self.calculate_next_utc_hour(local_hour, timezone_name, reference_time = Time.now)
      calculate_next_utc(local_hour, timezone_name, reference_time).hour
    end

    def self.calculate_next_utc(local_hour, timezone_name, reference_time = Time.now)
      zone = TimeZoneHelper.get(timezone_name)

      local = zone.utc_to_local(reference_time.getutc)

      tomorrow = local.to_date + 1
      local_tomorrow = Time.new(tomorrow.year, tomorrow.month, tomorrow.day, local_hour)

      zone.local_to_utc(local_tomorrow)
    end

    def self.utc_midnight(time)
      time = time.getutc unless time.utc?
      Time.utc(time.year, time.month, time.day)
    end

    def self.local_end_of_day_in_utc(time, timezone_name)
      (EventTime.new(date: time, time_of_day: "00:00", tzid: timezone_name) + Duration.new(days: 1)).to_time.getutc
    end

    # Internal: Returns the given list of email addresses with their aliased
    # equivalents.
    #
    # The original emails will *always* be returned first in their normalised
    # form, followed by their aliased equivalents (if any).
    #
    # emails - Array of Strings, will be flattened so it can be used in the
    #          params style or passed an Array directly.
    #
    # Returns cleansed versions of the emails and their aliases.
    #
    def self.emails_and_aliases(*emails)
      emails = emails.flatten.compact.map(&:downcase)
      aliases = alias_emails(emails)

      emails.concat(aliases)
    end

    TAG_REGEX = /(^|\W)#(?<tag>[\w-]+)/i

    def self.convert_to_tags(values)
      return [] unless values

      values.compact.map { |value| convert_to_tag(value) }
    end

    def self.convert_to_tag(value)
      value
        .downcase            # downcase everything
        .gsub(/[^\w-]/, ' ') # replace all non-word or hyphen characters with spaces
        .strip               # get rid of leading/trailing whitespace
        .tr(' ', '-')        # switch remaining whitespace to hyphens
        .squeeze('-')        # get rid of consecutive hyphens
    end

    def self.extract_tags(*sources)
      sources.map { |source| source ? source.scan(TAG_REGEX) : [] }
        .flatten
        .map(&:downcase)
        .uniq
    end

    def self.strip_tags(source)
      return unless source
      source.gsub(TAG_REGEX, '')
        .strip
        .squeeze(' ')
    end

    def self.convert_to_tag_filter_set(values)
      filters = values.map do |value|
        case value
        when TagFilter
          value
        when Hash
          TagFilter.new(value)
        when String
          TagFilter.new(tag: value, included_attributes: TagFilter::DEFAULT_ATTRIBUTES)
        else
          raise "Do not know how to convert #{value.class} (#{value}) to TagFilter"
        end
      end

      Set.new(filters)
    end

    def self.base64digest(args = {})
      input = args.sort_by { |k, _| k.to_s }.map { |*a| a.join(':') }.join('\n')
      Digest::MD5.base64digest(input)
    end

    def self.hexdigest(args = {})
      input = args.sort_by { |k, _| k.to_s }.map { |*a| a.join(':') }.join('\n')
      Digest::MD5.hexdigest(input)
    end

    def self.dup_with_symbolized_keys(hash)
      return nil unless hash

      new_hash = {}

      hash.each_key do |key|
        sym_key = key.to_sym
        # Prefer existing Symbol key values over their String counterparts
        value = hash.fetch(sym_key, hash[key])
        new_hash[sym_key] = value
      end

      new_hash
    end

    def self.deep_symbolize_keys(hash)
      case hash
      when Hash
        new_hash = {}

        hash.each_key do |key|
          sym_key = key.to_sym
          # Prefer existing Symbol key values over their String counterparts
          value = hash.fetch(sym_key, hash[key])
          value = deep_symbolize_keys(value)
          new_hash[sym_key] = value
        end

        new_hash
      when Array
        hash.map { |value| deep_symbolize_keys(value) }
      else
        hash
      end
    end

    def self.delayed_each(items, args = {})
      duration = assert_fetch! args, :duration

      # Allow time-related dependencies to be overridden for testing
      sleep_fn = args.fetch(:sleep_fn, Kernel.method(:sleep))
      time = args.fetch(:time, Time)

      sleeps_required = items.count - 1

      if sleeps_required > 0
        sleep_duration = duration / sleeps_required.to_f
      else
        sleep_duration = 0
      end

      start = time.now

      item_and_next_start = items.each_with_index.map do |item, index|
        next_offset = (index + 1) * sleep_duration
        [item, start + next_offset]
      end

      if item_and_next_start.any?
        # Stop the last item from invoking the sleep_fn
        item_and_next_start.last[1] = start
      end

      item_and_next_start.each do |item, next_start|
        yield item
        until_next = next_start - time.now
        sleep_fn.call(until_next) if until_next > 0
      end
    end

    def self.stringify_values(hash)
      return nil unless hash

      new_hash = {}

      hash.each_pair do |key, value|
        case value
        when Hash
          new_hash[key] = stringify_values(value)
        when Symbol
          new_hash[key] = value.to_s
        when Time
          new_hash[key] = value.getutc.strftime("%Y-%m-%dT%H:%M:%SZ")
        else
          new_hash[key] = value
        end
      end

      new_hash
    end

    def self.attribute_value(value)
      if value.respond_to?(:attributes)
        value.attributes
      elsif value.is_a?(Hash)
        h = {}
        value.each_pair { |k, v| h[k] = attribute_value(v) }
        h
      elsif value.is_a?(Array)
        value.collect { |v| attribute_value(v) }
      else
        value
      end
    end

    def self.shortened_third_party_id(value)
      sha_digest(value)
    end

    def self.sha_digest(value)
      Digest::SHA256.base64digest(value.to_s)
    end

    def self.domain_from_email(email)
      return unless email

      _, domain = email.split("@", 2)
      domain
    end

    def self.generic_email_domain?(email_or_domain)
      return false if email_or_domain.blank?

      email_or_domain = email_or_domain.downcase
      domain = email_or_domain.include?("@") ? domain_from_email(email_or_domain) : email_or_domain

      generic_domains.include?(domain)
    end

    def self.generic_domains
      # CSV.read returns an array of arrays
      @generic_domains ||= CSV.read(GENERIC_EMAIL_DOMAINS_FILE).flatten
    end

    def self.alias_emails(emails)
      aliases = []

      emails.each do |email|
        # As Google use gmail.com and googlemail.com interchangeably, generate
        # an alias with the alternative if there's a match to the original.

        if email.end_with?('@googlemail.com')
          aliases << email.sub(/@googlemail\.com\Z/, '@gmail.com')
        end

        if email.end_with?('@gmail.com')
          aliases << email.sub(/@gmail\.com\Z/, '@googlemail.com')
        end
      end

      aliases
    end

    def self.email_as_mailto(email)
      return unless email
      return email unless email.include?("@")
      return email if email.start_with?("mailto:")

      "mailto:#{email}"
    end

    def self.effective_contract_period(contract)
      effective_start_date = effective_contract_start_date(contract)

      [effective_start_date, effective_start_date.next_month(contract.periods)]
    end

    def self.effective_contract_start_date(contract)
      return contract.start_date if contract.initial_month_usage == 1

      days_in_month = Date.new(contract.start_date.year, contract.start_date.month, -1).day
      unused_days = days_in_month - (days_in_month * contract.initial_month_usage).to_i

      contract.start_date + unused_days
    end

    def self.same_month(date1, date2)
      [date1.year, date1.month] == [date2.year, date2.month]
    end

    def self.strip_all_whitespace(string)
      # [[:space:]] matches non-breaking whitespace too (\u00A0)
      string.gsub(/[[:space:]]+/, "")
    end

    def self.url?(string)
      /\A#{URI::DEFAULT_PARSER.make_regexp}\z/.match?(string)
    end

    def self.email?(string)
      /\A\S+@\S+\.\S+\z/.match?(string)
    end

    def self.valid_json?(json)
      JSON.parse(json)
      true
    rescue JSON::ParserError, TypeError
      false
    end
  end
end
