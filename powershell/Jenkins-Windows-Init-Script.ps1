Set-ExecutionPolicy Unrestricted
# Jenkins plugin will dynamically pass the server name and vm name.
# If your jenkins server is configured for security , make sure to edit command for how slave executes
# You may need to pass credentails or secret in the command , Refer to help by running "java -jar slave.jar --help"
$jenkinsserverurl = $args[0]
$vmname = $args[1]


# Download the file to a specific location
Write-Output "Downloading zulu SDK "
$source = "http://azure.azulsystems.com/zulu/zulu1.7.0_51-7.3.0.4-win64.zip?jenkins"
mkdir d:\azurecsdir
$destination = "d:\azurecsdir\zuluJDK.zip"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($source, $destination)

Write-Output "Unzipping JDK "
# Unzip the file to specified location
$shell_app=new-object -com shell.application
$zip_file = $shell_app.namespace($destination)
mkdir d:\java
$destination = $shell_app.namespace("d:\java")
$destination.Copyhere($zip_file.items())
Write-Output "Successfully downloaded and extracted JDK "

# Downloading jenkins slaves jar
Write-Output "Downloading jenkins slave jar "
$slaveSource = $jenkinsserverurl + "jnlpJars/slave.jar"
$destSource = "d:\java\slave.jar"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($slaveSource, $destSource)

# execute slave
Write-Output "Executing slave process "
$java="d:\java\zulu1.7.0_51-7.3.0.4-win64\bin\java.exe"
$jar="-jar"
$jnlpUrl="-jnlpUrl"
$serverURL=$jenkinsserverurl+"computer/" + $vmname + "/slave-agent.jnlp"
$jnlpCredentialsFlag="-jnlpCredentials"
# syntax for credentials username:apitoken or username:password
# you can get api token by clicking on your username --> configure --> show api token
$credentials="username:apitoken"
& $java $jar $destSource $jnlpCredentialsFlag $credentials $jnlpUrl $serverURL

