function Import-PortalAudioFile {
    [CmdletBinding()]
    param([hashtable]$Body)
    # Audio file upload requires special handling with base64 content
    $fileName = $Body.fileName
    $content = $Body.content  # base64 encoded
    try {
        $bytes = [Convert]::FromBase64String($content)
        $audioFile = Import-CsOnlineAudioFile -ApplicationId OrgAutoAttendant -FileName $fileName -Content $bytes -EA Stop
        Write-AuditEntry -Action 'UploadAudio' -Target $fileName -Result 'Success' -Detail "ID: $($audioFile.Id)"
        return @{success=$true;fileId=$audioFile.Id;fileName=$fileName}
    } catch {
        Write-AuditEntry -Action 'UploadAudio' -Target $fileName -Result 'Error' -Detail $_.Exception.Message
        return @{success=$false;error=$_.Exception.Message}
    }
}
