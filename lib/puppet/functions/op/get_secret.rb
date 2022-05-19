# Set the password in the 1Password api
#
# Puppet ruby doc: https://www.rubydoc.info/gems/puppet/Hiera/PuppetFunction
# 1P API doc : https://developer.1password.com/docs/connect/connect-api-reference
# SCIM filter doc: https://ldapwiki.com/wiki/SCIM%20Filtering
# op_connect ruby doc: https://github.com/partydrone/connect-sdk-ruby

# require File.expand_path('../../../util/onepassword', __FILE__)
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))
require 'puppet/util/one_password'
require 'op_connect'

Puppet::Functions.create_function(:'op::get_secret') do
  dispatch :get_secret do
    param 'String', :secretname
    optional_param 'Boolean', :exact
    optional_param 'String', :apikey
    optional_param 'String', :endpoint
  end
  def get_secret(secretname,exact=true,apikey=nil,endpoint=nil)
    begin
      Puppet.send_log(:info,"OP: calling get_password for #{secretname}" )

      # Obtail a onepassword object
      op = Puppet::Util::OnePassword.op_connect(apikey,endpoint)

      if op.nil? 
        raise( "OP: Unable to connect to 1Password" )
        return nil
      end

      Puppet.send_log(:info,"OP: searching for #{secretname}" )
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
            if (i.state.nil? or (i.state != 'DELETED' and i.state != 'ARCHIVED' ))
              thisid = i.id
              break
            end
          } #items
          if ! thisid.nil?
            Puppet.send_log(:info,"OP: located item #{secretname}" )
            # retrieve complete item
            i = op.item(
              vault_id: v.id, 
              id: thisid
            )
            if i.nil?
              Puppet.send_log(:warn,"OP: Item disappeared as we were reading it #{secretname}" )
              return nil
            end
            # identify the first PASSWORD purpose field
            i.fields.each { |f|
              if f.purpose == 'PASSWORD' 
                return f.value
              end
            } # fields
            Puppet.send_log(:warning,"OP: unable to find a PASSWORD field in #{secretname}" )
          end
        end
      } # vaults
    rescue => error
      Puppet.send_log(:err, "OP: 1Password lookup failed for #{secretname}: #{error.message}" )
      return nil
    end
    # not found in 1Password database
    Puppet.send_log(:warning,"OP: unable to find #{secretname}" )
    return nil
  end # function
end # create function
