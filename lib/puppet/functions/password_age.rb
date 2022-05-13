# Return the age of the password for the specified user, using the custom facts
# or -1 if user does not exist
# age = password_age(username)

Puppet::Functions.create_function(:'password_age') do
  def password_age(username)
    scope = closure_scope
	v = scope['facts']['pwage_'+username]
	v = -1 if(v == nil)
	v.to_i
  end
end

