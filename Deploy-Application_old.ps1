<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification="Suppresses AppVeyor errors on informational variables below")]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch { Write-Error "Failed to set the execution policy to Bypass for this process." }

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Oracle'
	[string]$appName = 'SQL Developer'
	[string]$appVersion = '19.2.0.206.2117'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '08/01/2019'
	[string]$appScriptAuthor = 'Jordan Hamilton'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.6.9'
	[string]$deployAppScriptDate = '02/12/2017'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close applications if required, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'sqldeveloper' -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>

		## Remove previous versions of SQL Developer
		If (Test-Path -Path "$envProgramFiles\Oracle SQL Developer" -PathType 'Container') {
			Remove-File -Path "$envProgramFiles\Oracle SQL Developer\*" -Recurse
		}

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
		New-Folder -Path "$envProgramFiles\Oracle SQL Developer"
		Copy-File -Path "$dirFiles\*" -Destination "$envProgramFiles\Oracle SQL Developer" -Recurse


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		## Add a shortcut to the Start Menu
		Copy-File -Path "$dirSupportFiles\Oracle SQL Developer.lnk" -Destination "$envCommonStartMenuPrograms"

		<# Old method of setting JDK if necessary:
		# Set the JDK path to JDK 64-Bit Update 162 using product.conf
		Get-ChildItem -Path "${envSystemDrive}\Users" -Force | Where-Object { $_.PSIsContainer } | ForEach-Object {
			$appDataRoamingFolder = $_.FullName + "\AppData\Roaming"
			If (Test-Path -Path $appDataRoamingFolder -PathType 'Container') {
				Write-Log -Message "Copying JDK path configuration for $_" -Severity 1 -Source $deployAppScriptFriendlyName
				New-Folder -Path "${appDataRoamingFolder}\sqldeveloper\17.4.0" -ContinueOnError $True
				Copy-File -Path "${dirSupportFiles}\product.conf" -Destination "${appDataRoamingFolder}\sqldeveloper\17.4.0"
			} Else {
				Write-Log -Message "A roaming application data folder was not found for $_" -Severity 2 -Source $deployAppScriptFriendlyName
				}
		}
		#>
		## Display a message at the end of the install
		#If (-not $useDefaultMsi) {Show-InstallationPrompt -Message "${appVendor} ${appName} ${appVersion} has been sucessfully installed." -ButtonRightText 'OK' -Icon Information -NoWait}
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close applications with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'sqldeveloper' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>
		If (Test-Path -Path "$envProgramFiles\Oracle SQL Developer" -PathType 'Container') {
			Remove-File -Path "$envProgramFiles\Oracle SQL Developer\*" -Recurse
			Remove-Folder -Path "$envProgramFiles\Oracle SQL Developer"
			Remove-File -Path "$envCommonStartMenuPrograms\Oracle SQL Developer.lnk"
		}

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}

	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}

# SIG # Begin signature block
# MIIZ7wYJKoZIhvcNAQcCoIIZ4DCCGdwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDes+swXSN22mAy
# 2qpAUi+aqI9JT79hrwx7nwUSDiiSZ6CCFFwwggQUMIIC/KADAgECAgsEAAAAAAEv
# TuFS1zANBgkqhkiG9w0BAQUFADBXMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xv
# YmFsU2lnbiBudi1zYTEQMA4GA1UECxMHUm9vdCBDQTEbMBkGA1UEAxMSR2xvYmFs
# U2lnbiBSb290IENBMB4XDTExMDQxMzEwMDAwMFoXDTI4MDEyODEyMDAwMFowUjEL
# MAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMT
# H0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzIwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCU72X4tVefoFMNNAbrCR+3Rxhqy/Bb5P8npTTR94ka
# v56xzRJBbmbUgaCFi2RaRi+ZoI13seK8XN0i12pn0LvoynTei08NsFLlkFvrRw7x
# 55+cC5BlPheWMEVybTmhFzbKuaCMG08IGfaBMa1hFqRi5rRAnsP8+5X2+7UulYGY
# 4O/F69gCWXh396rjUmtQkSnF/PfNk2XSYGEi8gb7Mt0WUfoO/Yow8BcJp7vzBK6r
# kOds33qp9O/EYidfb5ltOHSqEYva38cUTOmFsuzCfUomj+dWuqbgz5JTgHT0A+xo
# smC8hCAAgxuh7rR0BcEpjmLQR7H68FPMGPkuO/lwfrQlAgMBAAGjgeUwgeIwDgYD
# VR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFEbYPv/c
# 477/g+b0hZuw3WrWFKnBMEcGA1UdIARAMD4wPAYEVR0gADA0MDIGCCsGAQUFBwIB
# FiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAzBgNVHR8E
# LDAqMCigJqAkhiJodHRwOi8vY3JsLmdsb2JhbHNpZ24ubmV0L3Jvb3QuY3JsMB8G
# A1UdIwQYMBaAFGB7ZhpFDZfKiVAvfQTNNKj//P1LMA0GCSqGSIb3DQEBBQUAA4IB
# AQBOXlaQHka02Ukx87sXOSgbwhbd/UHcCQUEm2+yoprWmS5AmQBVteo/pSB204Y0
# 1BfMVTrHgu7vqLq82AafFVDfzRZ7UjoC1xka/a/weFzgS8UY3zokHtqsuKlYBAIH
# MNuwEl7+Mb7wBEj08HD4Ol5Wg889+w289MXtl5251NulJ4TjOJuLpzWGRCCkO22k
# aguhg/0o69rvKPbMiF37CjsAq+Ah6+IvNWwPjjRFl+ui95kzNX7Lmoq7RU3nP5/C
# 2Yr6ZbJux35l/+iS4SwxovewJzZIjyZvO+5Ndh95w+V/ljW8LQ7MAbCOf/9RgICn
# ktSzREZkjIdPFmMHMUtjsN/zMIIEnzCCA4egAwIBAgISESHWmadklz7x+EJ+6RnM
# U0EUMA0GCSqGSIb3DQEBBQUAMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i
# YWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFtcGluZyBD
# QSAtIEcyMB4XDTE2MDUyNDAwMDAwMFoXDTI3MDYyNDAwMDAwMFowYDELMAkGA1UE
# BhMCU0cxHzAdBgNVBAoTFkdNTyBHbG9iYWxTaWduIFB0ZSBMdGQxMDAuBgNVBAMT
# J0dsb2JhbFNpZ24gVFNBIGZvciBNUyBBdXRoZW50aWNvZGUgLSBHMjCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBALAXrqLTtgQwVh5YD7HtVaTWVMvY9nM6
# 7F1eqyX9NqX6hMNhQMVGtVlSO0KiLl8TYhCpW+Zz1pIlsX0j4wazhzoOQ/DXAIlT
# ohExUihuXUByPPIJd6dJkpfUbJCgdqf9uNyznfIHYCxPWJgAa9MVVOD63f+ALF8Y
# ppj/1KvsoUVZsi5vYl3g2Rmsi1ecqCYr2RelENJHCBpwLDOLf2iAKrWhXWvdjQIC
# KQOqfDe7uylOPVOTs6b6j9JYkxVMuS2rgKOjJfuv9whksHpED1wQ119hN6pOa9PS
# UyWdgnP6LPlysKkZOSpQ+qnQPDrK6Fvv9V9R9PkK2Zc13mqF5iMEQq8CAwEAAaOC
# AV8wggFbMA4GA1UdDwEB/wQEAwIHgDBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0
# MDIGCCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0
# b3J5LzAJBgNVHRMEAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEIGA1UdHwQ7
# MDkwN6A1oDOGMWh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vZ3MvZ3N0aW1lc3Rh
# bXBpbmdnMi5jcmwwVAYIKwYBBQUHAQEESDBGMEQGCCsGAQUFBzAChjhodHRwOi8v
# c2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RpbWVzdGFtcGluZ2cyLmNy
# dDAdBgNVHQ4EFgQU1KKESjhaGH+6TzBQvZ3VeofWCfcwHwYDVR0jBBgwFoAURtg+
# /9zjvv+D5vSFm7DdatYUqcEwDQYJKoZIhvcNAQEFBQADggEBAI+pGpFtBKY3IA6D
# lt4j02tuH27dZD1oISK1+Ec2aY7hpUXHJKIitykJzFRarsa8zWOOsz1QSOW0zK7N
# ko2eKIsTShGqvaPv07I2/LShcr9tl2N5jES8cC9+87zdglOrGvbr+hyXvLY3nKQc
# MLyrvC1HNt+SIAPoccZY9nUFmjTwC1lagkQ0qoDkL4T2R12WybbKyp23prrkUNPU
# N7i6IA7Q05IqW8RZu6Ft2zzORJ3BOCqt4429zQl3GhC+ZwoCNmSIubMbJu7nnmDE
# Rqi8YTNsz065nLlq8J83/rU9T5rTTf/eII5Ol6b9nwm8TcoYdsmwTYVQ8oDSHQb1
# WAQHsRgwggWuMIIElqADAgECAhAHA3HRD3laQHGZK5QHYpviMA0GCSqGSIb3DQEB
# CwUAMHwxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJNSTESMBAGA1UEBxMJQW5uIEFy
# Ym9yMRIwEAYDVQQKEwlJbnRlcm5ldDIxETAPBgNVBAsTCEluQ29tbW9uMSUwIwYD
# VQQDExxJbkNvbW1vbiBSU0EgQ29kZSBTaWduaW5nIENBMB4XDTE4MDYyMTAwMDAw
# MFoXDTIxMDYyMDIzNTk1OVowgbkxCzAJBgNVBAYTAlVTMQ4wDAYDVQQRDAU4MDIw
# NDELMAkGA1UECAwCQ08xDzANBgNVBAcMBkRlbnZlcjEYMBYGA1UECQwPMTIwMSA1
# dGggU3RyZWV0MTAwLgYDVQQKDCdNZXRyb3BvbGl0YW4gU3RhdGUgVW5pdmVyc2l0
# eSBvZiBEZW52ZXIxMDAuBgNVBAMMJ01ldHJvcG9saXRhbiBTdGF0ZSBVbml2ZXJz
# aXR5IG9mIERlbnZlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMtX
# iSjEDjYNBIYXsPnFGHwZqvS5lgRNSaQjsyxgLsGI6yLLDCpaYy3CBwN1on4QnYzE
# QpsHV+TJ/3K61ZvqAxhR6Anw8TjVjaB3kPdtKJjEUlgiXNK0nDRyMVasZyeXALR5
# STSf1SxoMt8HIDd0KTB8yhME6ezFdFzwB5He2/jyOswfYsN+n4k2Q9UcaVtWgCzW
# ua39anwNva7M4GugPO5ZkF6XkrGzRHpXctV/Fk6LmqPY6sRm45nScnC1KQ3NN/t6
# ZBHzmAtgbZa41o5+AvNdkv9TVF6S3ODGpf3qKW8kjFt82LLYdZi0V07ln+S/BtAl
# GUPOvqem4EkbMtZ5M3MCAwEAAaOCAewwggHoMB8GA1UdIwQYMBaAFK41Ixf//wY9
# nFDgjCRlMx5wEIiiMB0GA1UdDgQWBBSl6YhuvPlIpfXzOIq+Y/mkDGObDzAOBgNV
# HQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzAR
# BglghkgBhvhCAQEEBAMCBBAwZgYDVR0gBF8wXTBbBgwrBgEEAa4jAQQDAgEwSzBJ
# BggrBgEFBQcCARY9aHR0cHM6Ly93d3cuaW5jb21tb24ub3JnL2NlcnQvcmVwb3Np
# dG9yeS9jcHNfY29kZV9zaWduaW5nLnBkZjBJBgNVHR8EQjBAMD6gPKA6hjhodHRw
# Oi8vY3JsLmluY29tbW9uLXJzYS5vcmcvSW5Db21tb25SU0FDb2RlU2lnbmluZ0NB
# LmNybDB+BggrBgEFBQcBAQRyMHAwRAYIKwYBBQUHMAKGOGh0dHA6Ly9jcnQuaW5j
# b21tb24tcnNhLm9yZy9JbkNvbW1vblJTQUNvZGVTaWduaW5nQ0EuY3J0MCgGCCsG
# AQUFBzABhhxodHRwOi8vb2NzcC5pbmNvbW1vbi1yc2Eub3JnMC0GA1UdEQQmMCSB
# Iml0c3N5c3RlbWVuZ2luZWVyaW5nQG1zdWRlbnZlci5lZHUwDQYJKoZIhvcNAQEL
# BQADggEBAIc2PVq7BamWAujyCQPHsGCDbM3i1OY5nruA/fOtbJ6mJvT9UJY4+61g
# rcHLzV7op1y0nRhV459TrKfHKO42uRyZpdnHaOoC080cfg/0EwFJRy3bYB0vkVP8
# TeUkvUhbtcPVofI1P/wh9ZT2iYVCerOOAqivxWqh8Dt+8oSbjSGhPFWyu04b8Ucz
# bK/97uXdgK0zNcXDJUjMKr6CbevfLQLfQiFPizaej+2fvR/jZHAvxO9W2rhd6Nw6
# gFs2q3P4CFK0+yAkFCLk+9wsp+RsRvRkvdWJp+anNvAKOyVfCj6sz5dQPAIYIyLh
# y9ze3taVKm99DQQZV/wN/ATPDftLGm0wggXrMIID06ADAgECAhBl4eLj1d5QRYXz
# JiSABeLUMA0GCSqGSIb3DQEBDQUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# TmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBV
# U0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZp
# Y2F0aW9uIEF1dGhvcml0eTAeFw0xNDA5MTkwMDAwMDBaFw0yNDA5MTgyMzU5NTla
# MHwxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJNSTESMBAGA1UEBxMJQW5uIEFyYm9y
# MRIwEAYDVQQKEwlJbnRlcm5ldDIxETAPBgNVBAsTCEluQ29tbW9uMSUwIwYDVQQD
# ExxJbkNvbW1vbiBSU0EgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEAwKAvix56u2p1rPg+3KO6OSLK86N25L99MCfmutOYMlYj
# XAaGlw2A6O2igTXrC/Zefqk+aHP9ndRnec6q6mi3GdscdjpZh11emcehsriphHMM
# zKuHRhxqx+85Jb6n3dosNXA2HSIuIDvd4xwOPzSf5X3+VYBbBnyCV4RV8zj78gw2
# qblessWBRyN9EoGgwAEoPgP5OJejrQLyAmj91QGr9dVRTVDTFyJG5XMY4DrkN3dR
# yJ59UopPgNwmucBMyvxR+hAJEXpXKnPE4CEqbMJUvRw+g/hbqSzx+tt4z9mJmm2j
# /w2nP35MViPWCb7hpR2LB8W/499Yqu+kr4LLBfgKCQIDAQABo4IBWjCCAVYwHwYD
# VR0jBBgwFoAUU3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFK41Ixf//wY9
# nFDgjCRlMx5wEIiiMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8E
# STBHMEWgQ6BBhj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNB
# Q2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsG
# AQUFBzAChjNodHRwOi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRk
# VHJ1c3RDQS5jcnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5j
# b20wDQYJKoZIhvcNAQENBQADggIBAEYstn9qTiVmvZxqpqrQnr0Prk41/PA4J8HH
# nQTJgjTbhuET98GWjTBEE9I17Xn3V1yTphJXbat5l8EmZN/JXMvDNqJtkyOh26ow
# AmvquMCF1pKiQWyuDDllxR9MECp6xF4wnH1Mcs4WeLOrQPy+C5kWE5gg/7K6c9G1
# VNwLkl/po9ORPljxKKeFhPg9+Ti3JzHIxW7LdyljffccWiuNFR51/BJHAZIqUDw3
# LsrdYWzgg4x06tgMvOEf0nITelpFTxqVvMtJhnOfZbpdXZQ5o1TspxfTEVOQAsp0
# 5HUNCXyhznlVLr0JaNkM7edgk59zmdTbSGdMq8Ztuu6VyrivOlMSPWmay5MjvwTz
# uNorbwBv0DL+7cyZBp7NYZou+DoGd1lFZN0jU5IsQKgm3+00pnnJ67crdFwfz/8b
# q3MhTiKOWEb04FT3OZVp+jzvaChHWLQ8gbCORgClaZq1H3aqI7JeRkWEEEp6Tv4W
# AVsr/i7LoXU72gOb8CAzPFqwI4Excdrxp0I4OXbECHlDqU4sTInqwlMwofmxeO4u
# 94196qIqJQl+8Sykl06VktqMux84Iw3ZQLH08J8LaJ+WDUycc4OjY61I7FGxCDkb
# SQf3npXeRFm0IBn8GiW+TRDk6J2XJFLWEtVZmhboFlBLoUlqHUCKu0QOhU/+AEOq
# nY98j2zRMYIE6TCCBOUCAQEwgZAwfDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1J
# MRIwEAYDVQQHEwlBbm4gQXJib3IxEjAQBgNVBAoTCUludGVybmV0MjERMA8GA1UE
# CxMISW5Db21tb24xJTAjBgNVBAMTHEluQ29tbW9uIFJTQSBDb2RlIFNpZ25pbmcg
# Q0ECEAcDcdEPeVpAcZkrlAdim+IwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg4Zx1YYsy
# 4+akrunN2jku6E87G5Vf7mQ5sbPig/1qFJ0wDQYJKoZIhvcNAQEBBQAEggEAx541
# dmr+q7PYC86H9VWjdoLcHKXig20JNSIVEJ8KVwsz29eoGlBlZFnnKOZfBidUNOX/
# XImDLDAXD2KtJt9F3rTZHVRypznFZnnnXdGdHEqtixynj4ivBL+ss+F+BNyvdsWt
# zii8+LJZipCxWVahxxWuVWZ6TpT+mj9LZ0hzcDI4p9C3vVVaBSNYvXad7nsV3Ose
# V/yBwSNsZCJa7aclvOPX6HVeCYZHQuf3c2BwvEFo+6rXaMu5xHAOaAtZ63gB+5t4
# jKek4Y/R6nlcWNB8yWHjQjpUOD6fN+8XRK2s5FnscxdBedoQiy5O+3dhbn/YjNw8
# +DmdQ8QJebQPaLCjFqGCAqIwggKeBgkqhkiG9w0BCQYxggKPMIICiwIBATBoMFIx
# CzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQD
# Ex9HbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIEcyAhIRIdaZp2SXPvH4Qn7p
# GcxTQRQwCQYFKw4DAhoFAKCB/TAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0xOTA4MDExNzQwMzlaMCMGCSqGSIb3DQEJBDEWBBThQtH0
# XUliHaiUJHnbnOiwoONGSTCBnQYLKoZIhvcNAQkQAgwxgY0wgYowgYcwgYQEFGO4
# L6th9YOQlpUFCwAknFApM+x5MGwwVqRUMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIEcyAhIRIdaZp2SXPvH4Qn7pGcxTQRQwDQYJKoZIhvcNAQEBBQAE
# ggEADCD+rnGufJ3WNkwd0PZyh6cTVudOJRWTXHiOjup4ra7kNkAoramhmCRJnV91
# sb+uwhrH4o0erF3k/a6rk4TbwKMzVjAS1tuVCvOeE/8hsqqLwc5Ax4FpOdOf8GBx
# GbS4gnNGZ2X3QEJ49aSeHTM2S5ntVa+omDa9RnWqvGGzSD5jA4eHLzaAXhz2hai8
# gT0AR4Mrxsc3wYuAU+uSv49ceq7rF3BajvwDOFLCPucHja5pSBft87kq/o6NL/1u
# k+Ncn3zMf0smMg1pJWjSDOGc6BSWZLRfDDaTf6ucNarUYF8+rL4SXhwRfu/J/xu0
# OZ+z6o3P4eY2DLZrPDNzOWNU3g==
# SIG # End signature block
