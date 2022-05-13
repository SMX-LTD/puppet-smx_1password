# Set the password in the 1Password api
# Create a new secret if necessary

# require File.expand_path('../../../util/onepassword', __FILE__)
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet/util/onepassword'
require 'op_connect'

Puppet::Functions.create_function(:'op::set_secret') do
  dispatch :set_secret do
    param 'String', :secretname
    param 'String', :newpass
    optional_param 'String', :vault
    optional_param 'Boolean', :exact
    optional_param 'String', :apikey
    optional_param 'String', :endpoint
    return_type 'Boolean' 
  end
  def set_secret(secretname,newpass,vault,exact=true,apikey=nil,endpoint=nil)
    begin
      # Obtail a onepassword object
      op = Puppet::Util::OnePassword.op_connect(apikey,endpoint)

      if op.nil? {
        raise( "unknown: Unable to connect to 1Password" )
        return false
      }

	  if Puppet[:noop] or Puppet.settings['noop']
	    warn( "1Password will NOT be updated as in --noop mode" )
        return true
	  end

      # Find the secret, if it exists
      vaultid = nil
      itemid = nil
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
              itemid = i.id
              vaultid = v.id
              break
            end
          } #items
        end
        break if itemid
      } # vaults

      if itemid
        # update the item
        # Identify the field to update
        # retrieve complete item
        item = op.item(
          vault_id: vaultid,
          id: itemid
        )
        # identify the first PASSWORD purpose field
        path = nil
        item.fields.each { |f|
          if f.purpose == 'PASSWORD'
            path = '/'
            break
          end
        } # fields

        attributes = [
          { op: "replace", path: "", value: newpass }
        ]
        item = op.update_item(
          vault_id: vaultid, 
          id: itemid, 
          body: attributes
        )
      else
        # Create the item
attributes = {
  vault: {
    id: vault.id
  },
  title: "Secrets Automation Item",
  category: "LOGIN",
  fields: [
    {
      value: "wendy",
      purpose: "USERNAME"
    },
    {
      purpose: "PASSWORD",
      generate: true,
      recipe: {
        length: 55,
        characterSets: ["LETTERS", "DIGITS"]
      }
    }
  ]
  # …
}

        item = op.create_item(vault_id: vault, body: attributes)

      end

    rescue
      raise( "unknown: 1Password update ERROR: #{$!}" )
      return nil
    end
    raise( "unknown: Unable to connect to 1Password - how did I get here?" )
    return nil
  end # function
end # create function
