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
$javaHome = "c:\Program Files\Java\jdk1.8.0_131"
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", ${javaHome}, "Machine")
[System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";${javaHome}\bin", "Machine")
$Env:Path += ";${javaHome}\bin"


# Install Maven
$source = "https://archive.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.zip"
$destination = "C:\maven.zip"
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($source, $destination)
$shell_app=new-object -com shell.application
$zip_file = $shell_app.namespace($destination)
mkdir 'C:\Program Files\apache-maven-3.5.2'
$destination = $shell_app.namespace('C:\Program Files')
$destination.Copyhere($zip_file.items(), 0x14)
[System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";C:\Program Files\apache-maven-3.5.2\bin", "Machine")
$Env:Path += ";C:\Program Files\apache-maven-3.5.2\bin"


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
mkdir c:\jenkins
$slaveSource = $jenkinsserverurl + "jnlpJars/slave.jar"
$destSource = "c:\jenkins\slave.jar"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($slaveSource, $destSource)

# Download the service wrapper
$wrapperExec = "c:\jenkins\jenkins-slave.exe"
$configFile = "c:\jenkins\jenkins-slave.xml"
$wc.DownloadFile("https://github.com/kohsuke/winsw/releases/download/winsw-v2.1.2/WinSW.NET2.exe", $wrapperExec)
$wc.DownloadFile("https://raw.githubusercontent.com/azure-devops/ci/master/resources/jenkins-slave.exe.config", "c:\jenkins\jenkins-slave.exe.config")
$wc.DownloadFile("https://raw.githubusercontent.com/azure-devops/ci/master/resources/jenkins-slave.xml", $configFile)

# Prepare config
Write-Output "Executing agent process "
$configExec = "${javaHome}\bin\java.exe"
$configArgs = "-jnlpUrl `"${jenkinsserverurl}/computer/${vmname}/slave-agent.jnlp`" -noReconnect"
if ($secret) {
    $configArgs += " -secret `"$secret`""
}
(Get-Content $configFile).replace('@JAVA@', $configExec) | Set-Content $configFile
(Get-Content $configFile).replace('@ARGS@', $configArgs) | Set-Content $configFile
(Get-Content $configFile).replace('@SLAVE_JAR_URL', $slaveSource) | Set-Content $configFile

# Install the service
& $wrapperExec install
& $wrapperExec start