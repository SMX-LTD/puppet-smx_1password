# Generate a sufficiently random string to use as a password
# newpw = generate_password(length)

Puppet::Functions.create_function(:'generate_password') do
  def generate_password(pwlen)
    if pwlen then
      pwlen = 10 if(pwlen < 8)
    else
      pwlen = 10
    end
    SecureRandom.alphanumeric(length)
  end
end

