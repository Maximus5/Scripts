
$arc_path = "C:\Projects\ConEmu-Deploy\Pack\imp_src"
$bak_path = "C:\Projects\ConEmu-Deploy\Pack\imp_src\go"
$git_path = "C:\Projects\Test\mrg3"
$git_exe = "C:\Utils\GIT\bin\git.exe"
$extract_cmd = "C:\Projects\Test\extract.cmd"
$script:lastlabel = "090201b"

cd $git_path

function PrintLines($clr,$txt)
{
  if (($txt -eq $NULL) -Or ($txt -eq 0)) {
    [console]::beep(500,300); [console]::beep(500,300)
    Write-Host -ForegroundColor Red "Command execution failed?"
    return
  }
  if ($clr -eq "Red") { [console]::beep(500,300); [console]::beep(500,300) }
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
      if (($fs -eq " D") -Or ($fs -eq "D ")) {
        if ($prn_lines) {
          Write-Host -ForegroundColor Yellow $lines[$i]
        }
        if ($fs -eq " D") {
          $local:cmd_del += $fn
        }
      }
      elseif ($fs -eq "??") {
        if ($prn_lines) {
          Write-Host -ForegroundColor Cyan $lines[$i]
        }
        $local:cmd_add += $fn
      }
      elseif ($fs -eq "R ") {
        if ($prn_lines) {
          Write-Host -ForegroundColor Yellow $lines[$i]
        }
        #$local:cmd_mov += $fn
      }
      elseif ($fs -eq "A ") {
        # OK, skip it
        if ($prn_lines) {
          Write-Host -ForegroundColor Yellow $lines[$i]
        }
      }
      elseif ($fs -eq " M") {
        # OK, skip it
        if ($prn_lines) {
          Write-Host -ForegroundColor Green $lines[$i]
        }
      } else {
        [console]::beep(500,300); [console]::beep(500,300)
        Write-Host -ForegroundColor Red $lines[$i]
        $unknown = $TRUE
      }
    }

    if ($unknown) {
      return $FALSE
    }

    #Write-Host ("Deleted files: " + $local:cmd_del)
    #Write-Host ("New&Modified files: " + $local:cmd_add)
    if ($local:cmd_del.Length -gt 0) {
      & $git_exe "rm" $local:cmd_del
      if ($LASTEXITCODE -gt 0) {
        return $FALSE
      }
    }

    if ($local:cmd_add.Length -gt 0) {
      PrintLines Yellow $local:cmd_add
      [console]::beep(500,300); [console]::beep(500,300)
      $cfrm = Read-Host -Prompt ("New items: "+$local:cmd_add.Length+". Type 'y' to add, 'S'kip, 'R'escan, 'n' to exit")
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

function Commit($msg)
{
  $err = & $git_exe commit -am $msg
  #$err = & cmd /c C:\Projects\ConEmu-History-arc\commit_dt.cmd $build
  if ($LASTEXITCODE -gt 0) {
    PrintLines Red $err
    return $FALSE
  }
  PrintLines Gray $err
  #Write-Host "Commit succeeded"
  return $TRUE
}

function DoUpdate
{
  Write-Host "Updating index..."
  $r = UpdateIndex $FALSE
  if ($r -eq $FALSE) {
    return $FALSE
  }
  if ($script:no_changes) {
    return $TRUE
  }
  $r = UpdateIndex $TRUE
  if ($r -eq $FALSE) {
    return $FALSE
  }
  $r = Commit ("[arc] "+$script:lastlabel+" history")
  if ($r -eq $FALSE) {
    #Write-Host "Commit failed?"
    return $FALSE
  }
  #Write-Host "Returning TRUE"
  return $TRUE
}

function Extract($arc)
{
  #& 7z x -y -r $arc * `
  #  -x!*.exe -x!*.dll -x!*.7z -x!*.rar -x!*.zip -x!*.pdb -x!*.obj -x!*.map -x!*.bat -x!*.cmd -x!*.exe -x!*.dll `
  #  -x!*.xcf -x!*.idc -x!*.ion -x!*.png -x!*.xcf -x!*.psd -x!*.ini -x!*.xml -x!!*.txt -x!*.log `
  #  -x!*.pdb -x!*.opt -x!*.lib -x!*.exp -x!*.suo -x!*.user -x!*test* -x!*debug* -x!links -x!help
  $out = & cmd /c $extract_cmd $arc
  if ($LASTEXITCODE -gt 0) {
    PrintLines Red $out
    return $FALSE
  }
  #PrintLines $out
  return $TRUE
}

function Cleaning([Boolean]$all=$FALSE)
{
  $files = Get-ChildItem -Path $git_path
  $files | foreach {
    if (($_.Name -ne ".git") -And ($all -Or (($_.Name -ne "ConEmu.Addons") -And ($_.Name -ne "Release")))) {
      if ($_.PSIsContainer) {
        Remove-Item -Recurse -Force $_.Name
      } else {
        Remove-Item -Force $_.Name
      }
    }
  }
}

function DoStep
{
  $arc_files = (Get-ChildItem -File $arc_path)
  $script:lastlabel = $arc_files[0].BaseName.Substring(16)

  $may_be_src = ($arc_path + "\" + $arc_files[0].BaseName+".src.7z")
  $may_be_rel = ($arc_path + "\" + $arc_files[0].BaseName+".rel.7z")

  $is_src_exists = Test-Path -PathType Leaf -Path $may_be_src
  $is_rel_exists = Test-Path -PathType Leaf -Path $may_be_rel

  Write-Host "Cleaning..."
  Cleaning ($is_src_exists -Or $is_rel_exists)
  #$out = & cmd /c C:\Projects\ConEmu-History-arc\clean.cmd
  #if ($LASTEXITCODE -gt 0) {
  #  PrintLines Red $out
  #  return $FALSE
  #}

  Write-Host -ForegroundColor Magenta $arc_files[0].Name

  if ((Extract $arc_files[0].FullName) -eq $FALSE) {
    return $FALSE
  }

  if ($is_src_exists) {
    Write-Host ("Checking: "+$may_be_src+"... Found")
    if ((Extract $may_be_src) -eq $FALSE) {
      return $FALSE
    }
    mv $may_be_src $bak_path
    if ($LASTEXITCODE -gt 0) {
      Write-Host -ForegroundColor Red "Move file failed"
      return $FALSE
    }
  } else {
    if ($is_rel_exists) {
      Write-Host ("Checking: "+$may_be_rel+"... Found")

      $ext_rc = Extract $may_be_rel

      if ($ext_rc -eq $FALSE) {
        return $FALSE
      }
      mv $may_be_rel $bak_path
      if ($LASTEXITCODE -gt 0) {
        Write-Host -ForegroundColor Red "Move file failed"
        return $FALSE
      }
    } else {
      Write-Host ("Checking: "+$may_be_src+"... Not found")
      Write-Host ("Checking: "+$may_be_rel+"... Not found")
    }
  }

  mv $arc_files[0].FullName $bak_path
  if ($LASTEXITCODE -gt 0) {
    Write-Host -ForegroundColor Red "Move file failed"
    return $FALSE
  }

  if ((Test-Path -PathType Leaf -Path ($git_path+"\src\ConEmu\ConEmu.cpp")) -eq $FALSE) {
    PrintLines Red "src\ConEmu\ConEmu.cpp not exists!"
    exit 99
  }

  if ((DoUpdate) -eq $FALSE) {
    #Write-Host "DoUpdate returns FALSE"
    return $FALSE
  }

  #Write-Host "DoUpdate returns TRUE"
  return $TRUE
}

if ((DoStep) -eq $FALSE) {
  exit 99
}
#UpdateIndex
#DoUpdate
#Cleaning
