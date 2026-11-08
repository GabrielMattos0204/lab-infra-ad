<#
.SYNOPSIS
Provisiona OUs, grupos, usuarios e delegacao a partir de CSV.
Idempotente: reexecutar nao duplica objetos.
#>
[CmdletBinding()]
param(
    [string]$Dominio = "lab.local",
    [string]$Raiz = "OU=LAB,DC=lab,DC=local",
    [string]$ArquivoOUs = (Join-Path $PSScriptRoot "..\data\ous.csv"),
    [string]$ArquivoUsuarios = (Join-Path $PSScriptRoot "..\data\usuarios.csv"),
    [string]$ArquivoLog = (Join-Path $PSScriptRoot "..\logs\provisionamento.log")
)

$ErrorActionPreference = "Stop"
$senha = ConvertTo-SecureString "Senha@2026!" -AsPlainText -Force
$guidResetSenha = [guid]"00299570-246d-11d0-a768-00aa006e0529"

function Write-Log {
    param([string]$Mensagem, [string]$Nivel = "INFO")
    $linha = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Nivel, $Mensagem
    $linha | Out-File -FilePath $ArquivoLog -Append -Encoding utf8
    Write-Host $linha
}

function New-OUSeNaoExiste {
    param([string]$Pai, [string]$Nome)
    $dn = "OU=$Nome,$Pai"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Log "OU existente, ignorada: $dn" "SKIP"; return $dn
    }
    New-ADOrganizationalUnit -Name $Nome -Path $Pai -ProtectedFromAccidentalDeletion $true
    Write-Log "OU criada: $dn" "OK"
    return $dn
}

function New-GrupoSeNaoExiste {
    param([string]$Caminho, [string]$Nome)
    if (Get-ADGroup -Filter "Name -eq '$Nome'" -ErrorAction SilentlyContinue) {
        Write-Log "Grupo existente, ignorado: $Nome" "SKIP"; return
    }
    New-ADGroup -Name $Nome -SamAccountName $Nome -GroupScope Global -GroupCategory Security -Path $Caminho
    Write-Log "Grupo criado: $Nome" "OK"
}

function New-UsuarioSeNaoExiste {
    param([string]$Caminho, $Linha)
    if (Get-ADUser -Filter "SamAccountName -eq '$($Linha.Sam)'" -ErrorAction SilentlyContinue) {
        Write-Log "Usuario existente, ignorado: $($Linha.Sam)" "SKIP"; return
    }
    New-ADUser -Name $Linha.Nome -SamAccountName $Linha.Sam `
        -UserPrincipalName "$($Linha.Sam)@$Dominio" -Path $Caminho `
        -AccountPassword $senha -Enabled $true -ChangePasswordAtLogon $true `
        -Department $Linha.Departamento -Title $Linha.Cargo
    Write-Log "Usuario criado: $($Linha.Sam)" "OK"
}

function Set-DelegacaoSenha {
    param([string]$Caminho, [string]$Grupo)
    $acl = Get-Acl "AD:\$Caminho"
    if ($acl.Access | Where-Object { $_.IdentityReference -like "*$Grupo" }) {
        Write-Log "Delegacao ja existe em $Caminho" "SKIP"; return
    }
    $sid = (Get-ADGroup $Grupo).SID
    $regra = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $sid, "ExtendedRight", "Allow", $guidResetSenha)
    $acl.AddAccessRule($regra)
    Set-Acl "AD:\$Caminho" $acl
    Write-Log "Delegacao de senha aplicada: $Grupo em $Caminho" "OK"
}

try {
    Write-Log "=== Inicio do provisionamento ==="

    foreach ($ou in (Import-Csv $ArquivoOUs -Delimiter ";")) {
        New-OUSeNaoExiste -Pai $ou.Pai -Nome $ou.Nome | Out-Null
    }

    $ouGrupos = "OU=Grupos_Seguranca,$Raiz"
    foreach ($g in @("GG_HelpDesk","GG_TI","GG_Financeiro","GG_Operacao")) {
        New-GrupoSeNaoExiste -Caminho $ouGrupos -Nome $g
    }

    foreach ($u in (Import-Csv $ArquivoUsuarios -Delimiter ";")) {
        $caminho = "OU=$($u.Departamento),OU=Usuarios,OU=Corporativo,$Raiz"
        if ($u.Departamento -eq "Operacao") {
            $caminho = "OU=Usuarios,OU=Costa_Pinto,$Raiz"
        }
        New-UsuarioSeNaoExiste -Caminho $caminho -Linha $u
        try {
            $membros = Get-ADGroupMember -Identity $u.Grupos | Select-Object -ExpandProperty SamAccountName
            if ($membros -contains $u.Sam) {
                Write-Log "Vinculo ja existente: $($u.Sam)" "SKIP"
            } else {
                Add-ADGroupMember -Identity $u.Grupos -Members $u.Sam
                Write-Log "Vinculo: $($u.Sam) -> $($u.Grupos)" "OK"
            }
        } catch { Write-Log "Vinculo ja existente: $($u.Sam)" "SKIP" }
    }

    Set-DelegacaoSenha -Caminho "OU=Usuarios,OU=Corporativo,$Raiz" -Grupo "GG_HelpDesk"
    Set-DelegacaoSenha -Caminho "OU=Usuarios,OU=Costa_Pinto,$Raiz" -Grupo "GG_HelpDesk"

    Write-Log "=== Provisionamento concluido ==="
}
catch {
    Write-Log "ERRO: $($_.Exception.Message)" "ERRO"
    throw
}