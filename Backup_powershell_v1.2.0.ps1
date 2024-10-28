<#
By: Rafael "Zen-Aku"
Contato: rafaelrodrigues-2017@hotmail.com

v1.2.0
Foi adicionado uma op��o onde voc� agora pode indicar quais diret�rios deseja ignorar;
Foi modificado a maneira como o log � salvo, agora ele possui data e hora no nome do arquivo "Log_dd-MM-yy_HH-mm.log";
Adicionado o argumento "/MT:64" na opera��o robocopy para otimizar a c�pia dos arquivos;
Adicionado suporte ao encoding de sa�da para UTF-8;

v1.0.0
Este script realiza a c�pia dos arquivos nos diret�rios informados utilizando o robocopy e por fim, envia um aquivo de log para seu e-mail
ao final da opera��o informando se tudo ocorreu bem. Voc� tamb�m tem a op��o de compactar os arquivos em formato .zip caso ache necess�rio,
e neste caso, voc� poder� definir o n�mero de c�pias que voc� deseja armazenar alterando a vari�vel $limiteCopias para a quantidade desejada.
Caso a vari�vel $deveZipar esteja como falsa, o script ignora o limite de c�pias estabelecidas na vari�vel $limiteCopias.
#>

$dirsParaBackup = @("") # Lista de diret�rios para backup

$dirsParaIgnorar = @("") # Lista de diret�rios para ignorar durante a c�pia (pode ser deixado em branco se necess�rio).

$dirDestino = "" # Destino do backup

$deveZipar = $true # Deve zipar os arquivos de backup? "$false" para desativar

$emailRemetente = "" # E-mail remetente

$emailDestinatario = "" # E-mail destinat�rio

$senhaEmail = "" # Voc� deve utilizar sua senha de aplicativo da google aqui!

$limiteCopias = 1 # Limite de c�pias de backup armazenadas (se aplica somente quando "$deveZipar = $true")


########################### N�O ALTERE NENHUMA LINHA ABAIXO ###########################
chcp 65001 | Out-Null

# Criando o diret�rio de destino, se necess�rio
if (!(Test-Path -Path $dirDestino)) {
    New-Item -Path $dirDestino -ItemType Directory -Force | Out-Null
}

# Compactar um diret�rio
function ZiparDiretorio {
    param(
        [string]$dirPath,
        [string]$zipFilePath
    )

    if (!(Test-Path -Path $zipFilePath)) {
        Write-Output "Criando arquivo zip $zipFilePath"
        Compress-Archive -Path $dirPath -DestinationPath $zipFilePath
    } else {
        Write-Output "Arquivo zip $zipFilePath j� existe, adicionando conte�do"
        Compress-Archive -Path $dirPath -Update -DestinationPath $zipFilePath
    }
}

# Enviar e-mail com o arquivo de log anexado
function EnviarEmail {
    param(
        [string]$remetente,
        [string]$destinatario,
        [string]$senha,
        [string]$assunto,
        [string]$corpo,
        [string]$anexo
    )

    $EmailFrom = $remetente
    $EmailTo = $destinatario
    $Subject = $assunto
    $Body = $corpo

    $SMTPServer = "smtp.gmail.com"
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
    $SMTPClient.EnableSsl = $true
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($EmailFrom, $senha)
    
    $MailMessage = New-Object Net.Mail.MailMessage
    $MailMessage.From = $EmailFrom
    $MailMessage.To.Add($EmailTo)
    $MailMessage.Subject = $Subject
    $MailMessage.Body = $Body
    
    $Attachment = New-Object Net.Mail.Attachment($anexo, "text/plain; charset=utf-8")
    $MailMessage.Attachments.Add($Attachment)
    
    $SMTPClient.Send($MailMessage)
    $Attachment.Dispose()
}

$logDate = Get-Date -Format "dd-MM-yy_HH-mm" # Obt�m a data atual formatada
$prefixoLog = "Log_" # Define o prefixo do log
$logName = $prefixoLog + $logDate # Combina o prefixo com a data

# Copiando os arquivos para os diret�rios de backup usando Robocopy e gerando o log
$dirsParaBackup | ForEach-Object {
    $dir = $_
    $dirNome = Split-Path $dir -Leaf
    $dirDestinoPath = Join-Path -Path $dirDestino -ChildPath $dirNome

    # Criando o diret�rio de destino para este backup, se necess�rio
    if (!(Test-Path -Path $dirDestinoPath)) {
        New-Item -Path $dirDestinoPath -ItemType Directory -Force | Out-Null
    }

    # Executando o Robocopy com diret�rios a serem ignorados
    robocopy $dir $dirDestinoPath /MT:64 /E /Z /R:5 /W:5 /UNICODE /LOG+:$dirDestino\$logName.log /XD $dirsParaIgnorar
}

# Verificando se $deveZipar � verdadeiro antes de aplicar a regra do limite de c�pias
if ($deveZipar) {
    # Verificando o n�mero de arquivos no diret�rio de destino
    $arquivosBackup = Get-ChildItem -Path $dirDestino -File -Filter "*.zip"
    $copias = $arquivosBackup.Count

    # Remova o arquivo mais antigo, se necess�rio
    if ($copias -gt $limiteCopias) {
        $arquivosMaisAntigos = $arquivosBackup | Sort-Object CreationTime | Select-Object -First ($copias - $limiteCopias)
        
        $arquivosMaisAntigos | ForEach-Object {
            Remove-Item -Path $_.FullName -Force
        }
    }

    # Compactando diret�rios, se necess�rio
    $dataHora = Get-Date -Format "ddMMyy_HHmm"
    $zipFileName = "Backup_$dataHora.zip"
    $zipFilePath = Join-Path -Path $dirDestino -ChildPath $zipFileName

    $dirsParaBackup | ForEach-Object {
        $dir = $_
        $dirNome = Split-Path $dir -Leaf
        $dirDestinoPath = Join-Path -Path $dirDestino -ChildPath $dirNome
        ZiparDiretorio -dirPath $dirDestinoPath -zipFilePath $zipFilePath
    }

    # Removendo diret�rios de backup ap�s a compacta��o
    $dirsParaBackup | ForEach-Object {
        $dir = $_
        $dirNome = Split-Path $dir -Leaf
        $dirDestinoPath = Join-Path -Path $dirDestino -ChildPath $dirNome
        Remove-Item -Path $dirDestinoPath -Recurse -Force
    }
}

$EmailHora = Get-Date -Format "ddMMyy_HHmm"

# Enviando o e-mail com o arquivo de log anexado
$assuntoEmail = "Opera��o conclu�da"
$corpoEmail = "Opera��o conclu�da em $EmailHora, verifique o LOG pra mais detalhes."
$arquivoLog = Join-Path -Path $dirDestino -ChildPath "$logName.log"
EnviarEmail -remetente $emailRemetente -destinatario $emailDestinatario -senha $senhaEmail -assunto $assuntoEmail -corpo $corpoEmail -anexo $arquivoLog