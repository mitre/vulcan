# frozen_string_literal: true

# Parses duration settings with Postel's Law: be liberal in what you accept.
#
# This is the ONE place duration strings are interpreted. Every setting that
# accepts a human-written duration routes through here, so the accepted
# grammar can never drift between consumers.
#
# EXPLICIT SUFFIX — always respected, in every mode:
#    TimeoutParser.parse('30s')   => 30    (seconds)
#    TimeoutParser.parse('15m')   => 900   (minutes to seconds)
#    TimeoutParser.parse('1h')    => 3600  (hours to seconds)
#
# BARE NUMBERS are ambiguous, so the caller declares what they mean. The two
# modes exist because two settings made incompatible promises to operators
# before this class existed, and silently redefining either would change the
# meaning of values already deployed in the field.
#
#   bare_unit: :magnitude (default) — a size-based heuristic, used by
#   VULCAN_SESSION_TIMEOUT and VULCAN_REMEMBER_ME_DURATION:
#     parse('1')   => 3600  (1-9 = hours)
#     parse('60')  => 3600  (10-299 = minutes)
#     parse('900') => 900   (300+ = seconds)
#
#   Why these ranges:
#     - 1-9: nobody sets a 3-second or 3-minute timeout, but 1-8 hour timeouts
#       are common for dev environments and workday sessions
#     - 10-299: covers all common minute-based configs and preserves backwards
#       compatibility with old VULCAN_SESSION_TIMEOUT values (default was 60)
#     - 300+: the lowest practical seconds value is 300 (5 min, DoD strict),
#       cleanly separating seconds from the minutes range
#
#   bare_unit: :seconds — a bare number is a count of seconds, used by
#   VULCAN_CONSENT_TTL, which has always documented plain seconds:
#     parse('60', bare_unit: :seconds) => 60
#
# FALLBACK for nil, empty, '0' or an unparseable value. It differs by setting
# because the safe direction differs: a session timeout must not become
# infinite, so it falls back to an hour, while a consent TTL falling back to 0
# means "re-prompt every session", which is the stricter AC-8 posture.
#    parse(nil)                    => 3600
#    parse(nil, fallback: 0)       => 0
#
# NOTE for callers: pass the RAW setting value. Casting it to Integer first
# strips the suffix ("24h" -> 24) and silently defeats this class, which is why
# config/vulcan.default.yml emits every duration with to_json rather than to_i.
class TimeoutParser
  DEFAULT_TIMEOUT = 3600 # 1 hour in seconds
  HOURS_MAX = 9          # bare 1-9 = hours under :magnitude
  SECONDS_MIN = 300      # bare 300+ = seconds under :magnitude (10-299 = minutes)

  BARE_UNITS = %i[magnitude seconds].freeze

  def self.parse(value, bare_unit: :magnitude, fallback: DEFAULT_TIMEOUT)
    raise ArgumentError, "unknown bare_unit #{bare_unit.inspect} (expected one of #{BARE_UNITS.inspect})" \
      unless BARE_UNITS.include?(bare_unit)

    raw = value.to_s.strip
    return fallback if raw.empty? || raw == '0'

    case raw
    when /\A(\d+)h\z/i then Regexp.last_match(1).to_i * 3600
    when /\A(\d+)m\z/i then Regexp.last_match(1).to_i * 60
    when /\A(\d+)s\z/i then Regexp.last_match(1).to_i
    when /\A(\d+)\z/ then parse_bare(Regexp.last_match(1).to_i, bare_unit)
    else fallback
    end
  end

  def self.parse_bare(number, bare_unit)
    return number if bare_unit == :seconds

    if number <= HOURS_MAX
      number * 3600
    elsif number < SECONDS_MIN
      number * 60
    else
      number
    end
  end
  private_class_method :parse_bare
end
