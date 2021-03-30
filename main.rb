# stdlib
require 'date'
require 'json'

# Gemfile dependencies
require 'redis'
require 'faraday'

# Setup: these functions don't belong in this library; we should break out this functionality
#        later so that the chatbot is invoking Redis and passing the TIMEZONE_LIST back to the
#        is_valid_tz? method that requires it.

# Get list of valid timezones
begin
    response = Faraday.get('http://worldtimeapi.org/api/timezone')
    TIMEZONE_LIST = JSON.parse response.body
rescue => error
    raise "Unable to fetch list of valid timezone names from the World Time API; there may be a connectivity problem. Error: #{error.message}"
end

# Initialize Redis client
begin
    @redis = Redis.new
rescue => error
    raise "Could not start redis instance; is the redis backend started on this system and reachable at port 6379? Error: #{error.message}"
end

# Utility Methods

# @param timezone_string [String] a string to be validated as a timezone
# @return [Boolean] true if the string is a valid timezone, false otherwise
def is_valid_tz?(timezone_string)
    return false unless TIMEZONE_LIST.include? timezone_string
    return true
end

# @param tz [String] a fully-qualified timezone
# @return [Integer] the number of times that the fully-qualified timezone has been searched, from the redis backend
def fetch_popularity(tz)
    total = @redis.get tz
    return total.to_i unless total.nil?
    return 0
end

# Functions for Frontend

# @param timezone_string [String] a string (should be a valid timezone, but this is checked)
# @return [String] the current date and time at the supplied timezone
def timeat(timezone_string)
    return 'unknown timezone' unless is_valid_tz?(timezone_string)

    # Increment the number of times this particular timezone has been queried in the Redis DB
    # (If the key isn't in redis, this operation sets the value to 1). Keys with no value inserted
    # return nil when we try to redis.get() them.
    @redis.incr timezone_string

    # Query the World Time API for the current time at the given timezone string
    response = Faraday.get("http://worldtimeapi.org/api/timezone/#{timezone_string}")
    tzdata = JSON.parse response.body
    
    # Validate response contains an expected key
    begin
        datetime = tzdata['datetime']
    rescue
        raise 'Response from World Time API did not contain any time data!'
    end

    # Convert response to the expected format (from RFC 3339 to Day Mon Yr Hr:Min)
    begin
        parsed_datetime = DateTime.rfc3339 datetime
    rescue
        raise "Could not parse time from provided string: #{datetime}"
    end

    return d.strftime('%d %b %Y %H:%M')
end

# @param tz_or_prefix [String] a timezone or timezone prefix to find popularity for
# @return [String] the number of times a search for the given timezone or prefix has been carried out
def timepopularity(tz_or_prefix)
    # If the value we get for this argument is a valid fully qualified timezone, then we simply
    # return the value stored in Redis for the number of times that fully qualified timezone has
    # been queried.
    if is_valid_tz? tz_or_prefix
        return fetch_popularity(tz_or_prefix).to_s
    # If we get a prefix, then we will iterate through all known timezones until we figure out how many
    # fully qualified timezones the prefix applies to. We'll return 0 if there are no valid fully qualified
    # timezones that match; else, we'll sum the values at the keys of all the timezones we found.
    else
        timezones = TIMEZONE_LIST.grep(/#{tz_or_prefix}\/\s+/)
        
        return 0 if timezones.empty?
        
        sum = 0
        timezones.each do |tz|
            sum += fetch_popularity.to_i
        end
        return sum.to_s
    end
end