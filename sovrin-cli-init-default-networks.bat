@echo off
setlocal enableextensions enabledelayedexpansion

echo pool list > tmp.batch
indy-cli.exe tmp.batch > tmp.out
findstr /C:" sovrin " /C:" sovrin-sandbox " tmp.out > NUL

if NOT ERRORLEVEL 1 (
    echo "Default configuration 'sovrin' and/or 'sovrin-sandbox' already exists."

    SET /P R="Would you like to replace it [y/N]?: "

    if "!R!" == "y" (
        echo "Removing old configurations"

        echo -pool delete sovrin > tmp.batch
        echo -pool delete sovrin-sandbox >> tmp.batch
        indy-cli.exe tmp.batch
    ) else (
        echo "================================================================================"
        echo "Previous configurations are not changed, nothing to do."
        echo "================================================================================"
        goto cleanup
    )
)

echo pool create sovrin gen_txn_file=pool_transactions_live_genesis > tmp.batch
echo pool create sovrin-sandbox gen_txn_file=pool_transactions_sandbox_genesis >> tmp.batch
indy-cli.exe tmp.batch

echo "================================================================================"
echo "To start use CLI run 'indy-cli.exe'."
echo "Now you can see 'sovrin' and 'sovrin-sandbox' pool configuration in 'pool list'."
echo "================================================================================"

:cleanup
    del tmp.batch
    del tmp.out
