
$git_path = "C:\Project\Maximus5\Test\cur"
$git_exe = "C:\Utils\Lans\GIT\bin\git.exe"

cd $git_path

function PrintLines($clr,$txt)
{
  if (($txt -eq $NULL) -Or ($txt -eq 0)) {
    #[console]::beep(500,300); [console]::beep(500,300)
    Write-Host -ForegroundColor Red "Command execution failed?"
    return
  }
  #if ($clr -eq "Red") { [console]::beep(500,300); [console]::beep(500,300) }
  $txt.Split("`n") | foreach { Write-Host -ForegroundColor $clr $_ }
}

function UpdateIndex($prn_lines)
{
  $loop = $TRUE
  while ($loop) {
    $loop = $FALSE
    $local:cmd_add = @()
    $local:cmd_del = @()
    #$local:cmd_mov = @()
    $rstatus = & $git_exe reset head
    $status = & $git_exe -c color.status=false status --short
    if ($status -eq $null) {
      Write-Host -ForegroundColor Yellow ("Nothing was changed, errcode="+$LASTEXITCODE)
      $script:no_changes = $TRUE
      return $TRUE
    }
    $script:no_changes = $FALSE
    $lines = $status.Split("`n")
    $unknown = $FALSE
    for ($i = 0; $i -lt $lines.length; $i++) {
      $fs = $lines[$i].Substring(0,2)
      $fn = $lines[$i].Substring(3).Trim()
      if (($fs -eq " D")) {
        if ($prn_lines) {
          Write-Host -ForegroundColor Yellow $lines[$i]
        }
        $local:cmd_del += $fn
      }
      elseif (($fs -eq "??") -Or ($fs -eq " A") -Or ($fs -eq " M")) {
        if ($prn_lines) {
          Write-Host -ForegroundColor Cyan $lines[$i]
        }
        $local:cmd_add += $fn
      } else {
        #[console]::beep(500,300); [console]::beep(500,300)
        Write-Host -ForegroundColor Red $lines[$i]
        $unknown = $TRUE
      }
    }

    if ($unknown) {
      Write-Host -ForegroundColor Cyan "git execution skipped"
      return $FALSE
    }

    #Write-Host ("Deleted files: " + $local:cmd_del)
    #Write-Host ("New&Modified files: " + $local:cmd_add)
    if ($local:cmd_del.Length -gt 0) {
      Write-Host ($git_exe + " rm " + $local:cmd_del)
      & $git_exe "rm" $local:cmd_del
      if ($LASTEXITCODE -gt 0) {
        return $FALSE
      }
    }

    if ($local:cmd_add.Length -gt 0) {
      PrintLines Yellow $local:cmd_add
      #[console]::beep(500,300); [console]::beep(500,300)
      #$cfrm = Read-Host -Prompt ("New items: "+$local:cmd_add.Length+". Type 'y' to add, 'S'kip, 'R'escan, 'n' to exit")
      $cfrm = "y"
      if ($cfrm -eq "r") {
        $loop = $TRUE
        continue
      }
      elseif ($cfrm -ne "s") {
        if ($cfrm -ne "y") {
          exit 99
          return $FALSE
        }

        & $git_exe add $local:cmd_add
        if ($LASTEXITCODE -gt 0) {
          return $FALSE
        }
      }
    }

    #if ($local:cmd_mov.Length -gt 0) {
    #  $local:cmd_mov | foreach {
    #    $_
    #    $files = $_.Replace(" -> ","`n").Split("`n")
    #    $files.length
    #    $files[0]
    #    $files[1]
    #    Write-Host $git_exe mv $files[0].Trim() $files[1].Trim()
    #    & $git_exe mv $files[0].Trim() $files[1].Trim()
    #    if ($LASTEXITCODE -gt 0) {
    #      return $FALSE
    #    }
    #  }
    #}
  }

  return $TRUE
}

UpdateIndex $FALSE
