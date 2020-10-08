$Domain = $env:REALM.split('.')[0]
$Username = "$Domain\Administrator"
$SecureString = ConvertTo-SecureString -AsPlainText $env:PASSWORD -Force
$SecureCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username,$SecureString 

Add-Computer -DomainName $env:REALM -Credential $SecureCreds

$net = New-Object -ComObject WScript.Network
$net.MapNetworkDrive("z:", "\\dc1\dfs", $true, $Username, $env:PASSWORD)

Restart-Computer -Force