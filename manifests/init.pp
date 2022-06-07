# 1Password class
#
# You make the various settings in the  1password.yaml
# on the server (the best place to put it)

# Include this class if you want to have the automatic password management
# done through hiera in op::user_passwords

class op ( 
  Optional[Hash] $user_passwords = {},
) {
    # Make sure the puppet master has access to the api server, and
    # the API key is correct

    create_resources( 'op::user', $user_passwords )
}
