#!/bin/bash

# Process each file in validators directory
for file in validators/*; do
    # Skip if not a file
    [ ! -f "$file" ] && continue
    
    # Create temp file
    temp_file="${file}.tmp"
    
    # Process file line by line
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^#.*$ ]] || [[ -z $line ]] && echo "$line" >> "$temp_file" && continue
        
        # Split line into components
        pubkey=$(echo "$line" | cut -d':' -f1)
        wdcreds=$(echo "$line" | cut -d':' -f2)
        
        # Check if originally had 0x prefix
        had_prefix=false
        [[ $wdcreds == 0x* ]] && had_prefix=true
        
        # Remove 0x prefix if exists for comparison
        wdcreds_stripped=${wdcreds#0x}
        
        # Apply wdcreds rules
        if [[ $wdcreds_stripped == 01* ]]; then
            wdcreds_stripped="02${wdcreds_stripped#01}"
            $had_prefix && wdcreds="0x$wdcreds_stripped" || wdcreds=$wdcreds_stripped
        elif [[ $wdcreds_stripped == 00* ]]; then
            wdcreds_stripped="020000000000000000000000deaddeaddeaddeaddeaddeaddeaddeaddeaddead"
            $had_prefix && wdcreds="0x$wdcreds_stripped" || wdcreds=$wdcreds_stripped
        fi
        
        # Output with new value
        echo "$pubkey:$wdcreds:1024000000000" >> "$temp_file"
    done < "$file"
    
    # Replace original with temp file
    mv "$temp_file" "$file"
done 