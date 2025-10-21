# how to deal with the powershell security policy

# list the current policy (no admin)
Get-ExecutionPolicy -List

# bypass current user (no admin)
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

# bypass whole machine (admin required)
Set-ExecutionPolicy Bypass -Scope LocalMachine -Force