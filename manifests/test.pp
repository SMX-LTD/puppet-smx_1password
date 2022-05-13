# Run some tests

class smx_1password::test(
  Boolean $active = false,
  String $test_exists = 'root',
  String $test_get = 'op3',
  String $test_set = 'op4',
) {
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

    $test3 = op::check("${test_exists}\@${fqdn}")
    notify { "op-test-3": withpath=>false,
      message=>"1Password record for ${test_exists} exists? ${test3}" 
    }

    $test4 = generate_password(10)
    notify { "op-test-4": withpath=>false,
      message=>"Random password = ${test4}" 
    }
   
    $test5 = op::get_secret( $test_get )
    notify { "op-test-5": withpath=>false,
      message=>"Password for ${test_get} = ${test5}" 
    }

    $test6 = op::get_secret( $test_get, false )
    notify { "op-test-6": withpath=>false,
      message=>"Password for ${test_get} (not exact match) = ${test6}" 
    }

    $test7 = op::set_secret( $test_set, 'newpass' )
    notify { "op-test-7": withpath=>false,
      message=>"Set 1password record for ${test_set}: ${test7}" 
    }


  } else {
    notify { "op-test-1": withpath=>false,
      message=>"Not testing 1Password module because tests not active."
    }
  }
}
