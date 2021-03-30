# stdlib
require 'date'
require 'json'

# Gemfile dependencies
require 'redis'
require 'faraday'

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

def is_valid_tz?(timezone_string)
    return false unless TIMEZONE_LIST.include? timezone_string
    return true
end

def timeat(timezone_string)
    return 'unknown timezone' unless is_valid_tz?(timezone_string)

    # Increment the number of times this particular timezone has been queried in the Redis DB
    # (If the key isn't in redis, this operation sets the value to 1)
    @redis.incr timezone_string

    # Query the World Time API for the current time at the given timezone string
    response = Faraday.get("http://worldtimeapi.org/api/timezone/#{timezone_string}")
    tzdata = JSON.parse response.body
    
    begin
        datetime = tzdata['datetime']
    rescue
        raise 'Response from World Time API did not contain any time data!'
    end

    begin
        parsed_datetime = DateTime.rfc3339 datetime
    rescue
        raise "Could not parse time from provided string: #{datetime}"
    end

    return d.strftime('%d %b %Y %H:%M')
end

def fetch_popularity(tz)
    total = @redis.get tz
    return total.to_i unless total.nil?
    return 0
end

def timepopularity(tz_or_prefix)
    # If the value we get for this argument is a valid fully qualified timezone, then we simply
    # return the value stored in Redis for the number of times that fully qualified timezone has
    # been queried.
    if is_valid_tz? tz_or_prefix
        return fetch_popularity(tz_or_prefix)
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
        return sum
    end
end