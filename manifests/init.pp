# 1Password class
#
# You make the various settings in the Hiera, or in the 1password.yaml
# on the server (the best place to put it)

class op ( 
  Optional[Hash] $user_passwords = {},
  Optional[String] $endpoint = undef,
  Optional[String] $apikey = undef,
  Optional[String] $default_vault = undef,
  Optional[String] $configfile = undef,
  Optional[Integer] $password_length = 10,
) {
    # Make sure the puppet master has access to the api server, and
    # the API key is correct

    create_resources( 'op::user', $user_passwords )
}
