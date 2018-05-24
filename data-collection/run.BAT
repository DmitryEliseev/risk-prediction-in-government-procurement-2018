:: Создание всех функций
set /p db_name="Input database name: "
set /p server_name="Input server name: "
set /p username="Input user name: "
set /p pwd="Input password: "

cd utils
for %%G in (*.sql) do sqlcmd /S %server_name% /d %db_name% -U %username% -P %pwd% -i"%%G"

cd ../org
for %%G in (*.sql) do sqlcmd /S %server_name% /d %db_name% -U %username% -P %pwd% -i"%%G"

cd ../sup
for %%G in (*.sql) do sqlcmd /S %server_name% /d %db_name% -U %username% -P %pwd% -i"%%G"

cd ../ter
for %%G in (*.sql) do sqlcmd /S %server_name% /d %db_name% -U %username% -P %pwd% -i"%%G"

cd ..
sqlcmd /S %server_name% /d %db_name% -U %username% -P %pwd% -i"pred_variable.sql"
pause