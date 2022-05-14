# This should check the password in 1Password
# Return 'true' if the username@hostname is found

# require File.expand_path('../../../util/onepassword', __FILE__)
# $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet/util/onepassword'
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

      if op.nil? {
        raise( "unknown: Unable to connect to 1Password" )
        return nil
      }

      vaults = op.vaults
      vaults.each { |v|
        items = op.items(vault_id: v.id, filter: (
          'title eq "'+secretname+'"'
        ))
        if items.size > 0
          return true
        end
      }
      return false
#    rescue => error
#      raise( "unknown: 1Password lookup ERROR: #{error}" )
#      return nil
    end
    raise( "unknown: Unable to connect to 1Password - how did I get here?" )
    return nil
  end # function
end # create function
