
$Script_Working_path = (Get-Location).Path
$web_prefix = "http://www.farmanager.com/"

function DumpException($error)
{
  Write-Host -ForegroundColor Red $error.Exception
}

function CreateWebClient
{
  if ($script:nwc -eq $null)
  {
    $script:nwc = (new-object net.webclient)
    $script:nwc.Encoding = [System.Text.Encoding]::UTF8
  }
  return $script:nwc
}

function RetrievePage([string]$http)
{
  $script:PageData = ""

  try {
    Write-Host $http
    $nwc = CreateWebClient
    $nwc.BaseAddress = ""
    $script:PageData = $nwc.DownloadString($http)
    $nwc.BaseAddress = $http
  } catch {
    $se = [String]$error[0].Exception
    if ($se.IndexOf("(404)") -ge 0) {
      $script:PageData = ("<pre>Page not found on server!`r`n" + $http + "`r`n" + $error[0].Exception + "</pre>")
    } else {
      DumpException $error[0]
    }
    Write-Host -ForegroundColor Red ($http + " - NOT FOUND")
    exit
  }

  return $script:PageData
}

function SetDescription([string]$filepath,[string]$descr)
{
  $dir = Split-Path $filepath -Parent
  $name = Split-Path $filepath -Leaf
  $ion_path = Join-Path $dir "Descript.ion"
  #if ([System.IO.File]::Exists($ion_path)) {
  #  $ion = Get-Content $ion_path
  #} else {
  #  $ion = @()
  #}
  $ion = ($name + " " + $descr)
  Add-Content $ion_path $ion
  #Set-Content $ion_path $ion
}

function DownloadMsi([string]$url)
{
  $name = $url.SubString($url.LastIndexOf('/')+1)
  #$path = Join-Path $Script_Working_path ("..\" + $name)
  $path = Join-Path $Script_Working_path ($name)
  if ([System.IO.File]::Exists($path)) {
    Write-Host ("File " + $name + " already exists")
    return
  }
  $href = ($web_prefix + $url)
  Write-Host $href
  $nwc = CreateWebClient
  $nwc.DownloadFile($href,$path)
  if ($url.SubString(0,6) -eq "files/") {
    SetDescription $path "Stable"
  }
}

function SavePageLocally([string]$name, [string]$html)
{
  $file = Join-Path $Script_Working_path $name
  Set-Content $file $html

  if ($html -match "nightly.Far30b.+msi") {
    DownloadMsi $matches[0]
  }
  if ($html -match "files.Far30b.+msi") {
    DownloadMsi $matches[0]
  }
}


$x86 = RetrievePage "http://www.farmanager.com/download.php?p=32&l=en"
SavePageLocally "x86.html" $x86

$x64 = RetrievePage "http://www.farmanager.com/download.php?p=64&l=en"
SavePageLocally "x64.html" $x64
