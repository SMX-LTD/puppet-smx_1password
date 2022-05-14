# Set the password in the 1Password api
#
# Puppet ruby doc: https://www.rubydoc.info/gems/puppet/Hiera/PuppetFunction
# 1P API doc : https://developer.1password.com/docs/connect/connect-api-reference
# SCIM filter doc: https://ldapwiki.com/wiki/SCIM%20Filtering
# op_connect ruby doc: https://github.com/partydrone/connect-sdk-ruby

# require File.expand_path('../../../util/onepassword', __FILE__)
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet/util/onepassword'
require 'op_connect'

Puppet::Functions.create_function(:'op::get_secret') do
  dispatch :get_secret do
    param 'String', :secretname
    optional_param 'Boolean', :exact
    optional_param 'String', :apikey
    optional_param 'String', :endpoint
    return_type 'String' 
  end
  def get_secret(secretname,exact=true,apikey=nil,endpoint=nil)
    begin
      # Obtail a onepassword object
      op = Puppet::Util::OnePassword.op_connect(apikey,endpoint)

      if op.nil? {
        raise( "unknown: Unable to connect to 1Password" )
        return false
      }

      vaults = op.vaults
      vaults.each { |v|
        items = op.items(
          vault_id: v.id, 
          filter: ('title eq "'+secretname+'"')
        )
        # maybe we should check all vaults for exact before we allow fuzzy
        if items.size < 1 and ! exact
          items = op.items(
            vault_id: v.id, 
            filter: ('title co "'+secretname+'"')
          )
        end
        # items is now an array of item objects
        if items.size > 0 
          thisid = nil
          items.each { |i|
            if (! i.state or (i.state != 'DELETED' and i.state != 'ARCHIVED' ))
              thisid = i.id
              break
            end
          } #items
          if thisid 
            # retrieve complete item
            i = op.item(
              vault_id: v.id, 
              id: i.id
            )
            # identify the first PASSWORD purpose field
            i.fields.each { |f|
              if f.purpose == 'PASSWORD' 
                return f.value
              end
            } # fields
          end
        end
      } # vaults
    rescue => error
      raise( "unknown: 1Password lookup ERROR: #{error}" )
      return nil
    end
    # not found in 1Password database
    return nil
  end # function
end # create function
