##############################################################################################
# XmlProcessing.psm1
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.
# Operations :
#
<#
.SYNOPSIS
	PS modules for LISAv2 test automation.
	This module defines a set of functions to process XML file for LISAv2.

.PARAMETER
	<Parameters>

.INPUTS


.NOTES
	Creation Date:
	Purpose/Change:

.EXAMPLE


#>
###############################################################################################

Function Import-TestCases($WorkingDirectory, $TestConfigurationXmlFile) {
	# Consolidate all test cases into a unified test xml file
	$TestXMLs = Get-ChildItem -Path "$WorkingDirectory\XML\TestCases\*.xml"
	$SetupTypeXMLs = Get-ChildItem -Path "$WorkingDirectory\XML\VMConfigurations\*.xml"
	$AllLisaTests = @()

	$AllLisaTests = Collect-TestCases -TestXMLs $TestXMLs
	if( !$AllLisaTests.innerXML ) {
		Throw "Not able to collect any test cases from XML files"
	}
	Write-LogInfo "$(@($AllLisaTests).Length) Test Cases have been collected"

	$SetupTypes = $AllLisaTests.SetupType | Sort-Object | Get-Unique

	$tab = Create-ArrayOfTabs
	$TestCycle = "TC-$TestID"
	$GlobalConfiguration = [xml](Get-Content .\XML\GlobalConfigurations.xml)
	<##########################################################################
	We're following the Indentation of the XML file to make XML creation easier.
	##########################################################################>
	$xmlContent =  ("$($tab[0])" + '<?xml version="1.0" encoding="utf-8"?>')
	$xmlContent += ("$($tab[0])" + "<config>`n")
	$xmlContent += ("$($tab[0])" + "<CurrentTestPlatform>$TestPlatform</CurrentTestPlatform>`n")
	if ($TestPlatform -eq "Azure") {
		$xmlContent += ("$($tab[1])" + "<Azure>`n")
			# Add Subscription Details
			$xmlContent += ("$($tab[2])" + "<General>`n")

			foreach ( $line in $GlobalConfiguration.Global.$TestPlatform.Subscription.InnerXml.Replace("><",">`n<").Split("`n")) {
				$xmlContent += ("$($tab[3])" + "$line`n")
			}
			$xmlContent += ("$($tab[2])" + "<Location>$TestLocation</Location>`n")
			$xmlContent += ("$($tab[2])" + "</General>`n")

			# Database details
			$xmlContent += ("$($tab[2])" + "<database>`n")
			foreach ( $line in $GlobalConfiguration.Global.$TestPlatform.ResultsDatabase.InnerXml.Replace("><",">`n<").Split("`n")) {
				$xmlContent += ("$($tab[3])" + "$line`n")
			}
			$xmlContent += ("$($tab[2])" + "</database>`n")

			# Deployment details
			$xmlContent += ("$($tab[2])" + "<Deployment>`n")
				$xmlContent += ("$($tab[3])" + "<Data>`n")
					$xmlContent += ("$($tab[4])" + "<Distro>`n")
						$xmlContent += ("$($tab[5])" + "<Name>$RGIdentifier</Name>`n")
						if ($null -ne $ARMImageName) {
							$ARMImage = $ARMImageName.Trim().Split(" ")
							$xmlContent += ("$($tab[5])" + "<ARMImage>`n")
								$xmlContent += ("$($tab[6])" + "<Publisher>" + "$($ARMImage[0])" + "</Publisher>`n")
								$xmlContent += ("$($tab[6])" + "<Offer>" + "$($ARMImage[1])" + "</Offer>`n")
								$xmlContent += ("$($tab[6])" + "<Sku>" + "$($ARMImage[2])" + "</Sku>`n")
								$xmlContent += ("$($tab[6])" + "<Version>" + "$($ARMImage[3])" + "</Version>`n")
							$xmlContent += ("$($tab[5])" + "</ARMImage>`n")
						}
						$xmlContent += ("$($tab[5])" + "<OsVHD><![CDATA[" + "$OsVHD" + "]]></OsVHD>`n")
						$xmlContent += ("$($tab[5])" + "<VMGeneration>" + "$VMGeneration" + "</VMGeneration>`n")
					$xmlContent += ("$($tab[4])" + "</Distro>`n")
					$xmlContent += ("$($tab[4])" + "<UserName>" + "$($GlobalConfiguration.Global.$TestPlatform.TestCredentials.LinuxUsername)" + "</UserName>`n")
					$xmlContent += ("$($tab[4])" + "<Password>" + "$($GlobalConfiguration.Global.$TestPlatform.TestCredentials.LinuxPassword)" + "</Password>`n")
				$xmlContent += ("$($tab[3])" + "</Data>`n")

				foreach ( $file in $SetupTypeXMLs.FullName)	{
					foreach ( $SetupType in $SetupTypes ) {
						$CurrentSetupType = ([xml]( Get-Content -Path $file)).TestSetup
						if ($null -ne $CurrentSetupType.$SetupType) {
							$SetupTypeElement = $CurrentSetupType.$SetupType
							$xmlContent += ("$($tab[3])" + "<$SetupType>`n")
								#$xmlContent += ("$($tab[4])" + "$($SetupTypeElement.InnerXml)`n")
								foreach ( $line in $SetupTypeElement.InnerXml.Replace("><",">`n<").Split("`n")) {
									$xmlContent += ("$($tab[4])" + "$line`n")
								}
							$xmlContent += ("$($tab[3])" + "</$SetupType>`n")
						}
					}
				}
			$xmlContent += ("$($tab[2])" + "</Deployment>`n")
		$xmlContent += ("$($tab[1])" + "</Azure>`n")
	} elseif ($TestPlatform -eq "Hyperv") {
		$xmlContent += ("$($tab[1])" + "<Hyperv>`n")
			# Add Hosts Details
			$xmlContent += ("$($tab[2])" + "<Hosts>`n")
				$xmlContent += ("$($tab[3])" + "<Host>`n")
				foreach ( $line in $GlobalConfiguration.Global.HyperV.Hosts.FirstChild.InnerXml.Replace("><",">`n<").Split("`n")) {
					$xmlContent += ("$($tab[4])" + "$line`n")
				}
				$xmlContent += ("$($tab[3])" + "</Host>`n")

				if($TestLocation -and $TestLocation.split(',').Length -eq 2){
					$xmlContent += ("$($tab[3])" + "<Host>`n")
					foreach ( $line in $GlobalConfiguration.Global.HyperV.Hosts.LastChild.InnerXml.Replace("><",">`n<").Split("`n")) {
						$xmlContent += ("$($tab[4])" + "$line`n")
					}
					$xmlContent += ("$($tab[3])" + "</Host>`n")
				}
			$xmlContent += ("$($tab[2])" + "</Hosts>`n")

			# Database details
			$xmlContent += ("$($tab[2])" + "<database>`n")
				foreach ( $line in $GlobalConfiguration.Global.HyperV.ResultsDatabase.InnerXml.Replace("><",">`n<").Split("`n")) {
					$xmlContent += ("$($tab[3])" + "$line`n")
				}
			$xmlContent += ("$($tab[2])" + "</database>`n")

			# Deployment details
			$xmlContent += ("$($tab[2])" + "<Deployment>`n")
				$xmlContent += ("$($tab[3])" + "<Data>`n")
					$xmlContent += ("$($tab[4])" + "<Distro>`n")
						$xmlContent += ("$($tab[5])" + "<Name>$RGIdentifier</Name>`n")
						$xmlContent += ("$($tab[5])" + "<OsVHD><![CDATA[" + "$OsVHD" + "]]></OsVHD>`n")
					$xmlContent += ("$($tab[4])" + "</Distro>`n")
					$xmlContent += ("$($tab[4])" + "<UserName>" + "$($GlobalConfiguration.Global.$TestPlatform.TestCredentials.LinuxUsername)" + "</UserName>`n")
					$xmlContent += ("$($tab[4])" + "<Password>" + "$($GlobalConfiguration.Global.$TestPlatform.TestCredentials.LinuxPassword)" + "</Password>`n")
				$xmlContent += ("$($tab[3])" + "</Data>`n")

				foreach ( $file in $SetupTypeXMLs.FullName)	{
					foreach ( $SetupType in $SetupTypes ) {
						$CurrentSetupType = ([xml]( Get-Content -Path $file)).TestSetup
						if ($null -ne $CurrentSetupType.$SetupType) {
							$SetupTypeElement = $CurrentSetupType.$SetupType
							$xmlContent += ("$($tab[3])" + "<$SetupType>`n")
								#$xmlContent += ("$($tab[4])" + "$($SetupTypeElement.InnerXml)`n")
								foreach ( $line in $SetupTypeElement.InnerXml.Replace("><",">`n<").Split("`n")) {
									$xmlContent += ("$($tab[4])" + "$line`n")
								}

							$xmlContent += ("$($tab[3])" + "</$SetupType>`n")
						}
					}
				}
			$xmlContent += ("$($tab[2])" + "</Deployment>`n")
		$xmlContent += ("$($tab[1])" + "</Hyperv>`n")
	}
		# TestDefinition
		$xmlContent += ("$($tab[1])" + "<testsDefinition>`n")
		foreach ( $currentTest in $AllLisaTests) {
			if ($currentTest.Platform.Contains($TestPlatform)) {
				$xmlContent += ("$($tab[2])" + "<test>`n")
				foreach ( $line in $currentTest.InnerXml.Replace("><",">`n<").Split("`n")) {
					$xmlContent += ("$($tab[3])" + "$line`n")
				}
				$xmlContent += ("$($tab[2])" + "</test>`n")
			} else {
				Write-LogErr "*** UNSUPPORTED TEST *** : $currentTest. Skipped."
			}
		}
		$xmlContent += ("$($tab[1])" + "</testsDefinition>`n")

		# TestCycle
		$xmlContent += ("$($tab[1])" + "<testCycles>`n")
			$xmlContent += ("$($tab[2])" + "<Cycle>`n")
				$xmlContent += ("$($tab[3])" + "<cycleName>$TestCycle</cycleName>`n")
				foreach ( $currentTest in $AllLisaTests) {
					$line = $currentTest.TestName
					$xmlContent += ("$($tab[3])" + "<test>`n")
						$xmlContent += ("$($tab[4])" + "<Name>$line</Name>`n")
					$xmlContent += ("$($tab[3])" + "</test>`n")
				}
			$xmlContent += ("$($tab[2])" + "</Cycle>`n")
		$xmlContent += ("$($tab[1])" + "</testCycles>`n")
	$xmlContent += ("$($tab[0])" + "</config>`n")
  	Set-Content -Value $xmlContent -Path $TestConfigurationXmlFile -Force
  	Write-LogInfo "Test cases are scanned and imported to $TestConfigurationXmlFile"
}

Function Validate-XmlFiles( [string]$ParentFolder )
{
	Write-LogInfo "Validating XML Files from $ParentFolder folder recursively..."
	$allXmls = Get-ChildItem "$ParentFolder\*.xml" -Recurse
	$xmlErrorFiles = @()
	foreach ($file in $allXmls)
	{
		try
		{
			$null = [xml](Get-Content $file.FullName)
		}
		catch
		{
			Write-LogErr -text "$($file.FullName) validation failed."
			$xmlErrorFiles += $file.FullName
		}
	}
	if ( $xmlErrorFiles.Count -gt 0 )
	{
		$xmlErrorFiles | ForEach-Object -Process {Write-LogInfo $_}
		Throw "Please fix above ($($xmlErrorFiles.Count)) XML files."
	}
}

Function Import-TestParameters($ParametersFile)
{
	Write-LogInfo "Import test parameters from provided XML file $ParametersFile ..."
	try {
		$LISAv2Parameters = [xml](Get-Content -Path $ParametersFile)
		$ParameterNames = ($LISAv2Parameters.TestParameters.ChildNodes | Where-Object {$_.NodeType -eq "Element"}).Name
		foreach ($ParameterName in $ParameterNames) {
			if ($LISAv2Parameters.TestParameters.$ParameterName) {
				if ($LISAv2Parameters.TestParameters.$ParameterName -eq "true") {
					Write-LogInfo ">>> Setting boolean parameter: $ParameterName = true"
					Set-Variable -Name $ParameterName -Value $true -Scope Global -Force
				}
				else {
					Write-LogInfo ">>> Setting parameter: $ParameterName = $($LISAv2Parameters.TestParameters.$ParameterName)"
					Set-Variable -Name $ParameterName -Value $LISAv2Parameters.TestParameters.$ParameterName -Scope Global -Force
				}
			}
		}
	} catch {
		$line = $_.InvocationInfo.ScriptLineNumber
		$script_name = ($_.InvocationInfo.ScriptName).Replace($PWD,".")
		$ErrorMessage =  $_.Exception.Message

		Write-LogErr "EXCEPTION : $ErrorMessage"
		Write-LogErr "Source : Line $line in script $script_name."
	}
}
