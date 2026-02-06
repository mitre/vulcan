# frozen_string_literal: true

# Parses timeout duration values with Postel's Law: be liberal in what you accept.
#
# Supports three modes:
#
# 1. EXPLICIT SUFFIX — always respected:
#    TimeoutParser.parse('30s')   => 30    (seconds)
#    TimeoutParser.parse('15m')   => 900   (minutes to seconds)
#    TimeoutParser.parse('1h')    => 3600  (hours to seconds)
#
# 2. PLAIN NUMBER — smart heuristic based on magnitude:
#    TimeoutParser.parse('1')     => 3600  (1-9 = hours)
#    TimeoutParser.parse('60')    => 3600  (10-299 = minutes)
#    TimeoutParser.parse('900')   => 900   (300+ = seconds)
#
#    Why these ranges:
#    - 1-9: nobody sets a 3-second or 3-minute timeout, but 1-8 hour timeouts
#      are common for dev environments and workday sessions
#    - 10-299: covers all common minute-based configs and preserves backwards
#      compatibility with old VULCAN_SESSION_TIMEOUT values (default was 60)
#    - 300+: the lowest practical seconds value is 300 (5 min, DoD strict),
#      cleanly separating seconds from the minutes range
#
# 3. DEFAULT: 3600 seconds (1 hour) for nil, empty, or zero.
#
class TimeoutParser
  DEFAULT_TIMEOUT = 3600 # 1 hour in seconds
  HOURS_MAX = 9          # plain 1-9 = hours
  SECONDS_MIN = 300      # plain 300+ = seconds (10-299 = minutes)

  def self.parse(value)
    raw = value.to_s.strip
    return DEFAULT_TIMEOUT if raw.empty? || raw == '0'

    case raw
    when /\A(\d+)h\z/i  then Regexp.last_match(1).to_i * 3600
    when /\A(\d+)m\z/i  then Regexp.last_match(1).to_i * 60
    when /\A(\d+)s\z/i  then Regexp.last_match(1).to_i
    when /\A(\d+)\z/
      n = Regexp.last_match(1).to_i
      if n <= HOURS_MAX
        n * 3600
      elsif n < SECONDS_MIN
        n * 60
      else
        n
      end
    else DEFAULT_TIMEOUT
    end
  end
end
