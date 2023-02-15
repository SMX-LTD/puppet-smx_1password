# This should check the password in 1Password
# Return 'true' if the username@hostname is found

# require File.expand_path('../../../util/onepassword', __FILE__)
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))
require 'puppet/util/one_password'
require 'op_connect'

Puppet::Functions.create_function(:'op::check') do
  dispatch :check do
    param 'String', :secretname
    optional_param 'String', :apikey
    optional_param 'String', :endpoint
    return_type 'Boolean' 
  end
  def check(secretname,apikey=nil,endpoint=nil)
    begin
      # Obtail a onepassword object
      op = Puppet::Util::OnePassword.op_connect(apikey,endpoint)

      if op.nil? 
        raise( "OP: Unable to connect to 1Password" )
        return false
      end

      vaults = op.vaults
      vaults.each { |v|
        Puppet.send_log(:info,"OP: Checking for #{secretname} in #{v.name}")
        items = op.items(vault_id: v.id, filter: (
          'title eq "'+secretname+'"'
        ))
        items.each { |i|
          if (i.state.nil? or (i.state != 'DELETED' and i.state != 'ARCHIVED' ))
            # Puppet.send_log(:info,"OP: FOUND #{secretname} in #{v.name}")
            return true
          end
        } # items.each
      } # vaults.each
      Puppet.send_log(:info,"OP: NOT FOUND #{secretname}")
      return false
    rescue => error
      Puppet.send_log( :err, "OP: 1Password lookup error for #{secretname}: #{error.message}" )
      raise( "OP: 1Password lookup error for #{secretname}: #{error.message}" )
      return false
    end
    raise( "OP: Unable to connect to 1Password - how did I get here?" )
    return false
  end # function
end # create function
