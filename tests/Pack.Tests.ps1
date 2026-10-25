BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Guild/Guild.psd1') -Force

    function New-TestPack {
        param([string] $Directory, [string] $Name, [string] $Body)
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        $path = Join-Path $Directory "$Name.pack.psd1"
        Set-Content -LiteralPath $path -Value "@{`n Name = '$Name'; Version = '1.0.0'; Contract = '1'`n$Body`n}"
        $path
    }
}

Describe 'Resolve-GuildPack' {
    It 'works with no packs at all' {
        $pack = Get-GuildPack
        $pack.Prefix | Should -Be 'guild'
        $pack.Knowledge | Should -BeNullOrEmpty
        $pack.Review.MaxRounds | Should -Be 3
        $pack.Layers | Should -HaveCount 1
    }

    It 'layers packs: scalars replaced, lists accumulate with the later pack first' {
        $dir = Join-Path $TestDrive 'layers'
        New-Item -ItemType Directory "$dir/standards" -Force | Out-Null
        $company = New-TestPack -Directory $dir -Name 'company' -Body "Prefix = 'co'`nKnowledge = @(@{ Name = 'base'; Kind = 'standards'; Path = 'standards' })`nPolicy = @{ NeverInvent = @('team names') }"
        $project = New-TestPack -Directory $dir -Name 'project' -Body "Extends = 'company'`nReview = @{ MaxRounds = 5 }`nPolicy = @{ NeverInvent = @('queue names') }"
        $pack = Get-GuildPack -Pack $project
        $pack.Prefix | Should -Be 'co'
        $pack.Review.MaxRounds | Should -Be 5
        $pack.Review.PromoteAfter | Should -Be 2
        $pack.Policy.NeverInvent[0] | Should -Be 'queue names'
        $pack.Policy.NeverInvent | Should -Contain 'team names'
        $pack.Policy.NeverInvent | Should -Contain 'credentials or secret values'
        $pack.Knowledge[0].Path | Should -Be ("$dir/standards".Replace('\', '/'))
        $pack.Layers | Should -Be @('guild-defaults 0.3.0', 'company 1.0.0', 'project 1.0.0')
    }

    It 'resolves {env:NAME} and {pack}' {
        $dir = Join-Path $TestDrive 'tokens'
        New-Item -ItemType Directory "$dir/guides" -Force | Out-Null
        $env:GUILD_TEST_STANDARDS = $dir
        try {
            $path = New-TestPack -Directory $dir -Name 'tokens' -Body "Knowledge = @(@{ Name = 'x'; Kind = 'patterns'; Path = '{env:GUILD_TEST_STANDARDS}/guides' })`nStyle = @(@{ Language = 'python'; Guide = '{pack}/guides' })"
            $pack = Get-GuildPack -Pack $path
            $pack.Knowledge[0].Path | Should -Be ("$dir/guides".Replace('\', '/'))
            $pack.Style[0].Guide | Should -Be ("$dir/guides".Replace('\', '/'))
        }
        finally { Remove-Item Env:GUILD_TEST_STANDARDS }
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an unknown key'; Body = "Colour = 'blue'"; Message = "*unknown key 'Colour'*" }
        @{ Case = 'an absolute path'; Body = "AdrTemplate = 'C:/standards/adr.md'"; Message = '*absolute path*' }
        @{ Case = 'a missing path'; Body = "AdrTemplate = 'nowhere/adr.md'"; Message = '*does not exist*' }
        @{ Case = 'an unset variable'; Body = "AdrTemplate = '{env:GUILD_TEST_UNSET_VARIABLE}/adr.md'"; Message = '*not set*' }
        @{ Case = 'an unknown capability'; Body = "Capabilities = @{ Deploy = @{ Command = 'x' } }"; Message = "*unknown key 'Deploy'*" }
        @{ Case = 'a capability without a command'; Body = "Capabilities = @{ Check = @{ Notes = 'x' } }"; Message = '*needs a Command*' }
        @{ Case = 'an unknown knowledge kind'; Body = "Knowledge = @(@{ Name = 'x'; Kind = 'lore'; Path = '.' })"; Message = "*unknown Kind 'lore'*" }
        @{ Case = 'an unknown harness in Models'; Body = "Models = @{ notatool = @{ Tiers = @{ top = 'x' } } }"; Message = "*unknown key 'notatool'*" }
        @{ Case = 'a bad Review number'; Body = 'Review = @{ MaxRounds = 0 }'; Message = '*at least 1*' }
    ) {
        $path = New-TestPack -Directory (Join-Path $TestDrive "bad-$([guid]::NewGuid())") -Name 'bad' -Body $Body
        { Get-GuildPack -Pack $path } | Should -Throw -ExpectedMessage $Message
    }

    It 'rejects an unsupported contract' {
        $dir = Join-Path $TestDrive 'contract'
        New-Item -ItemType Directory $dir -Force | Out-Null
        Set-Content "$dir/c.pack.psd1" "@{ Name = 'c'; Version = '1.0.0'; Contract = '9' }"
        { Get-GuildPack -Pack "$dir/c.pack.psd1" } | Should -Throw -ExpectedMessage "*Contract '9' is not supported*"
    }

    It 'detects packs that extend each other in a cycle' {
        $dir = Join-Path $TestDrive 'cycle'
        $null = New-TestPack -Directory $dir -Name 'a' -Body "Extends = 'b'"
        $b = New-TestPack -Directory $dir -Name 'b' -Body "Extends = 'a'"
        { Get-GuildPack -Pack $b } | Should -Throw -ExpectedMessage '*cycle*'
    }

    It 'finds an extended pack on GUILD_PACK_PATH' {
        $shared = Join-Path $TestDrive 'shared'
        $null = New-TestPack -Directory $shared -Name 'org' -Body "Prefix = 'org'"
        $project = New-TestPack -Directory (Join-Path $TestDrive 'proj') -Name 'proj' -Body "Extends = 'org'"
        $env:GUILD_PACK_PATH = $shared
        try { (Get-GuildPack -Pack $project).Prefix | Should -Be 'org' }
        finally { Remove-Item Env:GUILD_PACK_PATH }
    }

    It 'loads the example pack' {
        $pack = Get-GuildPack -Pack (Join-Path $PSScriptRoot '../packs/example/example.pack.psd1')
        $pack.Prefix | Should -Be 'acme'
        $pack.Models.claude.Tiers.top | Should -Be 'opus'
    }
}
