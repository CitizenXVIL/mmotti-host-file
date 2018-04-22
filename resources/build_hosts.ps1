Clear-Host

# User defined variables

$host_files   = 'http://someonewhocares.org/hosts/hosts',`
                'https://goo.gl/bGNWyV' # <-- My manual entries
$wildcards    = 'https://goo.gl/qwP1iL' # <-- My wildcards
$regex_file   = 'https://goo.gl/eSj5Uv' # <-- My regex replacement criteria

# Get the script's parent directory
$parent_dir   = (Get-Item $PSScriptRoot).Parent.FullName
# Check whether we are running from the git repo
$isGitRepo    = Get-ChildItem -Attributes "Hidden" -Filter ".git" $parent_dir

# Conditional output location
if($isGitRepo)
{
    $out_file     = "$parent_dir\wildcard_standard_hosts.txt"
}
else
{
    $out_file     = "$PSScriptRoot\wildcard_standard_hosts.txt"
}

# Empty hosts array

$hosts = @()

# For each host file

foreach($host_list in $host_files)
{
    Write-Output "--> Fetching $host_list"

    # Add hosts to the array

    $hosts += (Invoke-WebRequest -Uri $host_list -UseBasicParsing).Content -split '\n'
}

# Fetch my host file separately

Write-Output "--> Fetching $wildcards"

$mmhosts      = (Invoke-WebRequest -Uri $wildcards -UseBasicParsing).Content -split '\n'

Write-Output '--> Parsing host files'

# Remove local end-zone

$hosts        = $hosts -replace '127.0.0.1'`
                       -replace '0.0.0.0'
# Remove whitespace

$hosts        = $hosts -replace '\s'

# Remove user comments

$hosts        = $hosts -replace '(#.*)|((\s)+#.*)'

# Remove www prefix

$hosts        = $hosts -replace '^(www)([0-9]{0,3})?(\.)'

# Only select 'valid' URLs

$hosts        = $hosts | Select-String '(?sim)(?=^.{4,253}$)(^((?!-)[a-z0-9-]{1,63}(?<!-)\.)+[a-z]{2,63}$)|^([\*])([A-Z0-9-_.]+)$|^([A-Z0-9-_.]+)([\*])$|^([\*])([A-Z0-9-_.]+)([\*])$' -AllMatches

# Remove empty lines
`
$hosts        = $hosts | Select-String '(^\s*$)' -NotMatch

# Output host count prior to removals

Write-Output "--> Hosts Detected: $($hosts.count)"

# Extra removals
# Get regex filters

Write-Output "--> Running regex removals (this may take a minute)"

$regex_str    = (Invoke-WebRequest -Uri $regex_file -UseBasicParsing).Content -split '\n'

# Loop through each regex and select non-matching items

foreach($regex in $regex_str)
{   
    $hosts    = $hosts | Select-String $regex -NotMatch
}

# Add custom hosts to the main hosts

$hosts        = $hosts += $mmhosts

# Count total hosts

Write-Output "--> Hosts Detected: $($hosts.count)"


Write-Output "--> Removing duplicate hosts (this may take a minute)"

<#############################################
       Fastest way to remove matchinfo
#############################################>

$hosts        = $hosts -replace ''

##############################################

# Remove duplicates and force lower case

$hosts        = ($hosts).toLower() | Sort-Object -Unique

# Count unique hosts

Write-Output "--> Hosts added: $($hosts.count)"

# Output host file

Write-Output '--> Saving host file'

$hosts     = $hosts -join "`n"

[System.IO.File]::WriteAllText($out_file,$hosts)

Write-Output "--> Host file saved to: $out_file"