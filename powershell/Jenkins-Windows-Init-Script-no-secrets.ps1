Set-ExecutionPolicy Unrestricted
# Jenkins plugin will dynamically pass the server name and vm name.
# If your jenkins server is configured for security , make sure to edit command for how slave executes
$jenkinsserverurl = $args[0]
$vmname = $args[1]
$secret = $args[2]


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

# execute agent
Write-Output "Executing agent process "
$java="d:\java\zulu1.7.0_51-7.3.0.4-win64\bin\java.exe"
$jar="-jar"
$jnlpUrl="-jnlpUrl"
$secretFlag="-secret"
$serverURL=$jenkinsserverurl+"computer/" + $vmname + "/slave-agent.jnlp"
while ($true) {
  try {
    # Launch
    & $java -jar $destSource $secretFlag  $secret $jnlpUrl $serverURL -noReconnect
  }
  catch [System.Exception] {
    Write-Output $_.Exception.ToString()
  }
  Start-Sleep 10
}
