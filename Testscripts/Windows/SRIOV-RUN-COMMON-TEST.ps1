# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.
param ([string] $TestParams)

function Main {
    param (
        $TestParams
    )
    try {
        $vmRootUser = "root"
        $timeout = 600
        if ($testPlatform -eq "Azure") {
            Write-LogInfo "Setting Azure constants"
            Remove-Item sriov_constants.sh -Force -EA SilentlyContinue
            $TestParams.NIC_COUNT
            foreach ($vmData in $allVMData) {
                if ($vmData.RoleName -imatch "dependency") {
                    $dependencyVmData = $vmData
                    $dependencyVmNICs = ((Get-AzureRmVM -Name $dependencyVmData.RoleName `
                        -ResourceGroupName $dependencyVmData.ResourceGroupName).NetworkProfile).NetworkInterfaces
                    $dependencyVmExtraNICs = $dependencyVmNICs | Where-Object {$_.Primary -eq $False}

                } else {
                    $testVmData = $vmData
                    $testVmNICs = ((Get-AzureRmVM -Name  $testVmData.RoleName `
                        -ResourceGroupName $testVmData.ResourceGroupName).NetworkProfile).NetworkInterfaces
                    $testVmExtraNICs = $testVmNICs | Where-Object {$_.Primary -eq $False}
                }
            }
            $vmPort = $testVmData.SSHPort
            $publicIp = $testVmData.PublicIP

            # Clean unnecessary variables from constants.sh
            Run-LinuxCmd -ip $publicIp -port $vmPort -username $user -password $password -command `
                "sed -i '/VF_/d' constants.sh ; sed -i '/MAX_/d' constants.sh ; sed -i '/NIC_/d' constants.sh ;" `
                -ignoreLinuxExitCode:$true

            Write-LogInfo "Will add VF_IP1=$($testVmData.InternalIP) to constants"
            "VF_IP1=$($testVmData.InternalIP)" | Out-File sriov_constants.sh
            Write-LogInfo "Will add VF_IP2=$($dependencyVmData.InternalIP) to constants"
            "VF_IP2=$($dependencyVmData.InternalIP)" | Out-File sriov_constants.sh -Append

            # Extract IP addresses from both VMs
            $ipIndex = 3
            foreach ($nic in $testVmExtraNICs) {
                try {
                    $index = $testVmExtraNICs.IndexOf($nic)
                } catch {
                    $index = 0
                }
                $testVMNicName = $($testVmExtraNICs[$index].Id).substring($($testVmExtraNICs[$index].Id).LastIndexOf("/")+1)
                $dependencyVMNicName = $($dependencyVmExtraNICs[$index].Id).substring($($dependencyVmExtraNICs[$index].Id).LastIndexOf("/")+1)
                $testIPaddr = (Get-AzureRmNetworkInterface -Name $testVMNicName -ResourceGroupName `
                    $testVmData.ResourceGroupName | Get-AzureRmNetworkInterfaceIpConfig `
                    | Select-Object PrivateIpAddress).PrivateIpAddress
                $dependencyIPaddr = (Get-AzureRmNetworkInterface -Name $dependencyVMNicName -ResourceGroupName `
                    $dependencyVmData.ResourceGroupName | Get-AzureRmNetworkInterfaceIpConfig `
                    | Select-Object PrivateIpAddress).PrivateIpAddress

                Write-LogInfo "Will add VF_IP${ipIndex}=${testIPaddr} to constants"
                "VF_IP${ipIndex}=${testIPaddr}" | Out-File sriov_constants.sh -Append
                $ipIndex++
                Write-LogInfo "Will add VF_IP${ipIndex}=${dependencyIPaddr} to constants"
                "VF_IP${ipIndex}=${dependencyIPaddr}" | Out-File sriov_constants.sh -Append
                $ipIndex++
            }
            if ($ipIndex -gt 3) {
                "NIC_COUNT=$($index+2)" | Out-File sriov_constants.sh -Append
            } else {
                "NIC_COUNT=1" | Out-File sriov_constants.sh -Append
            }

            "SSH_PRIVATE_KEY=id_rsa" | Out-File sriov_constants.sh -Append
            # Send sriov_constants.sh to VM
            Copy-RemoteFiles -upload -uploadTo $publicIp -Port $vmPort `
                -files "sriov_constants.sh" -Username $user -password $password
            if (-not $?) {
                Write-LogErr "Failed to send sriov_constants.sh to VM1!"
                return $False
            }

            if ($TestParams.Set_SSH -eq "yes") {
                Write-LogInfo "Setting SSH keys for both VMs"
                Copy-RemoteFiles -uploadTo $publicIp -port $vmPort -files `
                    ".\Testscripts\Linux\enablePasswordLessRoot.sh,.\Testscripts\Linux\utils.sh,.\Testscripts\Linux\SR-IOV-Utils.sh" `
                    -username $vmRootUser -password $password -upload
                Copy-RemoteFiles -uploadTo $publicIp -port $dependencyVmData.SSHPort -files `
                    ".\Testscripts\Linux\enablePasswordLessRoot.sh,.\Testscripts\Linux\utils.sh,.\Testscripts\Linux\SR-IOV-Utils.sh" `
                    -username $vmRootUser -password $password -upload
                Run-LinuxCmd -ip $publicIp -port $vmPort -username $vmRootUser -password `
                    $password -command "chmod +x ~/*.sh"
                Run-LinuxCmd -ip $publicIp -port $dependencyVmData.SSHPort -username $vmRootUser -password `
                    $password -command "chmod +x ~/*.sh"
                Run-LinuxCmd -ip $publicIp -port $vmPort -username $vmRootUser -password `
                    $password -command "./enablePasswordLessRoot.sh ; cp -rf /root/.ssh /home/$VMUsername"

                # Copy keys from VM1 and setup VM2
                Copy-RemoteFiles -download -downloadFrom $publicIp -port $vmPort -files `
                    "/root/sshFix.tar" -username $vmRootUser -password $password -downloadTo $LogDir
                Copy-RemoteFiles -uploadTo $publicIp -port $dependencyVmData.SSHPort -files "$LogDir\sshFix.tar" `
                    -username $vmRootUser -password $password -upload
                Run-LinuxCmd -ip $publicIp -port $dependencyVmData.SSHPort -username $vmRootUser -password `
                    $password -command "./enablePasswordLessRoot.sh ; cp -rf /root/.ssh /home/$VMUsername"
            }

            # Install dependencies on both VMs
            if ($TestParams.Install_Dependencies -eq "yes") {
                Run-LinuxCmd -username $vmRootUser -password $password -ip $publicIp -port $vmPort `
                    -command "cp /home/$user/sriov_constants.sh . ; . SR-IOV-Utils.sh; InstallDependencies"
                if (-not $?) {
                    Write-LogErr "Failed to install dependencies on $($testVmData.RoleName)"
                    return $False
                }
                Copy-RemoteFiles -upload -uploadTo $publicIp -Port $dependencyVmData.SSHPort `
                    -files "sriov_constants.sh" -Username $user -password $password
                if (-not $?) {
                    Write-LogErr "Failed to send sriov_constants.sh to VM1!"
                    return $False
                }
                Run-LinuxCmd -username $vmRootUser -password $password -ip $publicIp -port $dependencyVmData.SSHPort `
                    -command "cp /home/$user/sriov_constants.sh . ; . SR-IOV-Utils.sh; InstallDependencies"
                if (-not $?) {
                    Write-LogErr "Failed to install dependencies on $($dependencyVmData.RoleName)"
                    return $False
                }
            }

        } elseif ($testPlatform -eq "HyperV") {
            $vmPort = $allVMData.SSHPort
            $publicIp = $allVMData.PublicIP
        }

        if ($CurrentTestData.Timeout) {
            $timeout = $CurrentTestData.Timeout
        }
        $cmdToSend = "echo '${password}' | sudo -S -s eval `"export HOME=``pwd``;bash $($TestParams.Remote_Script) > $($TestParams.Remote_Script)_summary.log 2>&1`""
        Run-LinuxCmd -ip $publicIp -port $vmPort -username $user -password `
            $password -command $cmdToSend -runMaxAllowedTime $timeout

        $testResult = Collect-TestLogs -LogsDestination $LogDir -ScriptName $TestParams.Remote_Script.Split('.')[0] -TestType "sh" `
            -PublicIP $publicIp -SSHPort $vmPort -Username $user -password $password `
            -TestName $currentTestData.testName

        $resultArr += $testResult
        Write-LogInfo "Test Completed."
        Write-LogInfo "Test Result: $testResult"
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $ErrorLine = $_.InvocationInfo.ScriptLineNumber
        Write-LogErr "EXCEPTION : $ErrorMessage at line: $ErrorLine"
    }
    Finally {
        if (!$testResult) {
            $testResult = "ABORTED"
        }
        $resultArr += $testResult
    }

    $currentTestResult.TestResult = Get-FinalResultHeader -resultarr $resultArr
    return $currentTestResult.TestResult
}

Main -TestParams (ConvertFrom-StringData $TestParams.Replace(";","`n"))
