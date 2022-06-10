# Run some tests
# This class should only be used to test the functionality of the module
# and its configuration on the servers.  Otherwise don't use it!

class op::test(
  Boolean $active = false,
  String $test_exists = 'root',
  String $test_get = 'op3',
  String $test_fuzzy = 'op3a',
  String $test_set = 'op4',
) {
  include op

  if $active {
    notify { "op-test-0": withpath=>false,
      message=>"Running 1Password module tests" 
    }

    $test1 = op::default_vault()
    notify { "op-test-1": withpath=>false,
      message=>"1Password: default vault: ${test1}" 
    }

    $test2 = password_age($test_exists)
    notify { "op-test-2": withpath=>false,
      message=>"1Password: Age of password for ${test_exists} is ${test2}" 
    }

    $test3 = op::check("${test_exists}@${::fqdn}")
    notify { "op-test-3": withpath=>false,
      message=>"1Password record for ${test_exists} exists? ${test3}" 
    }

    $test4 = generate_password(12)
    notify { "op-test-4": withpath=>false,
      message=>"Random password = ${test4}" 
    }

    $test5 = op::get_secret( "${test_get}@${::fqdn}" )
    notify { "op-test-5": withpath=>false,
      message=>"Password for ${test_get}@${::fqdn} = ${test5}" 
    }

    $test5a = op::get_secret( "doesnotexist", true, "bad vault name" )
    notify { "op-test-5a": withpath=>false,
      message=>"Password for nonexistent returns = "${test5a}" (should be nil)" 
    }

    $test6 = op::get_secret( "${test_fuzzy}", false )
    notify { "op-test-6": withpath=>false,
      message=>"Password for ${test_fuzzy} (not exact match) = ${test6}" 
    }

    $test6a = op::get_secret( "o", false )
    notify { "op-test-6a": withpath=>false,
      message=>"Password search that matches multiple returns "${test6a}" (should be nil)" 
    }

    $testpass = generate_password(12)
    $test7 = op::set_secret( "${test_set}@${::fqdn}", $testpass )
    notify { "op-test-7": withpath=>false,
      message=>"Set 1password record for ${test_set}@${::fqdn} to '${testpass}' : '${test7}' (should be nil)" 
    }

    $test7a = op::set_secret( "doesnotexist", $testpass, true, "bad vault name" )
    notify { "op-test-7a": withpath=>false,
      message=>"Set 1password record for nonexistent vault : '${test7a}' (should be error)" 
    }
    $test7b = op::set_secret( "o", $testpass, false )
    notify { "op-test-7b": withpath=>false,
      message=>"Set 1password record for multiple matches : '${test7b}' (should be error)" 
    }

    $test8 = op::get_file( "op:testdocument1" )
    notify { "op-test-8": withpath=>false,
      message=>"Get 1password attachment for Document type : '${test8}'" 
    }

    $test9 = op::get_file( "op:testdocument2", true )
    notify { "op-test-9": withpath=>false,
      message=>"Get 1password attachment for Note type : '${test9}'" 
    }

    $test10 = op::get_file( "op:testdocument3", "testdata", true )
    notify { "op-test-10": withpath=>false,
      message=>"Get 1password attachment with regex selector : '${test10}'" 
    }

    $test11 = op::get_file( "op:testdocument", false )
    notify { "op-test-11": withpath=>false,
      message=>"Get 1password attachment with multiple matches: '${test11}' (should be nil)" 
    }

  } else {
    notify { "op-test-1": withpath=>false,
      message=>"Not testing 1Password module because tests not active."
    }
  }
}
