# Download and Install Java
Set-ExecutionPolicy Unrestricted
#Default workspace location
Set-Location C:\
$source = "http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-windows-x64.exe"
$destination = "C:\jdk-8u131-windows-x64.exe"
$client = new-object System.Net.WebClient
$cookie = "oraclelicense=accept-securebackup-cookie"
$client.Headers.Add([System.Net.HttpRequestHeader]::Cookie, $cookie)
$client.downloadFile($source, $destination)
$proc = Start-Process -FilePath $destination -ArgumentList "/s" -Wait -PassThru
$proc.WaitForExit()
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "c:\Program Files\Java\jdk1.8.0_131", "Machine")
[System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";c:\Program Files\Java\jdk1.8.0_131\bin", "Machine")
$Env:Path += ";c:\Program Files\Java\jdk1.8.0_131\bin"


# Install Maven
$source = "http://mirror.reverse.net/pub/apache/maven/maven-3/3.5.0/binaries/apache-maven-3.5.0-bin.zip"
$destination = "C:\maven.zip"
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($source, $destination)
$shell_app=new-object -com shell.application
$zip_file = $shell_app.namespace($destination)
mkdir 'C:\Program Files\apache-maven-3.5.0'
$destination = $shell_app.namespace('C:\Program Files')
$destination.Copyhere($zip_file.items(), 0x14)
[System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";C:\Program Files\apache-maven-3.5.0\bin", "Machine")
$Env:Path += ";C:\Program Files\apache-maven-3.5.0\bin"


# Install Git
$source = "https://github.com/git-for-windows/git/releases/latest"
$latestRelease = Invoke-WebRequest -UseBasicParsing $source -Headers @{"Accept"="application/json"}
$json = $latestRelease.Content | ConvertFrom-Json
$latestVersion = $json.tag_name
$versionHead = $latestVersion.Substring(1, $latestVersion.IndexOf("windows")-2)
$source = "https://github.com/git-for-windows/git/releases/download/v${versionHead}.windows.1/Git-${versionHead}-64-bit.exe"
$destination = "C:\Git-${versionHead}-64-bit.exe"
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($source, $destination)
$proc = Start-Process -FilePath $destination -ArgumentList "/VERYSILENT" -Wait -PassThru
$proc.WaitForExit()
$Env:Path += ";C:\Program Files\Git\cmd"
#Disable git credential manager, get more details in https://support.cloudbees.com/hc/en-us/articles/221046888-Build-Hang-or-Fail-with-Git-for-Windows
git config --system --unset credential.helper


# Install Slaves jar and connect via JNLP
# Jenkins plugin will dynamically pass the server name and vm name.
# If your jenkins server is configured for security , make sure to edit command for how slave executes
$jenkinsserverurl = $args[0]
$vmname = $args[1]
$secret = $args[2]

# Downloading jenkins slaves jar
Write-Output "Downloading jenkins slave jar "
$slaveSource = $jenkinsserverurl + "jnlpJars/slave.jar"
$destSource = "C:\slave.jar"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($slaveSource, $destSource)

# execute agent
Write-Output "Executing agent process "
$java="java"
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
