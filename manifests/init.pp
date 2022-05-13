# 1Password class
#
# You make the various settings in the Hiera, or in the 1password.yaml
# on the server (the best place to put it)

class smx_1password( 
  Optional[String] $endpoint,
  Optional[String] $apikey,
  Optional[Integer] $password_length = 10,
{
	# Make sure the puppet master has access to the api server, and
	# the API key is correct
}
