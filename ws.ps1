Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online

$Domain = $env:REALM.split('.')[0]
$Username = "$Domain\Administrator"
$SecureString = ConvertTo-SecureString -AsPlainText $env:PASSWORD -Force
$SecureCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username,$SecureString 

$Stoploop = $false
do {
  try {
    Add-Computer -DomainName $env:REALM -Credential $SecureCreds
    Write-Host "Domain joined"
    $Stoploop = $true
  }
  catch {
    Write-Host "Waiting DC to start..."
    Start-Sleep -Seconds 60
  }
}
While ($Stoploop -eq $false)

$net = New-Object -ComObject WScript.Network
$net.MapNetworkDrive("z:", "\\dc1\dfs", $true, $Username, $env:PASSWORD)

Restart-Computer
