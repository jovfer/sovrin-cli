#!/bin/bash -e

already_exists=''
echo "pool list" | indy-cli | grep -E " (sovrin)(-sandbox)? " 1> /dev/null || already_exists='yes' && true ;

if [[ -z ${already_exists} ]]; then
    echo "Default configuration 'sovrin' and/or 'sovrin-sandbox' already exists."

    R=''
    read -p "Would you like to replace it [y|N]" R
    echo "$R"

    if [[ "${R}" = "y" ]]; then
        echo "Removing old configurations"

        echo "\
-pool delete sovrin
-pool delete sovrin-sandbox" \
            | indy-cli
    else
        echo "================================================================================"
        echo "Previous configurations are not changed, nothing to do."
        echo "================================================================================"
        exit
    fi
fi

echo "\
pool create sovrin gen_txn_file=/etc/sovrin/pool_transactions_live_genesis
pool create sovrin-sandbox gen_txn_file=/etc/sovrin/pool_transactions_sandbox_genesis" | indy-cli

echo "================================================================================"
echo "To start use CLI run 'indy-cli' binary."
echo "Now you can see 'sovrin' and 'sovrin-sandbox' pool configuration in 'pool list'."
echo "================================================================================"
