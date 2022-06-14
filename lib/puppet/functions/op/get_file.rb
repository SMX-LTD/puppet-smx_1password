# This will fetch the attached file for a Document type secret
# For a non-Document-type, you need to add a filename regex to match


$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))
require 'puppet/util/one_password'
require 'op_connect'

Puppet::Functions.create_function(:'op::get_file') do
  dispatch :get_file do
    param 'String', :secretname
    param 'String', :regex
    optional_param 'Boolean', :exact
    optional_param 'String', :vault
    optional_param 'String', :apikey
    optional_param 'String', :endpoint
  end
  dispatch :get_file_short do
    param 'String', :secretname
    optional_param 'Boolean', :exact
    optional_param 'String', :vault
    optional_param 'String', :apikey
    optional_param 'String', :endpoint
  end
  def get_file(secretname,regex=nil,exact=true,vault=nil,apikey=nil,endpoint=nil)
    begin
      # Obtain a onepassword object
      op = Puppet::Util::OnePassword.op_connect(apikey,endpoint)

      if op.nil? 
        raise( "OP: Unable to connect to 1Password" )
        return nil
      end

      content = nil
      thisid = nil
      vaults = op.vaults
      vaults.each { |v|
        if ! vault.nil?
          next if v.name != vault
        end
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
          items.each { |i|
            if (i.state.nil? or (i.state != 'DELETED' and i.state != 'ARCHIVED' ))
              if ! thisid.nil?
                Puppet.send_log(:warning,"OP: Multiple items match #{secretname}" )
                return nil
              end
              thisid = i.id
            end
          } #items
          if ! thisid.nil?
            # retrieve complete item
            i = op.item(
              vault_id: v.id, 
              id: thisid
            )
            if i.nil?
              Puppet.send_log(:warning,"OP: Item disappeared as we were reading it #{secretname}" )
              return nil
            end

            # Retrieve the attached file here
            fileid = nil
            filename = nil
            files = op.files( vault_id: v.id, item_id: thisid )
            files.each { |f|
              Puppet.send_log(:debug,"OP: Checking file #{f.name} =~ /#{regex}/" )
              if regex.nil?
                if ! fileid.nil?
                  Puppet.send_log(:warning,"OP: Multiple file attachments on #{i.name}, use regex match" )
                  return nil
                end
                fileid = f.id
                filename = f.name
              else
                if f.name.match?(/#{regex}/)
                  if ! fileid.nil?
                    Puppet.send_log(:warning,"OP: Multiple file attachments on #{i.name} match regex /#{regex}/" )
                    return nil
                  end
                  fileid = f.id
                  filename = f.name
                else
                  Puppet.send_log(:debug,"OP: Filename #{f.name} does not match regex /#{regex}/" )
                end
              end
            }

            if ! fileid.nil?
              if ! content.nil?
                Puppet.send_log(:warning,"OP: Multiple possible file items match #{secretname}" )
                return nil
              end
              Puppet.send_log(:info,"OP: Retrieve file #{filename} from secret #{secretname}")
              content = op.file_content(vault_id: v.id, item_id: thisid, 
                id: fileid
              )
              if content.nil?
                Puppet.send_log(:error,"OP: Retrieve file #{filename} from secret #{secretname} failed")
              end
            end

          end
        end
      } # vaults
      # we return here, so that all vaults will have been scanned for a match
      # and we will have alerted if any duplicates
      if ! content.nil?
        return content
      end
    rescue => error
      Puppet.send_log(:err, "OP: 1Password file lookup failed for #{secretname}: #{error.message}" )
      return nil
    end
    # not found in 1Password database
    Puppet.send_log(:warning,"OP: unable to find file secret '#{secretname}' matching /#{regex}/" )
    return nil
  end # function
  def get_file_short(secretname,exact=true,vault=nil,apikey=nil,endpoint=nil)
    get_file(secretname,nil,exact,vault,apikey,endpoint)
  end
end # create function

