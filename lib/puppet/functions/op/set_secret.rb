# Set the password in the 1Password api
# Create a new secret if necessary
# Return nil for success, or error string for fail

# require File.expand_path('../../../util/onepassword', __FILE__)
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))
require 'puppet/util/one_password'
require 'op_connect'

Puppet::Functions.create_function(:'op::set_secret') do
  dispatch :set_secret do
    param 'String', :secretname
    param 'String', :newpass
    optional_param 'String', :vault
    optional_param 'Boolean', :exact
    optional_param 'String', :apikey
    optional_param 'String', :endpoint
  end

  def set_secret(secretname,newpass,vault=nil,exact=true,apikey=nil,endpoint=nil)
    begin
      # Obtain a onepassword object
      op = Puppet::Util::OnePassword.op_connect(apikey,endpoint)

      if op.nil? 
        raise( "OP: Unable to connect to 1Password" )
        return "Unable to connect to 1Password"
      end

	  if Puppet[:noop] or Puppet.settings['noop']
	    Puppet.send_log(:warning,"OP: 1Password will NOT be updated as in --noop mode" )
        return nil
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
            end
          } #items
        end
        break if itemid
      } # vaults

      if ! itemid.nil?
        # update the item
        # retrieve complete item
        item = op.item(
          vault_id: vaultid,
          id: itemid
        )
        # Identify the field to update
        # identify the first PASSWORD purpose field
        path = nil
        item.fields.each { |f|
          if f.purpose == 'PASSWORD'
            path = '/fields/' + f.id + '/value'
            break
          end
        } # fields
        if path.nil?
          Puppet.send_log(:err,"OP: Cannot locate a Password field in secret #{secretname}")
          return "Cannot locate password field in secret #{secretname}"
        end

        begin
          # NOTE - this breaks v0.1.3 of the SDK due to a bug.
          # The update_item function need to not set the content-type header
          # and must pass the body attributes as an array
          item = op.update_item(
            vault_id: vaultid, 
            id: itemid, 
            op: 'replace', path: path, value: newpass
          )
        rescue => error
          Puppet.send_log(:err,"OP: Failed to update #{secretname} - #{error.message}")
          return "Failed to update #{secretname} - #{error.message}"
        end
        if item.nil?
          Puppet.send_log(:err,"OP: Failed to update #{secretname}")
          return "Cannot update secret #{secretname}"
        else
          Puppet.send_log(:info,"OP: Updated secret successfully #{secretname}")
          return nil
        end
      else
        # we need to create a new secret

        # Identify vault to use. This returns an array.
        vault = Puppet::Util::OnePassword.op_default_vault() if vault.nil?
        vaultid = nil
        op.vaults.each { |v|
          if v.name == vault
            vaultid = v.id
          end
        }
        if vaultid.nil?
          Puppet.send_log(:err,"OP: Cannot identify vault '#{vault}'")
          raise( "fail: Cannot access 1Password vault '#{vault}'" )
          return "Cannot access 1Password vault '#{vault}'"
        end
         
        # Identify username, if we can
        username = secretname.sub( /@.*/, "" ).sub( /^.*:\/*/, "" )

        # Create the item
        begin
          item = op.create_item(vault_id: vaultid, 
            category: 'LOGIN', tags: [ 'puppet' ],
            title: secretname,
            fields: [
              {
                id: "username",
                purpose: "USERNAME",
                value: username,
              },
              {
                id: "password",
                purpose: "PASSWORD",
                value: newpass,
              },
              {
                id: "notesPlain",
                purpose: "NOTES",
                value: "Created by puppet module"
              }
            ]
          )
        rescue => error
          Puppet.send_log(:err, "OP: Failed to create item #{secretname} - #{error.message}" )
          return "Failed to create item #{secretname} - #{error.message}"
        end
        if item.nil?
          Puppet.send_log(:err, "OP: Failed to create item #{secretname}" )
          raise( "unknown: 1Password item create ERROR for #{secretname}" )
          return "1Password item create ERROR for #{secretname}"
        else
          Puppet.send_log(:info, "OP: Created new secret #{secretname}" )
          return nil
        end
      end

    rescue => error
      raise( "unknown: 1Password update ERROR: #{error.message}" )
      return "1Password update ERROR: #{error.message}"
    end
    raise( "unknown: Unable to connect to 1Password - how did I get here?" )
    return "Unable to connect to 1Password"
  end # def function
end # create function
