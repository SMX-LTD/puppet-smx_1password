# Change password if older than 30 days, updating secret server
# This will also change and update if password is not yet defined in 1P
# It will NOT verify that SS record contains the correct password though as
# this is not necessarily possible with various backends
# Only users with UID<500 are checked; to change this, edit the facter module
# to set facts for ALL users.
#
# Facter should set facts: pwage_(.*) for all accounts <500
#
# To use:
#    Make sure necessary settings are in the server 1password.yml, or
#    defined in Heira
# Puppet code example
#    op::user { root: }
#    op::user { oracle: maxage=>60, vault=>'Oracle Passwords' }
# Hiera example
#    op::user_passwords:
#      op1: {}
#      op2:
#        maxage: 7
#      foobar:
#        username: op3
#        password_length: 20
#        minreset: 14
#      user:
#        secret: "Password for user on hostname"
#
# Assumptions:
#    1. The specified vault exists, is writeable, and defaults to appropriate
#       sharing rules
#    2. All newly created passwords will be type Login
#    3. Password ages are in /etc/shadow in standard format
#    4. The configuration file for 1password.yaml exists on the puppetmaster
#       and is correctly configured

# This adds a new username to check for expiry
define op::user(
  Integer $maxage = 30,
  Optional[String] $username = undef,  # defaults to the namevar
  Optional[String] $secret = undef, # defaults to username@fqdn
  Optional[String] $vault = undef,
  Optional[Integer] $minreset = 0,
  Optional[Integer] $password_length = 12
) {

    if ! $username {
        $uname = $name
    } else {
        $uname = $username
    }
    if ! $secret {
        $secretname = "${uname}@${::fqdn}"
    } else {
        $secretname = $secret
    }
    $age_account = password_age($uname)
    $opexists = op::check($secretname)
    if ( $age_account < 0 ) {
      notify { "op-secret-$uname": withpath=>false,
         message=>"1Password : Username ${uname} does not exist on ${::fqdn}!" 
      }
    } else {
      # update the password if it is too old, or if we dont have anything
      # stored in the 1password server yet
      if $age_account > $maxage or ! $opexists {
        notice ( "1Password : Password for ${uname} on ${::fqdn} has age of ${age_account} : 1Password record = ${opexists}" )
        notify { "op-secret-${uname}-toupdate": withpath=>false,
          message=>"1Password : Need update for ${secretname} because either ${age_account} > ${maxage} or ${opexists} == false" 
        }
        # update 1Password
        if $::noop {
          notify { "op-secret-$uname": withpath=>false,
            message=>"1Password : Not updating for $uname because in --noop mode"
          }
        } else {
          # change password for account
          notice( "1Password : Updating password for $secretname" )
          $newpass = generate_password($password_length)
          $rv = op::set_secret($secretname,$newpass,true,$vault)
          if $rv  {
            notify { "op-secret-$uname": withpath=>false,
              message=>"ERROR: 1Password password update FAILED for ${secretname}: ${rv}" 
            }
          } else {
            # change password on system
            exec { "passwd_$name":
              command=>$operatingsystem?{
                # RedHat allows /usr/bin/passwd --stdin, but all
                # allow use of /usr/sbin/chpasswd
                # Solaris needs chpasswd to be installed but then it
                # works OK.  AIX, no idea...
                /(RedHat|CentOS|Fedora|Alma|Rocky)/=>"/usr/bin/chage -m '$minreset' '$uname';/bin/echo '$uname:$newpass'|/usr/sbin/chpasswd",
                /(Ubuntu|Debian)/       =>"/usr/bin/chage -m '$minreset' '$uname';/bin/echo '$uname:$newpass'|/usr/sbin/chpasswd",
                /(Solaris|SunOS)/       =>"/bin/echo '$uname:$newpass'|/usr/sbin/chpasswd",
                default=>"/bin/false",
              },
              onlyif=>"/bin/egrep '^$uname:' /etc/passwd",
            }
            -> notify { "op-secret-$uname": withpath=>false,
              message=>"1Password : Password updated for ${secretname}" 
            }
          }
        }
      }
    }
}

