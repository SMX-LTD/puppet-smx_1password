# Set the password in the 1Password api
# Create a new secret if necessary

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
    return_type 'Boolean' 
  end

  def set_secret(secretname,newpass,vault=nil,exact=true,apikey=nil,endpoint=nil)
    begin
      # Obtain a onepassword object
      op = Puppet::Util::OnePassword.op_connect(apikey,endpoint)

      if op.nil? 
        raise( "unknown: Unable to connect to 1Password" )
        return false
      end

	  if Puppet[:noop] or Puppet.settings['noop']
	    Puppet.send_log(:warning,"OP: 1Password will NOT be updated as in --noop mode" )
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

      if ! itemid.nil?
        Puppet.send_log(:info,"OP: Identified item to update - [#{vaultid}/#{itemid}] = #{secretname}")
      else
        Puppet.send_log(:info,"OP: Will need to create new item for #{secretname}")
      end

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
        if ! path.nil?
          Puppet.send_log(:err,"OP: Cannot locate a Password field in secret #{secretname}")
          raise( "fail: Cannot locate password field in secret #{secretname}" )
          return false
        end

        attributes = [
          { op: 'replace', path: path, value: newpass }
        ]
        item = op.update_item(
          vault_id: vaultid, 
          id: itemid, 
          body: attributes
        )
        if item.nil?
          Puppet.send_log(:err,"OP: Failed to update #{secretname}")
          raise( "fail: Cannot update secret #{secretname}" )
          return false
        else
          Puppet.send_log(:info,"OP: Updated secret successfully #{secretname}")
        end
      else
        # we need to create a new secret

        # Identify vault to use. This returns an array.
        vault = Puppet::Util::OnePassword.op_default_vault() if vault.nil?
        Puppet.send_log(:info,"OP: Creating new secret in vault #{vault}")
        vaultid = nil
        op.vaults.each { |v|
          Puppet.send_log(:debug,"OP: Checking vault [#{v.id}]='#{v.name}' against #{vault}")
          if v.name == vault
            vaultid = v.id
          end
        }
        if vaultid.nil?
          Puppet.send_log(:err,"OP: Cannot identify vault '#{vault}'")
          raise( "fail: Cannot access 1Password vault '#{vault}'" )
          return false
        else
          Puppet.send_log(:info,"OP: Identified vault [#{vaultid}] = #{vault}")
        end
         
        # Identify username, if we can
        username = secretname.sub( /@.*/, "" ).sub( /^.*:\/*/, "" )

        # Create the item
        attributes = {
          vault: {
            id: vaultid
          },
          title: secretname,
          category: "LOGIN",
          tags: [
            "puppet"
          ],
          fields: [
            {
              value: username,
              purpose: "USERNAME",
              id: "username",
              label: "username",
              type: "STRING"
            },
            {
              id: "password",
              type: "CONCEALED",
              purpose: "PASSWORD",
              label: "password",
              value: newpass,
            },
            {
              id: "notesPlain",
              type: "STRING",
              purpose: "NOTES",
              label: "notesPlain",
              value: "Created by puppet module"
            }
          ],
          files: [
          ]
        }

        Puppet.send_log(:info, "OP: 1Password item being created for #{secretname}" )
        item = op.create_item(vault_id: vaultid, body: attributes)
        if item
          return true
        else
          Puppet.send_log(:warning, "OP: 1Password item create ERROR" )
          raise( "unknown: 1Password item create ERROR" )
          return false
        end
      end

    rescue => error
      raise( "unknown: 1Password update ERROR: #{error.message}" )
      return false
    end
    raise( "unknown: Unable to connect to 1Password - how did I get here?" )
    return false
  end # def function
end # create function
