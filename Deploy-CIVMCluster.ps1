<#
    .SYNOPSIS
    Deploys a group of virtual machines in a VApp in a vCloud Director envrionment.

    .DESCRIPTION
    This script deploys 100 virtual machines in a vCloud Director environment.  The following variables
    should be configured in before running:
        $Vapp - the name of the VApp
        $Template - the name of the template
        $GuestUser - the guest user, should be 'root'
        $GuestPassword - the password of the guest operating system
    The script requires a connection to both the CIServer (vCloud Director) and the VIServer (vCenter). The
    vCenter connection allows for guest customization.  In this script, the /etc/network/interfaces file is
    changed to set a static IP address.

    .LINK
    https://github.com/jmcnatt/PowerCLI
#>

Connect-VIServer -Server 'rlesvctr.main.ad.rit.edu'
Connect-CIServer -Server 'rlesvcloud.rit.edu'

$Vapp = Get-CIVapp "QI Cluster"
$Template = Get-CIVMTemplate "QI-NODE"
$GuestUser = 'root'
$GuestPassword = 'qi'

for ($i = 114; $i -le 114; $i++)
{
    $Name = "QI-NODE-{0:000}" -f $i
    Write-Host "[$Name]: Deploying VM"
    $CIVM = New-CIVM -Vapp $Vapp -VMTemplate $Template -Name $Name -ComputerName $Name
    $VM = $CIVM | Get-VM

    # Set the network
    Write-Host "[$Name]: Applying network segment settings"
    $VappNetwork = Get-CIVAppNetwork "QI_Network" -ConnectionType Direct
    $Results = ($CIVM | Get-CINetworkAdapter | Set-CINetworkAdapter -Connected:$true -VAppNetwork $VappNetwork -IPAddressAllocationMode Manual -IPAddress "10.1.1.$i")

    Write-Host "[$Name]: Powering on VM"
    $Results = Start-CIVM -VM $CIVM

    # Wait for VMWare Tools to load
    Write-Host "[$Name]: Waiting for VMWare Tools" 
    $Results = Wait-Tools -VM $VM
    Start-Sleep -Seconds 20
    
    # Get VSphere View from VIServer Connection
    $VSphereView = Get-View -RelatedObject $CIVM.ExtensionData

    # Get VI Object to invoke script
    $VIObject = Get-VIObjectByVIView $VSphereView

    # Change the network manager propoerties
    $Results = Invoke-VMScript -VM $ViObject -ScriptText "sed -i -e 's/10\.1\.1\.250/10\.1\.1\.$i/g' /etc/network/interfaces" -GuestUser $GuestUser -GuestPassword $GuestPassword -ErrorAction SilentlyContinue

    # Reboot the VM
    Write-Host "[$Name]: Restarting VM for changes to take effect"
    $Results = Restart-CIVM -Confirm:$false -VM $CIVM
    
    Write-Host "[$Name]: Waiting for VMWare tools"
    $Results = Wait-Tools -VM $VM
}