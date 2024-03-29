# Return the default vault to use for storing new passwords

# require File.expand_path('../../../util/onepassword', __FILE__)
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))
require 'puppet/util/one_password'
require 'op_connect'

Puppet::Functions.create_function(:'op::default_vault') do
  dispatch :default_vault do
    return_type 'String' 
  end
  def default_vault()
    begin
      v = Puppet::Util::OnePassword.op_default_vault()

      if v.nil?
        Puppet.send_log(:warning,"OP: no default 1Password vault name is configured" )
        return "Default"
      end
  
      return v
    end
  end # default value
end # create function

