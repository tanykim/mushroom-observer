# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_string(key, args = {})
    declare_parameter(key, :string, args)
    str = get_param(key)
    return args[:default] unless str
    limit = args[:limit]
    fail StringTooLong.new(str, limit) if limit && (str.bytesize > limit)
    str
  end

  def parse_email(key, args = {})
    declare_parameter(key, :email, args)
    val = parse_string(key, args)
    return unless val
    email_pattern = /^[\w\-]+@[\w\-]+(\.[\w\-]+)+$/
    return val if val.match(email_pattern)
    fail BadParameterValue.new(val, :email)
  end
end
