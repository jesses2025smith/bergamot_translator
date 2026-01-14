function(initialize_all_submodules)
    execute_process(
        COMMAND git submodule update --init --recursive
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        RESULT_VARIABLE GIT_SUBMODULE_RESULT
        OUTPUT_QUIET
        ERROR_QUIET
    )
    
    if(NOT GIT_SUBMODULE_RESULT EQUAL "0")
        message(WARNING "Git submodule update failed with code ${GIT_SUBMODULE_RESULT}")
    endif()
endfunction()
