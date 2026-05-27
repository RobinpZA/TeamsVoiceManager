Describe 'Format-PhoneNumber' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Helpers' 'Format-PhoneNumber.ps1')
    }
    It 'Should pass through E.164 numbers unchanged' {
        Format-PhoneNumber -Number '+27821234567' | Should -Be '+27821234567'
    }
    It 'Should convert SA local format to E.164' {
        Format-PhoneNumber -Number '0821234567' | Should -Be '+27821234567'
    }
    It 'Should add + prefix to country code' {
        Format-PhoneNumber -Number '27821234567' | Should -Be '+27821234567'
    }
}

Describe 'ConvertTo-JsonSafe' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Helpers' 'ConvertTo-JsonSafe.ps1')
    }
    It 'Should convert simple hashtable to JSON' {
        $result = @{name='test';value=42} | ConvertTo-JsonSafe
        $result | Should -Match '"name"'
        $result | Should -Match '"value"'
    }
}
