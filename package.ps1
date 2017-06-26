    $path = $PSScriptRoot+'\staging'
	
	# Delete staging directory if it exists already
	If (Test-Path $path){
		Remove-Item $path -Force -Recurse
	}
	
    #Regex for stripping directory leads for Rock .lst files

    $regex = '.\\staging\\content\\'


	# Build staging directory
    New-Item $path -type directory
    New-Item $path\content -type directory
    New-Item $path\uninstall -type directory
    New-Item $path\content\bin -type directory
    New-Item $path\content\Webhooks -type directory

    Copy-Item $PSScriptRoot\SendGrid\bin\Release\com.bricksandmortarstudio.SendGrid.dll $path\content\bin\
    Copy-Item $PSScriptRoot\SendGrid\bin\Release\Sendgrid.Webhooks.dll $path\content\bin\
    Copy-Item $PSScriptRoot\SendGrid\RockWeb\Webhooks\SendGrid.ashx $path\content\Webhooks
	Copy-Item $PSScriptRoot\SendGrid\RockWeb\Webhooks\SendGrid.ashx $path\content\Webhooks

	# Get deletefile.lst
    Get-ChildItem $path\content\*.* -Recurse | Resolve-Path -Relative | Set-Content $path\uninstall\deletefile.lst
	# Remove staging prefix on deletefile.lst
    (Get-Content $path\uninstall\deletefile.lst) -replace $regex, '' | Set-Content $path\uninstall\deletefile.lst
	
    $name = 'SendGrid-VERSION.plugin'
	
	# Zip things up
	$command = '7za a -tzip -r ' + $name + ' .\staging\*'
	Invoke-Expression -Command:$command