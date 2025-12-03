#!/bin/bash

parse_user_text_file() {
    local file_path="$1"
    
    validate_file "$file_path" || return 1
    
    declare -g -a BATCH_USERS=()
    local line_num=0
    
    echo "Parsing text file: $file_path"
    echo ""
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        
        [ -z "$line" ] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        line=$(echo "$line" | xargs)
        
        if [[ "$line" =~ , ]]; then
            IFS=',' read -r username comment shell sudo pgroup sgroups pexpiry pwarn aexpiry random <<< "$line"
            
            username=$(echo "$username" | xargs)
            comment=$(echo "$comment" | xargs)
            shell=$(echo "$shell" | xargs)
            sudo=$(echo "$sudo" | xargs)
            pgroup=$(echo "$pgroup" | xargs)
            sgroups=$(echo "$sgroups" | xargs)
            pexpiry=$(echo "$pexpiry" | xargs)
            pwarn=$(echo "$pwarn" | xargs)
            aexpiry=$(echo "$aexpiry" | xargs)
            random=$(echo "$random" | xargs)
            
            if [ -z "$username" ]; then
                echo "WARNING: Line $line_num - Empty username, skipping"
                continue
            fi
            
            if [ -z "$comment" ]; then
                echo "WARNING: Line $line_num - Empty comment for user '$username', skipping"
                continue
            fi
            
            [ -z "$random" ] && random="no"
            
       else
            echo "WARNING: Line $line_num - Invalid format, skipping"
            echo "         Expected: username,comment[,optional fields]"
            echo "         Example: alice,Alice Smith:Engineering"
            echo "         Example: bob,Bob Jones:IT,developer,allow,devs,docker,90,7,365,yes"
            continue
        fi
        
        BATCH_USERS+=("$username|$comment|$shell|$sudo|$pgroup|$sgroups|$pexpiry|$pwarn|$aexpiry|$random")
        
    done < "$file_path"
    
    local count=${#BATCH_USERS[@]}
    echo "Parsed $count users from text file"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "ERROR: No valid users found in file"
        return 1
    fi
    
    return 0
}