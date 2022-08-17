username = nil
pwage = nil
pwlchg = nil
currentday = (Time.now.to_i / 3600 / 24).to_i
test = {}
uids = {}
# For just the system users
# maxuid = 999
# For ALL users
maxuid = 100000

File.open("/etc/passwd").each do |line|
    uids[$1] = $2.to_i if line =~ /^([^:\s]+):[^:]+:(\d+):/
end

File.open("/etc/shadow").each do |line|
    if line =~ /^([^:\s]+):[^:]+:(\d+):/ && uids[$1] && uids[$1] < maxuid
        username = $1
        pwlchg = $2 
    
        if pwlchg != nil
            if pwlchg.to_i < 99999
                pwage = currentday - pwlchg.to_i
            else
                pwage = 99999
            end
            pwage = 99999 if pwage < 0
        end
        
        if username != nil && pwage != nil
            test['pwage_'+username] = pwage
            username = nil
            pwage = nil
        end
    end
end

test.each { |name,age|
    Facter.add(name) do
        setcode do
            age
        end
    end
}

