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
#    op::user { root: }
#    op::user { oracle: maxage=>60, vault=>'Oracle Passwords' }
#
# Assumptions:
#    2. The specified vault exists, is writeable, and defaults to appropriate
#       sharing rules
#    4. All newly created passwords will be type Login
#    5. Passwords can be changed via "echo 'pass'|passwd --stdin username"
#       This is true under RedHat but not necessarily elsewhere.
#    6. Password ages are in /etc/shadow in standard format

# This adds a new username to check for expiry
define op::user(
  Integer $maxage = 30,
  Optional[String] $username = undef,  # defaults to the namevar
  Optional[String] $vault = undef,
  Optional[Integer] $minreset = 0,
  Optional[Integer] $password_length = 12
) {

    if ! $username {
        $uname = $name
    } else {
        $uname = $username
    }
    if ! $vault {
        $cvault = op::default_vault()
    } else {
        $cvault = $vault
    }
    $secretname = "${uname}@${::fqdn}"
    $age_account = password_age($uname)
    $opexists = op::check($secretname)
    notice ( "Password for ${uname} has age of ${age_account} : 1Password record = ${opexists}" )
    if ( $age_account < 0 ) {
      notify { "op-secret-$uname": withpath=>false,
         message=>"Username ${uname} does not exist on this host!" 
      }
    } else {
      if $age_account > $maxage or ! $op_exists {
        # update 1Password
        if $::noop {
          notify { "op-secret-$uname": withpath=>false,
            message=>"Not updating 1Password for $uname because in --noop mode" }
        } else {
          # change password for account
          notice( "Updating password for $secretname" )
          $newpass = generate_password($password_length)
          $rv = op::set_secret($secretname,$newpass,$cvault)
          if ! $rv  {
            notify { "op-secret-$uname": withpath=>false,
              message=>"ERROR: 1Password password update FAILED for ${secretname}: ${rv}" }
          } else {
            notify { "op-secret-$uname": withpath=>false,
              message=>"1Password password updated for ${secretname}" }
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
          }
        }
      }
    }
}

