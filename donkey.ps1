#This code watches for zip files to be placed into a directory, it will then extract them and 
# train them on donkeycar for windows

#Zip Files to be placed in the following location
$zipFileLocation = 'C:\Users\adric\projects\NanoDonkeyConfig\data'

#Conda and donkey activation 
$conda = "& '~\Miniconda3\shell\condabin\conda-hook.ps1' ; conda activate '~\Miniconda3' "
$donkey = 'conda activate donkey'

Set-Alias sz "7z\7za.exe"
$global:queue = New-Object System.Collections.Queue

function Invoke-Train-Model {
    param ($zipFile)
    #Activate Conda and donkey
    iex $conda
    iex $donkey
    
    #We extract the files to a temp location with a guid
    $guid = New-Guid
    $tempPath = "c:\temp\" + $guid 
    #Write-Output $tempPathNew-Item -Path $tempPath -ItemType 'directory'

    sz e $zipFile -o"$tempPath"
    $filepath = Get-ChildItem $zipFile
    $train = "python ..\train.py --model ..\model\" + $filepath.BaseName + ".h5 --tub " + $tempPath
    iex $train
    $train = "python ..\train.py --model ..\model\" + $filepath.BaseName + "_aug.h5 --aug --tub " + $tempPath
    iex $train

    Remove-Item $tempPath -Recurse
    $zipFilePath = [System.IO.Path]::GetDirectoryName($zipFile)
    New-Item -Path $zipFilePath -Name "archive" -ItemType "directory" -Force
    $zipFilePathArchive = $zipFilePath + '\archive\' + $filepath.Name
    #Write-Output $zipFilePathArchive
    Move-Item -Path $zipFile -Destination $zipFilePathArchive 
    iex "conda deactivate"
    iex "conda deactivate"
}

function Invoke-ZipFileWatcher {
    param ($zipFileLocation)
    #Start FileWatcher for watching folder
    $filter = '*.zip'
    $FileSystemWatcher = New-Object IO.FileSystemWatcher $zipFileLocation, $filter -Property @{
        IncludeSubdirectories = $false;
        NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
    }

    $actionWatcher = {
        $Object = "{0} was  {1} at {2}" -f $Event.SourceEventArgs.FullPath,  $Event.SourceEventArgs.ChangeType, $Event.TimeGenerated
        $WriteHostParams  = @{
            ForegroundColor = 'Green'
            BackgroundColor =  'Black'
            Object =  $Object
        }
        Write-Host @WriteHostParams
        $global:queue.Enqueue($Event.SourceEventArgs.FullPath)
    }

    Register-ObjectEvent -InputObject $FileSystemWatcher Created -SourceIdentifier FileCreated -Action $actionWatcher 
}

Invoke-ZipFileWatcher($zipFileLocation)

while(1 -eq 1) {
    Start-Sleep -Seconds 1.5
    if ($global:queue.Count -gt 0) {
        $fileName = $global:queue.Dequeue()
        Write-Output "File to be processed $($fileName)"
        Invoke-Train-Model($fileName)
    }
}


