#INCLUDE WCONNECT.H

#DEFINE MAX_INI_BUFFERSIZE  		512
#DEFINE MAX_INI_ENUM_BUFFERSIZE 	8196

SET PROCEDURE TO wwAPI ADDITIVE

*************************************************************
DEFINE CLASS wwAPI AS Custom
*************************************************************
***    Author: Rick Strahl
***            (c) West Wind Technologies, 1997
***   Contact: (541) 386-2087  / rstrahl@west-wind.com
***  Function: Encapsulates several Windows API functions
*************************************************************

*** Custom Properties
nLastError=0
cErrorMsg = ""

FUNCTION Init
************************************************************************
* wwAPI :: Init
*********************************
***  Function: DECLARES commonly used DECLAREs so they're not redefined
***            on each call to the methods.
************************************************************************

DECLARE INTEGER GetPrivateProfileString ;
   IN WIN32API ;
   STRING cSection,;
   STRING cEntry,;
   STRING cDefault,;
   STRING @cRetVal,;
   INTEGER nSize,;
   STRING cFileName

DECLARE INTEGER GetCurrentThread ;
   IN WIN32API 
   
DECLARE INTEGER GetThreadPriority ;
   IN WIN32API ;
   INTEGER tnThreadHandle

DECLARE INTEGER SetThreadPriority ;
   IN WIN32API ;
   INTEGER tnThreadHandle,;
   INTEGER tnPriority

*** Open Registry Key
DECLARE INTEGER RegOpenKey ;
        IN Win32API ;
        INTEGER nHKey,;
        STRING cSubKey,;
        INTEGER @nHandle

*** Create a new Key
DECLARE Integer RegCreateKey ;
        IN Win32API ;
        INTEGER nHKey,;
        STRING cSubKey,;
        INTEGER @nHandle

*** Close an open Key
DECLARE Integer RegCloseKey ;
        IN Win32API ;
        INTEGER nHKey
  
ENDFUNC
* Init

FUNCTION MessageBeep
************************************************************************
* wwAPI :: MessageBeep
**********************
***  Function: MessageBeep API call runs system sounds
***      Pass: lnSound   -   Uses FoxPro.h MB_ICONxxxxx values
***    Return: nothing
************************************************************************
LPARAMETERS lnSound
DECLARE INTEGER MessageBeep ;
   IN WIN32API AS MsgBeep ;
   INTEGER nSound
=MsgBeep(lnSound)
ENDFUNC
* MessageBeep

FUNCTION ReadRegistryString
************************************************************************
* wwAPI :: ReadRegistryString
*********************************
***  Function: Reads a string value from the registry.
***      Pass: tnHKEY    -  HKEY value (in CGIServ.h)
***            tcSubkey  -  The Registry subkey value
***            tcEntry   -  The actual Key to retrieve
***            tlInteger -  Optional - Return an DWORD value
***            tnMaxStringSize - optional - Max size for a string (512)
***    Return: Registry String or .NULL. on not found
************************************************************************
LPARAMETERS tnHKey, tcSubkey, tcEntry, tlInteger,tnMaxStringSize
LOCAL lnRegHandle, lnResult, lnSize, lcDataBuffer, tnType

IF EMPTY(tnMaxStringSize)
   tnMaxStringSize= MAX_INI_BUFFERSIZE
ENDIF
IF EMPTY(tnHKEY)
   tnHKEY = HKEY_LOCAL_MACHINE
ENDIF   
IF VARTYPE(tnHKey) = "C"
   DO CASE
      CASE tnHKey = "HKLM"
         tnHKey = HKEY_LOCAL_MACHINE
      CASE tnHkey = "HKCU"
         tnHKey = HKEY_CURRENT_USER
      CASE tnHkey = "HKCR"
          tnHKey = HKEY_CLASSES_ROOT
      OTHERWISE 
         tnHKey = 0 
   ENDCASE
ENDIF

lnRegHandle=0

*** Open the registry key
lnResult=RegOpenKey(tnHKey,tcSubKey,@lnRegHandle)
IF lnResult#ERROR_SUCCESS
   *** Not Found
   RETURN .NULL.
ENDIF   

*** Return buffer to receive value
IF !tlInteger
*** Need to define here specifically for Return Type
*** for lpdData parameter or VFP will choke.
*** Here it's STRING.
DECLARE INTEGER RegQueryValueEx ;
        IN Win32API ;
        INTEGER nHKey,;
        STRING lpszValueName,;
        INTEGER dwReserved,;
        INTEGER @lpdwType,;
        STRING @lpbData,;
        INTEGER @lpcbData
        
	lcDataBuffer=space(tnMaxStringSize)
	lnSize=LEN(lcDataBuffer)
	lnType=REG_DWORD

	lnResult=RegQueryValueEx(lnRegHandle,tcEntry,0,@lnType,;
                         @lcDataBuffer,@lnSize)
ELSE
*** Need to define here specifically for Return Type
*** for lpdData parameter or VFP will choke. 
*** Here's it's an INTEGER
DECLARE INTEGER RegQueryValueEx ;
        IN Win32API AS RegQueryInt;
        INTEGER nHKey,;
        STRING lpszValueName,;
        INTEGER dwReserved,;
        Integer @lpdwType,;
        INTEGER @lpbData,;
        INTEGER @lpcbData

	lcDataBuffer=0
	lnSize=4
	lnType=REG_DWORD
	lnResult=RegQueryInt(lnRegHandle,tcEntry,0,@lnType,;
	                         @lcDataBuffer,@lnSize)
	IF lnResult = ERROR_SUCCESS
	   RETURN lcDataBuffer
	ELSE
       RETURN -1
	ENDIF
ENDIF
=RegCloseKey(lnRegHandle)

IF lnResult#ERROR_SUCCESS 
   *** Not Found
   RETURN .NULL.
ENDIF   

IF lnSize<2
   RETURN ""
ENDIF
   
*** Return string and strip out NULLs
RETURN SUBSTR(lcDataBuffer,1,lnSize-1)
ENDFUNC
* ReadRegistryString

************************************************************************
* Registry :: WriteRegistryString
*********************************
***  Function: Writes a string value to the registry.
***            If the value doesn't exist it's created. If the key
***            doesn't exist it is also created, but this will only
***            succeed if it's the last key on the hive.
***      Pass: tnHKEY    -  HKEY value (in WCONNECT.h)
***            tcSubkey  -  The Registry subkey value
***            tcEntry   -  The actual Key to write to
***            tcValue   -  Value to write or .NULL. to delete key
***            tlCreate  -  Create if it doesn't exist
***    Assume: Use with extreme caution!!! Blowing your registry can
***            hose your system!
***    Return: .T. or .NULL. on error
************************************************************************
FUNCTION WriteRegistryString
LPARAMETERS tnHKey, tcSubkey, tcEntry, tcValue,tlCreate
LOCAL lnRegHandle, lnResult, lnSize, lcDataBuffer, tnType

IF EMPTY(tnHKEY)
   tnHKEY = HKEY_LOCAL_MACHINE
ENDIF   
IF VARTYPE(tnHKey) = "C"
   DO CASE
      CASE tnHKey = "HKLM"
         tnHKey = HKEY_LOCAL_MACHINE
      CASE tnHkey = "HKCU"
         tnHKey = HKEY_CURRENT_USER
      CASE tnHkey = "HKCR"
          tnHKey = HKEY_CLASSES_ROOT
      OTHERWISE 
         tnHKey = 0 
   ENDCASE
ENDIF

lnRegHandle=0

lnResult=RegOpenKey(tnHKey,tcSubKey,@lnRegHandle)
IF lnResult#ERROR_SUCCESS
   IF !tlCreate
      RETURN .F.
   ELSE
      lnResult=RegCreateKey(tnHKey,tcSubKey,@lnRegHandle)
      IF lnResult#ERROR_SUCCESS
         RETURN .F.
      ENDIF  
   ENDIF
ENDIF   

*** Need to define here specifically for Return Type!
*** Here lpbData is STRING.

*** Check for .NULL. which means delete key
IF !ISNULL(tcValue)
  IF VARTYPE(tcValue) = "N"
	DECLARE INTEGER RegSetValueEx ;
	        IN Win32API ;
	        INTEGER nHKey,;
	        STRING lpszEntry,;
	        INTEGER dwReserved,;
	        INTEGER fdwType,;
	        INTEGER@ lpbData,;
	        INTEGER cbData
	  lnResult=RegSetValueEx(lnRegHandle,tcEntry,0,REG_DWORD,;
                         @tcValue,4)
  ELSE
	  DECLARE INTEGER RegSetValueEx ;
	        IN Win32API ;
	        INTEGER nHKey,;
	        STRING lpszEntry,;
	        INTEGER dwReserved,;
	        INTEGER fdwType,;
	        STRING lpbData,;
	        INTEGER cbData
	  *** Nope - write new value
	  lnSize=LEN(tcValue)
	  if lnSize=0
	     tcValue=CHR(0)
	  ENDIF

	  lnResult=RegSetValueEx(lnRegHandle,tcEntry,0,REG_SZ,;
	                         tcValue,lnSize)
  ENDIF                         
ELSE
  *** Delete a value from a key
  DECLARE INTEGER RegDeleteValue ;
          IN Win32API ;
          INTEGER nHKEY,;
          STRING cEntry

  *** DELETE THE KEY
  lnResult=RegDeleteValue(lnRegHandle,tcEntry)
ENDIF                         

=RegCloseKey(lnRegHandle)
                        
IF lnResult#ERROR_SUCCESS
   RETURN .F.
ENDIF   

RETURN .T.
ENDPROC
* WriteRegistryString

FUNCTION EnumKey
************************************************************************
* wwAPI :: EnumRegistryKey
*********************************
***  Function: Returns a registry key name based on an index
***            Allows enumeration of keys in a FOR loop. If key
***            is empty end of list is reached.
***      Pass: tnHKey    -   HKEY_ root key
***            tcSubkey  -   Subkey string
***            tnIndex   -   Index of key name to get (0 based)
***    Return: "" on error - Key name otherwise
************************************************************************
LPARAMETERS tnHKey, tcSubKey, tnIndex 
LOCAL lcSubKey, lcReturn, lnResult, lcDataBuffer

lnRegHandle=0

*** Open the registry key
lnResult=RegOpenKey(tnHKey,tcSubKey,@lnRegHandle)
IF lnResult#ERROR_SUCCESS
   *** Not Found
   RETURN .NULL.
ENDIF   

DECLARE Integer RegEnumKey ;
  IN WIN32API ;
  INTEGER nHKey, ;
  INTEGER nIndex, ;
  STRING @cSubkey, ;  
  INTEGER nSize

lcDataBuffer=SPACE(MAX_INI_BUFFERSIZE)
lnSize=MAX_INI_BUFFERSIZE
lnResult=RegENumKey(lnRegHandle, tnIndex, @lcDataBuffer, lnSize)

=RegCloseKey(lnRegHandle)

IF lnResult#ERROR_SUCCESS 
   *** Not Found
   RETURN .NULL.
ENDIF   

RETURN TRIM(CHRTRAN(lcDataBuffer,CHR(0),""))
ENDFUNC
* EnumRegistryKey


FUNCTION GetProfileString
************************************************************************
* wwAPI :: GetProfileString
***************************
***  Modified: 09/26/95
***  Function: Read Profile String information from a given
***            text file using Windows INI formatting conventions
***      Pass: pcFileName   -    Name of INI file
***            pcSection    -    [Section] in the INI file ("Drivers")
***            pcEntry      -    Entry to retrieve ("Wave")
***                              If this value is a null string
***                              all values for the section are
***                              retrieved seperated by CHR(13)s
***    Return: Value(s) or .NULL. if not found
************************************************************************
LPARAMETERS pcFileName,pcSection,pcEntry, pnBufferSize
LOCAL lcIniValue, lnResult

*** Initialize buffer for result
lcIniValue=SPACE(IIF( vartype(pnBufferSize)="N",pnBufferSize,MAX_INI_BUFFERSIZE) )

lnResult=GetPrivateProfileString(pcSection,pcEntry,"*None*",;
   @lcIniValue,LEN(lcIniValue),pcFileName)

*** Strip out Nulls
IF VARTYPE(pcEntry)="N" AND pcEntry=0
   *** 0 was passed to get all entry labels
   *** Seperate all of the values with a Carriage Return
   lcIniValue=TRIM(CHRTRAN(lcIniValue,CHR(0),CHR(13)) )
ELSE
   *** Individual Entry
   lcIniValue=SUBSTR(lcIniValue,1,lnResult)
ENDIF

*** On error the result contains "*None"
IF lcIniValue="*None*"
   lcIniValue=.NULL.
ENDIF

RETURN lcIniValue
ENDFUNC
* GetProfileString

************************************************************************
* wwAPI :: GetProfileSections
*********************************
***  Function: Retrieves all sections of an INI File
***      Pass: @laSections   -   Empty array to receive sections
***            lcIniFile     -   Name of the INI file
***            lnBufSize     -   Size of result buffer (optional)
***    Return: Count of Sections  
************************************************************************
FUNCTION aProfileSections
LPARAMETERS laSections, lcIniFile
LOCAL lnBufsize, lcBuffer, lnSize, lnResult, lnCount

lnBufsize=IIF(EMPTY(lnBufsize),16484,lnBufsize)

DECLARE INTEGER GetPrivateProfileSectionNames ;
   IN WIN32API ;
   STRING @lpzReturnBuffer,;
   INTEGER nSize,;
   STRING lpFileName
   
lcBuffer = SPACE(lnBufSize)
lnSize = lEN(lcBuffer)   
lnResult = GetPrivateProfileSectionNames(@lcBuffer,lnSize,lcIniFile)
IF lnResult < 3
   RETURN 0
ENDIF

lnCount = aParseString(@laSections,TRIM(lcBuffer),CHR(0))
lnCount = lnCount - 2
IF lnCount > 0
  DIMENSION laSections[lnCount]
ENDIF

RETURN lnCount
ENDFUNC
* wwAPI :: aProfileSections

************************************************************************
* wwAPI :: WriteProfileString
*********************************
***  Function: Writes a value back to an INI file
***      Pass: pcFileName    -   Name of the file to write to
***            pcSection     -   Profile Section
***            pcKey         -   The key to write to
***            pcValue       -   The value to write
***    Return: .T. or .F.
************************************************************************
FUNCTION WriteProfileString
LPARAMETERS pcFileName,pcSection,pcEntry,pcValue

   DECLARE INTEGER WritePrivateProfileString ;
      IN WIN32API ;
      STRING cSection,STRING cEntry,STRING cValue,;
      STRING cFileName

   lnRetVal=WritePrivateProfileString(pcSection,pcEntry,pcValue,pcFileName)

   if lnRetval=1
      RETURN .t.
   endif
   
   RETURN .f.
ENDFUNC
* WriteProfileString

FUNCTION GetTempPath
************************************************************************
* wwAPI :: GetTempPath
***********************
***  Function: Returns the OS temporary files path
***    Return: Temp file path with trailing "\"
************************************************************************
LOCAL lcPath, lnResult

*** API Definition:
*** ---------------
*** DWORD GetTempPath(cchBuffer, lpszTempPath)
***
*** DWORD cchBuffer;	/* size, in characters, of the buffer	*/
*** LPTSTR lpszTempPath;	/* address of buffer for temp. path name	*/
DECLARE INTEGER GetTempPath ;
   IN WIN32API AS GetTPath ;
   INTEGER nBufSize, ;
   STRING @cPathName

lcPath=SPACE(256)
lnSize=LEN(lcPath)

lnResult=GetTPath(lnSize,@lcPath)

IF lnResult=0
   lcPath=""
ELSE
   lcPath=SUBSTR(lcPath,1,lnResult)
ENDIF

RETURN lcPath
ENDFUNC
* eop GetTempPath

************************************************************************
FUNCTION MapDrive()
****************************************
***  Function: Maps a network path
***    Assume:
***      Pass: lcNetPath -  \\servername\share  (\\rasvist\f$)
***            lcShareName =  z:
***            lcPassword - optional
***    Return:
************************************************************************
LPARAMETERS lcNetPath, lcShareName, lcPassword

IF EMPTY(lcPassword)
  lcPassword = CHR(0)
ENDIF

DECLARE INTEGER WNetAddConnection IN WIN32API ;
    string lpRemoteName, string lpPassWord, string lpLocalName
    
lnError =  WNetAddConnection(lcNetPath,lcPassword, lcShareName)
IF lnError # 0
	this.cErrorMsg = this.GetSystemErrorMsg(lnError)
	RETURN .F.
ENDIF

RETURN .T.
ENDFUNC
*  wwAPI ::  MapPath

************************************************************************
FUNCTION DisconnectDrive
****************************************
***  Function: Disconnects a network drive mapping
***    Assume:
***      Pass:
***    Return:
************************************************************************
LPARAMETERS lcShareName
LOCAL lnError

DECLARE INTEGER WNetCancelConnection in Win32API ;
   string lpName, INTEGER bForce
   
lnError = WNetCancelConnection(lcShareName,1)   
IF lnError # 0
   this.cErrorMsg = this.GetSystemErrorMsg(lnError)
   RETURN .F.
ENDIF

RETURN .T.   
ENDFUNC
*  wwAPI ::  UnmapDrive


FUNCTION GetEXEFile
************************************************************************
* wwAPI :: GetEXEFileName
*********************************
***  Function: Returns the Module name of the EXE file that started
***            the current application. Unlike Application.Filename
***            this function correctly returns the name of the EXE file
***            for Automation servers too!
***    Return: Filename or ""  (VFP.EXE is returned in Dev Version)
************************************************************************
DECLARE integer GetModuleFileName ;
   IN WIN32API ;
   integer hinst,;
   string @lpszFilename,;
   integer @cbFileName
   
lcFilename=space(256)
lnBytes=255   

=GetModuleFileName(0,@lcFileName,@lnBytes)

lnBytes=AT(CHR(0),lcFileName)
IF lnBytes > 1
  lcFileName=SUBSTR(lcFileName,1,lnBytes-1)
ELSE
  lcFileName=""
ENDIF       

RETURN lcFileName
ENDFUNC
* GetEXEFileName


************************************************************************
* WinApi :: ShellExecute
*********************************
***    Author: Rick Strahl, West Wind Technologies
***            http://www.west-wind.com/ 
***  Function: Opens a file in the application that it's
***            associated with.
***      Pass: lcFileName  -  Name of the file to open
***            lcWorkDir   -  Working directory
***            lcOperation -  
***    Return: 2  - Bad Association (invalid URL)
***            31 - No application association
***            29 - Failure to load application
***            30 - Application is busy 
***
***            Values over 32 indicate success
***            and return an instance handle for
***            the application started (the browser) 
************************************************************************
***         FUNCTION ShellExecute
***         LPARAMETERS lcFileName, lcWorkDir, lcOperation
***         
***         lcWorkDir=IIF(type("lcWorkDir")="C",lcWorkDir,"")
***         lcOperation=IIF(type("lcOperation")="C",lcOperation,"Open")
***         
***         DECLARE INTEGER ShellExecute ;
***             IN SHELL32.DLL ;
***             INTEGER nWinHandle,;
***             STRING cOperation,;   
***             STRING cFileName,;
***             STRING cParameters,;
***             STRING cDirectory,;
***             INTEGER nShowWindow
***            
***         RETURN ShellExecute(0,lcOperation,lcFilename,"",lcWorkDir,1)
***         ENDFUNC
***         * ShellExecute

************************************************************************
* wwAPI :: CopyFile
*********************************
***  Function: Copies File. Faster than Fox Copy and handles
***            errors internally.
***      Pass: tcSource -  Source File
***            tcTarget -  Target File
***            tnFlag   -  0* overwrite, 1 don't
***    Return: .T. or .F.
************************************************************************
FUNCTION CopyFile
LPARAMETERS lcSource, lcTarget,nFlag
LOCAL lnRetVal 

*** Copy File and overwrite
nFlag=IIF(type("nFlag")="N",nFlag,0)

DECLARE INTEGER CopyFile ;
   IN WIN32API ;
   STRING @cSource,;
   STRING @cTarget,;
   INTEGER nFlag

lnRetVal=CopyFile(@lcSource,@lcTarget,nFlag)

RETURN IIF(lnRetVal=0,.F.,.T.)
ENDPROC
* CopyFile

FUNCTION GetUserName


DECLARE INTEGER GetUserName ;
     IN WIN32API ;
     STRING@ cComputerName,;
     INTEGER@ nSize

lcComputer=SPACE(80)
lnSize=80

=GetUserName(@lcComputer,@lnSize)
IF lnSize < 2
   RETURN ""
ENDIF   

RETURN SUBSTR(lcComputer,1,lnSize-1)

FUNCTION GetComputerName
************************************************************************
* wwAPI :: GetComputerName
*********************************
***  Function: Returns the name of the current machine
***    Return: Name of the computer
************************************************************************

DECLARE INTEGER GetComputerName ;
     IN WIN32API ;
     STRING@ cComputerName,;
     INTEGER@ nSize

lcComputer=SPACE(80)
lnSize=80

=GetComputername(@lcComputer,@lnSize)
IF lnSize < 2
   RETURN ""
ENDIF   

RETURN SUBSTR(lcComputer,1,lnSize)
ENDFUNC
* GetComputerName


FUNCTION LogonUser
************************************************************************
* wwAPI :: LogonUser
*********************************
***  Function: Check whether a username and password is valid
***    Assume: Account checking must have admin rights
***      Pass: Username, Password and optionally a server
***    Return: .T. or .F.
************************************************************************
LPARAMETERS lcUsername, lcPassword, lcServer

IF EMPTY(lcUsername)
   RETURN .F.
ENDIF
IF EMPTY(lcPassword)
   lcPassword = ""
ENDIF
IF EMPTY(lcServer)
   lcServer = "."
ENDIF         

#define LOGON32_LOGON_INTERACTIVE   2
#define LOGON32_LOGON_NETWORK       3
#define LOGON32_LOGON_BATCH         4
#define LOGON32_LOGON_SERVICE       5

#define LOGON32_PROVIDER_DEFAULT    0

DECLARE INTEGER LogonUser in WIN32API ;
       String lcUser,;
       String lcServer,;
       String lcPassword,;
       INTEGER dwLogonType,;
       Integer dwProvider,;
       Integer @dwToken
       
lnToken = 0
lnResult = LogonUser(lcUsername,lcServer,lcPassword,;
                     LOGON32_LOGON_NETWORK,LOGON32_PROVIDER_DEFAULT,@lnToken) 

DECLARE INTEGER CloseHandle IN WIN32API INTEGER
CloseHandle(lnToken)

RETURN IIF(lnResult=1,.T.,.F.)
ENDFUNC
* wwAPI :: LogonUser

FUNCTION GetSystemDir
************************************************************************
* wwAPI :: GetSystemDir
*********************************
***  Function: Returns the Windows System directory path
***      Pass: llWindowsDir - Optional: Retrieve the Windows dir
***    Return: Windows System directory or "" if failed
************************************************************************
LPARAMETER llWindowsDir
LOCAL lcPath, lnSize

lcPath=SPACE(256)

IF !llWindowsDir
	DECLARE INTEGER GetSystemDirectory ;
	   IN Win32API ;
	   STRING  @pszSysPath,;
	   INTEGER cchSysPath
	lnsize=GetSystemDirectory(@lcPath,256) 
ELSE
	DECLARE INTEGER GetWindowsDirectory ;
	   IN Win32API ;
	   STRING  @pszSysPath,;
	   INTEGER cchSysPath
	lnsize=GetWindowsDirectory(@lcPath,256) 
ENDIF 

if lnSize > 0
   RETURN SUBSTR(lcPath,1,lnSize) + "\"
ENDIF
   
RETURN ""
ENDFUNC
* GetSystemDir


FUNCTION GetCurrentThread
************************************************************************
* wwAPI :: GetCurrentThread
*********************************
***  Function: Returns handle to the current Process/Thread
***    Return: Process Handle or 0
************************************************************************
RETURN GetCurrentThread()
ENDFUNC
* GetProcess

************************************************************************
* wwAPI :: GetThreadPriority
*********************************
***  Function: Gets the current Priority setting of the thread.
***            Use to save and reset priority when bumping it up.
***      Pass: tnThreadHandle
************************************************************************
FUNCTION GetThreadPriority
LPARAMETER tnThreadHandle
RETURN GetThreadPriority(tnThreadHandle)
ENDFUNC
* GetThreadPriority

FUNCTION SetThreadPriority
************************************************************************
* wwAPI :: SetThreadPriority
*********************************
***  Function: Sets a thread process priority. Can dramatically
***            increase performance of a task.
***      Pass: tnThreadHandle
***            tnPriority         0 - Normal
***                               1 - Above Normal
***                               2 - Highest Priority
***                              15 - Time Critical
***                              31 - Real Time (doesn't work w/ Win95)
************************************************************************
LPARAMETER tnThreadHandle,tnPriority
RETURN SetThreadPriority(tnThreadHandle,tnPriority)
ENDFUNC
* GetThreadPriority


FUNCTION PlayWave
************************************************************************
* wwapi :: PlayWave
*******************
***     Class: WinAPI
***  Function: Plays the Wave File or WIN.INI
***            [Sounds] Entry specified in the
***            parameter. If the .WAV file or
***            System Sound can't be found,
***            SystemDefault beep is played
***    Assume: Runs only under Windows
***            uses MMSYSTEM.DLL  (Win 3.1)
***                 WINMM.DLL  (32 bit Win)
***      Pass: pcWaveFile - Full path of Wave file
***                         or System Sound Entry
***            pnPlayType - 1 - sound plays in background (default)
***                         0 - sound plays - app waits
***                         2 - No default sound if file doesn't exist
***                         4 - Kill currently playing sound 
***                         8 - Continous  
***                         Values can be added together for combinations
***  Examples:
***    do PlayWav with "SystemQuestion"
***    do PlayWav with "C:\Windows\System\Ding.wav"
***    if PlayWav("SystemAsterisk")
***
***    Return: .t. if Wave was played .f. otherwise
*************************************************************************
LPARAMETER pcWaveFile,pnPlayType
LOCAL lhPlaySnd,llRetVal

pnPlayType=IIF(TYPE("pnPlayType")="N",pnPlayType,1)

llRetVal=.f.

DECLARE INTEGER PlaySound ;
   IN WINMM.dll  ;
   STRING cWave, INTEGER nModule, INTEGER nType

IF PlaySound(pcWaveFile,0,pnPlayType)=1
   llRetVal=.t.
ENDIF

RETURN llRetVal
ENDFUNC
*EOF PLAYWAV


FUNCTION CreateGUID
************************************************************************
* wwapi::CreateGUID
********************
***    Author: Rick Strahl, West Wind Technologies
***            http://www.west-wind.com/
***  Modified: 01/26/98
***  Function: Creates a globally unique identifier using Win32
***            COM services. The vlaue is guaranteed to be unique
***    Format: {9F47F480-9641-11D1-A3D0-00600889F23B}
***    Return: GUID as a string or "" if the function failed 
*************************************************************************
LPARAMETERS llRaw
LOCAL lcStruc_GUID, lcGUID, lnSize

DECLARE INTEGER CoCreateGuid ;
  IN Ole32.dll ;
  STRING @lcGUIDStruc
  
DECLARE INTEGER StringFromGUID2 ;
  IN Ole32.dll ;
  STRING cGUIDStruc, ;
  STRING @cGUID, ;
  LONG nSize
  
*** Simulate GUID strcuture with a string
lcStruc_GUID = REPLICATE(" ",16) 
lcGUID = REPLICATE(" ",80)
lnSize = LEN(lcGUID) / 2
IF CoCreateGuid(@lcStruc_GUID) # 0
   RETURN ""
ENDIF

IF llRaw
   RETURN lcStruc_GUID
ENDIF   

*** Now convert the structure to the GUID string
IF StringFromGUID2(lcStruc_GUID,@lcGuid,lnSize) = 0
  RETURN ""
ENDIF

*** String is UniCode so we must convert to ANSI
RETURN  StrConv(LEFT(lcGUID,76),6)
* Eof CreateGUID

FUNCTION Sleep(lnMilliSecs)
************************************************************************
* wwAPI :: Sleep
*********************************
***  Function: Puts the computer into idle state. More efficient and
***            no keyboard interface than Inkey()
***      Pass: tnMilliseconds
***    Return: nothing
************************************************************************

lnMillisecs=IIF(type("lnMillisecs")="N",lnMillisecs,0)

DECLARE Sleep ;
  IN WIN32API ;
  INTEGER nMillisecs
 	
=Sleep(lnMilliSecs) 	
ENDFUNC
* Sleep

************************************************************************
* wwAPI :: GetLastError
*********************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION GetLastError
DECLARE INTEGER GetLastError IN Win32API 
RETURN GetLastError()
ENDFUNC
* wwAPI :: GetLastError

************************************************************************
* wwAPI :: GetSystemErrorMsg
*********************************
***  Function: Returns the Message text for a Win32API error code.
***      Pass: lnErrorNo  -  WIN32 Error Code
***    Return: Error Message or "" if not found
************************************************************************
FUNCTION GetSystemErrorMsg
LPARAMETERS lnErrorNo,lcDLL
LOCAL szMsgBuffer,lnSize

szMsgBuffer=SPACE(500)

DECLARE INTEGER FormatMessage ;
     IN WIN32API ;
     INTEGER dwFlags ,;
     STRING lpvSource,;
     INTEGER dwMsgId,;
     INTEGER dwLangId,;
     STRING @lpBuffer,;
     INTEGER nSize,;
     INTEGER  Arguments

lnSize=FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM,0,lnErrorNo,;
                     0,@szMsgBuffer,LEN(szMsgBuffer),0)

IF LEN(szMsgBUffer) > 1
  szMsgBuffer=SUBSTR(szMsgBuffer,1, lnSize-1 )
ELSE
  szMsgBuffer=""  
ENDIF
    		   
RETURN szMsgBuffer


ENDDEFINE
*EOC wwAPI


************************************************************************
* wwAPI :: GetSpecialFolder
****************************************
***  Function:
***    Assume: 0x002b -  Common Files
***            0x0026 -  Program Files
***            
***            
***      Pass:
***    Return:
************************************************************************
FUNCTION GetSpecialFolder(lnFolder)

IF VARTYPE(lnFolder) = "C"
   DO CASE
      *** MSDN -  CSIDL flag translates
      CASE lnFolder = "Program Files Common"
         lnFolder = 0x002B
      CASE lnFolder = "Program Files"
         lnFolder = 0x0026
      CASE lnFolder = "Documents Common"
         lnFolder = 0x002E
      CASE  lnFolder == "Documents" OR lnFolder = "Documents User" OR lnFolder = "My Documents"
         lnFolder = 0x0005
      CASE lnFolder = "Send To"
         lnFolder = 0x0009
      CASE lnFolder = "My Computer"
         lnFolder = 0x0011
      CASE lnFolder = "Desktop"
         lnFolder = 0
      CASE lnFolder == "Application Data"
         lnFolder = 0x001A
      CASE lnFolder == "Application Data Common"
         lnFolder = 0x0023
   ENDCASE
ENDIF


DECLARE INTEGER SHGetFolderPath IN Shell32.dll ;
      INTEGER Hwnd, INTEGER nFolder, INTEGER Token, INTEGER Flags, STRING @cPath
      
lcOutput = repl(CHR(0),256)
lnResult = SHGetFolderPath(Application.hWnd,lnFolder,0,0,@lcOutput)
IF lnResult = 0
   lcOutput = STRTRAN(lcOutput,CHR(0),"") + "\"
ELSE
   lcOutput = ""
ENDIF

RETURN lcOutput
ENDFUNC
*  wwAPI :: GetSpecialFolder

************************************************************************
* wwAPI :: CreateShortcut
****************************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION CreateShortcut(lcShortCut,lcDescription, lcTarget,lcArguments,lcStartFolder,lcIcon)


IF !ISCOMOBJECT("wscript.Shell")
   RETURN .f.
ENDIF
   
llError = .f.   
*TRY 
loScript = create("wscript.Shell")
loSc = loScript.createShortCut(lcShortCut)
loSC.Description = lcDescription
loSC.TargetPath = lcTarget

IF !EMPTY(lcArguments)
   loSC.Arguments = lcArguments
ENDIF
IF !EMPTY(lcIcon)
loSC.IconLocation = lcIcon
ENDIF

IF EMPTY(lcStartFolder)
   loSC.WorkingDirectory = JUSTPATH(lcTarget)
ELSE
   loSC.WorkingDirectory = lcStartFolder
ENDIF

loSC.Save()
*CATCH
*   llError = .t.
*ENDTRY

RETURN !llError  
ENDFUNC
*  wwAPI :: CreateShortcut

************************************************************************
FUNCTION GetTimeZone
*********************************
***  Function: Returns the TimeZone offset from GMT including
***            daylight savings. Result is returned in minutes.
************************************************************************

DECLARE integer GetTimeZoneInformation IN Win32API ;
   STRING @ TimeZoneStruct
   
lcTZ = SPACE(256)

lnDayLightSavings = GetTimeZoneInformation(@lcTZ)

lnOffset = CharToBin(SUBSTR(lcTZ,1,4),.T.)

*** Subtract an hour if daylight savings is active
IF lnDaylightSavings = 2
   lnOffset = lnOffset - 60
ENDIF

RETURN lnOffSet


************************************************************************
FUNCTION CharToBin(lcBinString,llSigned)
****************************************
***  Function: Binary Numeric conversion routine. 
***            Converts DWORD or Unsigned Integer string
***            to Fox numeric integer value.
***      Pass: lcBinString -  String that contains the binary data 
***            llSigned    -  if .T. uses signed conversion
***                           otherwise value is unsigned (DWORD)
***    Return: Fox number
************************************************************************
LOCAL m.i, lnWord

lnWord = 0
FOR m.i = 1 TO LEN(lcBinString)
 lnWord = lnWord + (ASC(SUBSTR(lcBinString, m.i, 1)) * (2 ^ (8 * (m.i - 1))))
ENDFOR

IF llSigned AND lnWord > 0x80000000
  lnWord = lnWord - 1 - 0xFFFFFFFF
ENDIF

RETURN lnWord
*  wwAPI :: CharToBin

************************************************************************
FUNCTION BinToChar(lnValue)
****************************************
***  Function: Creates a DWORD value from a number
***      Pass: lnValue - VFP numeric integer (unsigned)
***    Return: binary string
************************************************************************
Local byte(4)
If lnValue < 0
    lnValue = lnValue + 4294967296
EndIf
byte(1) = lnValue % 256
byte(2) = BitRShift(lnValue, 8) % 256
byte(3) = BitRShift(lnValue, 16) % 256
byte(4) = BitRShift(lnValue, 24) % 256
RETURN Chr(byte(1))+Chr(byte(2))+Chr(byte(3))+Chr(byte(4))
*  wwAPI :: BinToChar

************************************************************************
FUNCTION BinToWordChar(lnValue)
****************************************
***  Function: Creates a DWORD value from a number
***      Pass: lnValue - VFP numeric integer (unsigned)
***    Return: binary string
************************************************************************
RETURN Chr(MOD(m.lnValue,256)) + CHR(INT(m.lnValue/256))


************************************************************************
* wwAPI :: FindWindow
****************************************
***  Function: Returns a Window Handle for a window on the desktop
************************************************************************
FUNCTION FindWindow(lcTitle)
DECLARE INTEGER FindWindow IN WIN32API AS __FindWindow integer Handle, STRING Title
RETURN __FindWindow(0,lcTitle)
ENDFUNC



#IF wwVFPVersion > 7
************************************************************************
* wwAPI :: HashMD5
****************************************
***  Function: retrieved from the FoxWiki
*** 		   http://fox.wikis.com/wc.dll?fox~vfpmd5hashfunction
***    Assume: Self standing function - not part of wwAPI class
***      Pass: Data to encrypt
***    Return: 
************************************************************************
FUNCTION HashMD5(tcData)

*** #include "c:\program files\microsoft visual foxpro 8\ffc\wincrypt.h"
#DEFINE dnPROV_RSA_FULL           1
#DEFINE dnCRYPT_VERIFYCONTEXT     0xF0000000

#DEFINE dnALG_CLASS_HASH         BITLSHIFT(4,13)
#DEFINE dnALG_TYPE_ANY 		 0
#DEFINE dnALG_SID_MD5           3
#DEFINE dnCALG_MD5        BITOR(BITOR(dnALG_CLASS_HASH,dnALG_TYPE_ANY),dnALG_SID_MD5)

#DEFINE dnHP_HASHVAL              0x0002  && Hash value

LOCAL lnStatus, lnErr, lhProv, lhHashObject, lnDataSize, lcHashValue, lnHashSize
lhProv = 0
lhHashObject = 0
lnDataSize = LEN(tcData)
lcHashValue = REPLICATE(CHR(0), 16)
lnHashSize = LEN(lcHashValue)


DECLARE INTEGER GetLastError ;
   IN win32api AS GetLastError

DECLARE INTEGER CryptAcquireContextA ;
   IN WIN32API AS CryptAcquireContext ;
   INTEGER @lhProvHandle, ;
   STRING cContainer, ;
   STRING cProvider, ;
   INTEGER nProvType, ;
   INTEGER nFlags

* load a crypto provider
lnStatus = CryptAcquireContext(@lhProv, 0, 0, dnPROV_RSA_FULL, dnCRYPT_VERIFYCONTEXT)
IF lnStatus = 0
   THROW GetLastError()
ENDIF

DECLARE INTEGER CryptCreateHash ;
   IN WIN32API AS CryptCreateHash ;
   INTEGER hProviderHandle, ;
   INTEGER nALG_ID, ;
   INTEGER hKeyhandle, ;
   INTEGER nFlags, ;
   INTEGER @hCryptHashHandle

* create a hash object that uses MD5 algorithm
lnStatus = CryptCreateHash(lhProv, dnCALG_MD5, 0, 0, @lhHashObject)
IF lnStatus = 0
   THROW GetLastError()
ENDIF

DECLARE INTEGER CryptHashData ;
   IN WIN32API AS CryptHashData ;
   INTEGER hHashHandle, ;
   STRING @cData, ;
   INTEGER nDataLen, ;
   INTEGER nFlags

* add the input data to the hash object
lnStatus = CryptHashData(lhHashObject, tcData, lnDataSize, 0)
IF lnStatus = 0
   THROW GetLastError()
ENDIF


DECLARE INTEGER CryptGetHashParam ;
   IN WIN32API AS CryptGetHashParam ;
   INTEGER hHashHandle, ;
   INTEGER nParam, ;
   STRING @cHashValue, ;
   INTEGER @nHashSize, ;
   INTEGER nFlags

* retrieve the hash value, if caller did not provide enough storage (16 bytes for MD5)
* this will fail with dnERROR_MORE_DATA and lnHashSize will contain needed storage size
lnStatus = CryptGetHashParam(lhHashObject, dnHP_HASHVAL, @lcHashValue, @lnHashSize, 0)
IF lnStatus = 0
   THROW GetLastError()
ENDIF


DECLARE INTEGER CryptDestroyHash ;
   IN WIN32API AS CryptDestroyHash;
   INTEGER hKeyHandle

*** free the hash object
lnStatus = CryptDestroyHash(lhHashObject)
IF lnStatus = 0
   THROW GetLastError()
ENDIF


DECLARE INTEGER CryptReleaseContext ;
   IN WIN32API AS CryptReleaseContext ;
   INTEGER hProvHandle, ;
   INTEGER nReserved

*** release the crypto provider
lnStatus = CryptReleaseContext(lhProv, 0)
IF lnStatus = 0
   THROW GetLastError()
ENDIF

RETURN lcHashValue
ENDFUNC
* HashMD5
#ENDIF




************************************************************************
FUNCTION ResizeImage(lcSource,lcTarget,lnWidth,lnHeight,lnCompression)
****************************************
***  Function: Creates a Thumbnail image from a file into another file
***    Assume:
***      Pass:
***    Return:
************************************************************************

IF EMPTY(lnCompression)
  lnCompression = -1
ENDIF
IF lnCompression > 100 OR lnCompression < -1
   lnCompression = -1
ENDIF

DECLARE INTEGER ResizeImage IN wwImaging.dll AS _ResizeImage;
   STRING lcSource, STRING lcTarget, INTEGER lnWidth, INTEGER lnHeight, INTEGER lnCompression
   
RETURN (IIF(_ResizeImage(STRCONV(FULLPATH(lcSource)+CHR(0),5),;
                             STRCONV(LOWER(FULLPATH(lcTarget))+CHR(0),5),;
                             lnWidth,lnHeight,lnCompression)=1,.T.,.F.))

************************************************************************
FUNCTION CopyImage(lcSource,lcTarget)
****************************************
***  Function: Copies an image from one format to another
***    Assume:
***      Pass:
***    Return:
************************************************************************

IF LOWER(JUSTEXT(lcTarget)) = "gif"  
   DECLARE INTEGER SaveImageToGif IN wwImaging.dll as _SaveImageAsGif ;
                   STRING lcSource, STRING lcTarget
    RETURN (IIF(_SaveImageAsGif(STRCONV(FULLPATH(lcSource)+CHR(0),5),;
                           STRCONV(FULLPATH(lcTarget)+CHR(0),5))=1,.T.,.F.))
ELSE
    DECLARE INTEGER CopyImageEx IN wwImaging.dll AS _CopyImage ;
                    STRING lcSource, STRING lcTarget

    RETURN (IIF(_CopyImage(STRCONV(FULLPATH(lcSource)+CHR(0),5),;
                           STRCONV(LOWER(FULLPATH(lcTarget))+CHR(0),5))=1,.T.,.F.))
ENDIF

                             
************************************************************************
FUNCTION CreateThumbNail(lcSource,lcTarget,lnWidth,lnHeight)
****************************************
***  Function: Creates a Thumbnail image from a file into another file
***    Assume:
***      Pass:
***    Return:
************************************************************************

DECLARE INTEGER CreateThumbnail IN wwImaging.dll AS _CreateThumbnail;
   STRING lcSource, STRING lcTarget, INTEGER lnWidth, INTEGER lnHeight
   
RETURN (IIF(_CreateThumbnail(STRCONV(FULLPATH(lcSource)+CHR(0),5),;
                             STRCONV(FULLPATH(lcTarget)+CHR(0),5),;
                             lnWidth,lnHeight)=1,.T.,.F.))

************************************************************************
FUNCTION GetImageInfo(lcImage,lnWidth,lnHeight,lnResolution)
****************************************
***  Function: Returns Width, Height and Resolution of an image
***    Assume:
***      Pass: Pass the last 3 parameters in by Reference
***    Return:
************************************************************************

DECLARE INTEGER GetImageInfo IN wwImaging.dll AS _GetImageInfo;
   STRING lcSource, INTEGER@ lnWidth, INTEGER@ lnHeight, INTEGER@ lnResolution
   
lnWidth = 0
lnHeight = 0
lnResolution = 0

RETURN IIF(;
 _GetImageInfo(STRCONV(FULLPATH(lcImage) +CHR(0) ,5),;
              @lnWidth,@lnHeight,@lnResolution) = 1,.T.,.F.)

ENDFUNC
* GetImageInfo

************************************************************************
FUNCTION RotateImage(lcImage,lnFlipType)
****************************************
***  Function: Returns Width, Height and Resolution of an image
***    Assume:
***      Pass: lcImage    - Image file to convert in place
***            lnFlipType - Type of rotation or flip to perform
***                         1  -   Rotate 90 degrees
***                         2  -   Rotate 180 degrees
***                         3  -   Rotate 270 degrees
***                         4  -   Flip Image (mirror image)
***                         5  -   Flip Image and Rotate 90 degrees
***                         6  -   Flip Image and Rotate 180 degrees
***                         7  -   Flip Image and Rotate 270 degrees
***    Return:
************************************************************************

DECLARE INTEGER RotateImage IN wwImaging.dll AS _RotateImage ;
   STRING lcSource, INTEGER FlipType   
RETURN IIF(;
 _RotateImage(STRCONV(FULLPATH(lcImage) +CHR(0) ,5),;
              @lnFlipType) = 1,.T.,.F.)
ENDFUNC
* GetImageInfo


************************************************************************
* wwAPI :: WriteImage
****************************************
***  Function: Writes one image into another
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION WriteImage(lcSource, lcInsert, lnLeft, lnTop, llNonOpaque)

DECLARE INTEGER WriteImage IN wwImaging.dll AS _WriteImage ;
   STRING lcSource, string lcInsert, ;
   INTEGER lnLeft, INTEGER lnTop, INTEGER lnOpaque
   
RETURN IIF(;
 _WriteImage(STRCONV(FULLPATH(lcSource) +CHR(0),5),;
			    STRCONV(FULLPATH(lcInsert) +CHR(0),5),;
             lnLeft, lnTop,IIF(llNonOpaque,0,1)) = 1,.T.,.F.)

ENDFUNC
*  wwAPI :: WriteImage

************************************************************************
* wwAPI :: ReadImage
****************************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION ReadImage(lcSource, lcTarget, lnLeft, lnTop, lnWidth, lnHeight)

DECLARE INTEGER ReadImage IN wwImaging.dll AS _ReadImage ;
   STRING lcSource, STRING lcTarget, INTEGER lnLeft, INTEGER lnTop, ;
   INTEGER lnWidth, INTEGER lnHeight
   
RETURN IIF(;
 _ReadImage(STRCONV(FULLPATH(lcSource) +CHR(0),5),;
			 STRCONV(FULLPATH(lcTarget) +CHR(0),5),;
             lnLeft, lnTop, lnWidth, lnHeight) = 1,.T.,.F.)
ENDFUNC
*  wwAPI :: ReadImage

************************************************************************
* wwAPI ::  GetCaptchaImage
****************************************
***  Function: Returns an image for the given text
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION GetCaptchaImage(lcText,lcOutputFile,lcFont,lnFontSize)

IF EMPTY(lcFont)
   lcFont = "Arial"
ENDIF
IF EMPTY(lnFontSize)
   lnFontSize = 28
ENDIF      

DECLARE INTEGER GetCaptchaImage ;
   IN wwImaging.dll  as _GetCaptchaImage ;
   STRING Text,  STRING FONTNAME, integer FontSize, STRING lcOutputFile

lcText = STRCONV(lcText,5) + CHR(0)
lcFont = STRCONV(lcFont,5) + CHR(0)
lcOutputFile = STRCONV(lcOutputFile,5) + CHR(0)   
   
RETURN IIF( _GetCaptchaImage(lcText,lcFont,lnFontSize,lcOutputFile) = 1,;
           .T.,.F.)
ENDFUNC
*  wwAPI ::  GetCaptchaImage


************************************************************************
* wwAPI :: CreateprocessEx
****************************************
***  Function: Calls the CreateProcess API to run a Windows application
***    Assume: Gets around RUN limitations which has command line
***            length limits and problems with long filenames.
***            Can do Redirection
***            Requires wwIPStuff.dll to run!
***      Pass: lcExe - Name of the Exe
***            lcCommandLine - Any command line arguments
***    Return: .t. or .f.
************************************************************************
FUNCTION CreateProcessEx(lcExe,lcCommandLine,lcStartDirectory,;
                         lnShowWindow,llWaitForCompletion,lcStdOutputFilename)

DECLARE INTEGER wwCreateProcess IN wwIPStuff.DLL AS _wwCreateProcess  ;
   String lcExe, String lcCommandLine, INTEGER lnShowWindow,;
   INTEGER llWaitForCompletion, STRING lcStartupDirectory, STRING StdOutFile
   
IF EMPTY(lcStdOutputFileName)
  lcStdOutputFileName = NULL
ENDIF
IF EMPTY(lcStartDirectory)
  lcStartDirectory = CHR(0)
ENDIF

IF !EMPTY(lcCommandLine)
   lcCommandLine = ["] + lcExe + [" ]+ lcCommandLine
ELSE
   lcCommandLine = ""
ENDIF

IF llWaitForCompletion
   lnWait = 1
ELSE
   lnWait = 0
ENDIF
IF EMPTY(lnShowWindow)
   lnShowWindow = 4
ENDIF   

lnResult = _wwCreateProcess(lcExe,lcCommandLine,lnShowWindow,lnWait,lcStartDirectory,lcStdOutputFileName)
   
RETURN IIF(lnResult == 1, .t. , .f.)
ENDFUNC

************************************************************************
* wwAPI :: Createprocess
****************************************
***  Function: Calls the CreateProcess API to run a Windows application
***    Assume: Gets around RUN limitations which has command line
***            length limits and problems with long filenames.
***            Can do everything EXCEPT REDIRECTION TO FILE!
***      Pass: lcExe - Name of the Exe
***            lcCommandLine - Any command line arguments
***    Return: .t. or .f.
************************************************************************
FUNCTION Createprocess(lcExe,lcCommandLine,lnShowWindow,llWaitForCompletion)
LOCAL hProcess, cProcessInfo, cStartupInfo

DECLARE INTEGER CreateProcess IN kernel32 as _CreateProcess; 
    STRING   lpApplicationName,; 
    STRING   lpCommandLine,; 
    INTEGER  lpProcessAttributes,; 
    INTEGER  lpThreadAttributes,; 
    INTEGER  bInheritHandles,; 
    INTEGER  dwCreationFlags,; 
    INTEGER  lpEnvironment,; 
    STRING   lpCurrentDirectory,; 
    STRING   lpStartupInfo,; 
    STRING @ lpProcessInformation 

 
cProcessinfo = REPLICATE(CHR(0),128)
cStartupInfo = GetStartupInfo(lnShowWindow)

IF !EMPTY(lcCommandLine)
   lcCommandLine = ["] + lcExe + [" ]+ lcCommandLine
ELSE
   lcCommandLine = ""
ENDIF

lnResult =  _CreateProcess(lcExe,lcCommandLine,0,0,1,0,0,;
                           SYS(5)+CURDIR(),cStartupInfo,@cProcessInfo)

lhProcess = CHARTOBIN( SUBSTR(cProcessInfo,1,4) )

IF llWaitForCompletion
   #DEFINE WAIT_TIMEOUT 0x00000102
   DECLARE INTEGER WaitForSingleObject IN kernel32.DLL ;
         INTEGER hHandle, INTEGER dwMilliseconds

   DO WHILE .T.
       *** Update every 100 milliseconds
       IF WaitForSingleObject(lhProcess, 100) != WAIT_TIMEOUT
          EXIT
        ELSE
           DOEVENTS
        ENDIF
   ENDDO
ENDIF


DECLARE INTEGER CloseHandle IN kernel32.DLL ;
        INTEGER hObject

CloseHandle(lhProcess)

RETURN IIF(lnResult=1,.t.,.f.)

FUNCTION getStartupInfo(lnShowWindow)
LOCAL lnFlags
* creates the STARTUP structure to specify main window
* properties if a new window is created for a new process

IF EMPTY(lnShowWindow)
  lnShowWindow = 1
ENDIF
  
*| typedef struct _STARTUPINFO {
*| DWORD cb; 4
*| LPTSTR lpReserved; 4
*| LPTSTR lpDesktop; 4
*| LPTSTR lpTitle; 4
*| DWORD dwX; 4
*| DWORD dwY; 4
*| DWORD dwXSize; 4
*| DWORD dwYSize; 4
*| DWORD dwXCountChars; 4
*| DWORD dwYCountChars; 4
*| DWORD dwFillAttribute; 4
*| DWORD dwFlags; 4
*| WORD wShowWindow; 2
*| WORD cbReserved2; 2
*| LPBYTE lpReserved2; 4
*| HANDLE hStdInput; 4
*| HANDLE hStdOutput; 4
*| HANDLE hStdError; 4
*| } STARTUPINFO, *LPSTARTUPINFO; total: 68 bytes

#DEFINE STARTF_USESTDHANDLES 0x0100
#DEFINE STARTF_USESHOWWINDOW 1
#DEFINE SW_HIDE 0
#DEFINE SW_SHOWMAXIMIZED 3
#DEFINE SW_SHOWNORMAL 1

lnFlags = STARTF_USESHOWWINDOW

RETURN binToChar(80) +;
    binToChar(0) + binToChar(0) + binToChar(0) +;
    binToChar(0) + binToChar(0) + binToChar(0) + binToChar(0) +;
    binToChar(0) + binToChar(0) + binToChar(0) +;
    binToChar(lnFlags) +;
    binToWordChar(lnShowWindow) +;
    binToWordChar(0) + binToChar(0) +;
    binToChar(0) + binToChar(0) + binToChar(0) + REPLICATE(CHR(0),30)


************************************************************************
* Sleep
****************************************
***  Function: Suspends the current thread for x number of 
***            milliseconds.
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION WinAPI_Sleep(lnMilliSecs)

lnMillisecs=IIF(type("lnMillisecs")="N",lnMillisecs,0)

DECLARE Sleep ;
  IN WIN32API ;
  INTEGER nMillisecs
    
=Sleep(lnMilliSecs)    
ENDFUNC
* WinApi_Sleep

************************************************************************
* wwAPI :: Win32_GetSystemTime
****************************************
***  Function: Returns the System local time (in UTC format)
***            for the current time
***    Assume:
***      Pass: 
***    Return:
************************************************************************
FUNCTION Win32_GetSystemTime()
LOCAL lnYear, lnMonth, lnDay, lnHour, lnMinute, lnSecond, lcBuffer

DECLARE INTEGER GetSystemTime IN win32api STRING @
lcBuffer=SPACE(40)
=GetSystemTime(@lcBuffer)

#IF wwVFPVersion > 8
   lnYear = CTOBIN( SUBSTR(lcBuffer,1,2),"RS2")
   lnMonth = CTOBIN( SUBSTR(lcBuffer,3,2),"RS2")
   lnDay = CTOBIN( SUBSTR(lcBuffer,7,2),"RS2")

   lnHour = CTOBIN( SUBSTR(lcBuffer,9,2),"RS2")
   lnMinute = CTOBIN( SUBSTR(lcBuffer,11,2),"RS2")
   lnSecond = CTOBIN( SUBSTR(lcBuffer,13,2),"RS2")
#ELSE
   lnYear = CharToBin( SUBSTR(lcBuffer,1,2))
   lnMonth = CharToBin( SUBSTR(lcBuffer,3,2))
   lnDay = CharToBin( SUBSTR(lcBuffer,7,2))

   lnHour = CharToBin( SUBSTR(lcBuffer,9,2))
   lnMinute = CharToBin( SUBSTR(lcBuffer,11,2))
   lnSecond = CharToBin( SUBSTR(lcBuffer,13,2))
#ENDIF

lcTime = "{^" + TRANSFORM(lnYear) + "-" + ;
         TRANSFORM(lnMonth) + "-" + ;
         TRANSFORM(lnDay) + " " +;
         TRANSFORM(lnHour) + ":" +;
         TRANSFORM(lnMinute) + ":" + ;
         TRANSFORM(lnSecond) + "}"

RETURN  EVALUATE(lcTime)

************************************************************************
* wwAPI :: WinApi_ActivateWindow
****************************************
***  Function: Activates the 
***    Assume:
***      Pass: lcTitle - Exact Window Title or Window Handle Number
***    Return:
************************************************************************
FUNCTION ActivateWindow(lcTitle,lnParentHandle)

IF VARTYPE(lcTitle) = "C"
   IF EMPTY(lnParentHandle)
      lnParentHandle = 0
   ENDIF
   
   DECLARE INTEGER FindWindow ;
      IN WIN32API ;
      STRING cNull,STRING cWinName

   lnHandle = FindWindow(lnParentHandle,lcTitle)
ELSE
   lnHandle = lcTitle
ENDIF

DECLARE INTEGER SetForegroundWindow ;
      IN WIN32API INTEGER

SetForegroundWindow(lnHandle)

RETURN
ENDFUNC
*  wwAPI :: WinApi_ActivateWindow



************************************************************************
* InstallPrinterDriver
*********************************************
***  Function: Installs a Windows Printer driver from the stock
*** 		   Windows driver library
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION InstallPrinterDriver(lcDriverName,lcPrinterName)
LOCAL lcOs, llResult

IF EMPTY(lcDriverName)
 *** This color PS driver exists under Win2003, Vista and XP
 lcDriverName = "Xerox Phaser 1235 PS"
 * lcDriverName = "Apple Color LW 12/660 PS"
ENDIF
IF EMPTY(lcPrinterName)
  lcPrinterName = lcDriverName
ENDIF  
LOCAL ARRAY laPrinters[1]

lnCount = APRINTERS(laPrinters)
FOR lnX = 1 TO lnCount
   IF LOWER(lcPrinterName) == LOWER(laPrinters[lnX,1])
      RETURN .t.
   ENDIF
ENDFOR   

lcOS = "Windows 2000 or XP"
IF OS(3) = "6"  && Vista requires XP setting
   lcOS = "Windows XP"
ENDIF

loAPI = CREATEOBJECT("wwAPI")
lcExe = loAPI.GetSystemDir() + "rundll32.exe"
lcCmdLine = [printui.dll,PrintUIEntry /ia /m "] + lcDriverName + [" /h "Intel" /v "] + lcOS + [" /f "] + loAPI.GetSystemDir(.t.)+ [inf\ntprint.inf" /u"]

llResult = CreateProcess(lcExe,lcCmdLine,2,.t.)
IF !llResult
   RETURN .F.
ENDIF   

lcCmdLine = [printui.dll,PrintUIEntry /if /b "] + lcPrinterName + [" /f "] + loAPI.GetSystemDir(.T.) + [inf\ntprint.inf" /r "lpt1:" /m "] + lcDriverName + ["]

llResult = CreateProcess(lcExe,lcCmdLine,2,.t.)
IF !llResult
   RETURN .F.
ENDIF   

RETURN .T.

************************************************************************
* wwAPI :: WinApi_SendMessage
****************************************
***  Function: SendMessage API call - straight through
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION WinApi_SendMessage(lnHwnd,lnMsg,lnWParam,lnLParam)

DECLARE integer SendMessage IN WIN32API ;
        integer hWnd,integer Msg,;
        integer wParam,;
        Integer lParam

RETURN SendMessage(lnHwnd,lnMsg,lnWParam,lnLParam)
ENDFUNC  

************************************************************************
* wwAPI :: WinApi_FindWindowEx
****************************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION WinApi_FindWindowEx(lnParentHwnd,lnHwndLastChild,lcClass,lcTitle)

  IF EMPTY(lcClass)
     lcClass = NULL
  ENDIF
  IF EMPTY(lcTitle)
     lcTitle = NULL
  ENDIF
  IF EMPTY(lnHwndLastChild)
    lnHwndLastChild = 0
  ENDIF
  
  declare integer FindWindowEx in Win32API;
       integer, integer, string, string

RETURN FindWindowEx(lnParentHwnd,lnHwndLastChild,lcClass,lcTitle)
ENDFUNC

************************************************************************
* wwAPI :: WinApi_GetClassName
****************************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION WinApi_GetClassName(lnHwnd)

 declare integer GetClassName in Win32API ;
  integer lnhWnd, string @lpClassName, integer lnMaxCount

   lnBuffer   = 255
   lcBuffer   = space(lnBuffer)
   lnBuffer   = GetClassName(lnhWnd, @lcBuffer, lnBuffer)
   IF lnBuffer > 0
      RETURN left(lcBuffer, lnBuffer - 1)
   ENDIF
   
   RETURN ""
ENDFUNC

************************************************************************
* wwAPI :: WinApi_CallWindowProc
****************************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION WinApi_CallWindowProc(lpLastWinProc,lnHwnd,lnMsg,lnWParam,lnLParam)
declare integer CallWindowProc in Win32API ;
         integer lpPrevWndFunc, integer hWnd, integer Msg,;
         integer wParam, integer lParam

RETURN CallWindowProc(lhLastWinProc,lnHwnd,lnMsg,lnWParam,lnLParam)
ENDFUNC    

************************************************************************
* wwAPI :: WinApi_GetWindowLong
****************************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION WinApi_GetWindowLong(lnHwnd,lnIndex)
   declare integer GetWindowLong in Win32API ;
         integer hWnd, integer nIndex

   IF VARTYPE(lnIndex) # "N"
      lnIndex = -4  &&GWL_WNDPROC  
   ENDIF

RETURN GetWindowLong(lnHwnd,lnIndex)        
ENDFUNC
*  wwAPI :: WinApi_GetWindowLong     

************************************************************************
* wwAPI :: Sleep
*********************************
***  Function: Puts the computer into idle state. More efficient and
***            no keyboard interface than Inkey()
***      Pass: tnMilliseconds
***    Return: nothing
************************************************************************
FUNCTION Sleep(lnMilliSecs)

lnMillisecs=IIF(type("lnMillisecs")="N",lnMillisecs,0)

DECLARE Sleep ;
  IN WIN32API ;
  INTEGER nMillisecs
 	
=Sleep(lnMilliSecs) 	
ENDFUNC


************************************************************************
* wwAPI ::  GetMonitorStatistics
****************************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION GetMonitorStatistics()

#DEFINE SM_XVIRTUALSCREEN 76
#DEFINE SM_YVIRTUALSCREEN 77
#DEFINE SM_CXVIRTUALSCREEN 78
#DEFINE SM_CYVIRTUALSCREEN 79
#DEFINE SM_CMONITORS 80
#DEFINE SM_CXFULLSCREEN 16
#DEFINE SM_CYFULLSCREEN 17


DECLARE INTEGER GetSystemMetrics IN user32 INTEGER nIndex

loMonitor = CREATEOBJECT("EMPTY")
ADDProperty( loMonitor,"Monitors",GetSystemMetrics(SM_CMONITORS) )
ADDPROPERTY( loMonitor,"VirtualWidth",GetSystemMetrics(SM_CXVIRTUALSCREEN) )
ADDPROPERTY( loMonitor,"VirtualHeight",GetSystemMetrics(SM_CYVIRTUALSCREEN) )
ADDPROPERTY( loMonitor,"ScreenHeight",GetSystemMetrics(SM_CYFULLSCREEN) )
ADDPROPERTY( loMonitor,"ScreenWidth",GetSystemMetrics(SM_CXFULLSCREEN) )

RETURN loMonitor
ENDFUNC
*  wwAPI ::  GetMonitorStatistics



************************************************************************
* wwAPI ::  GZipCompressString
****************************************
***  Function: Compresses a string using GZip
***    Assume: Requires ZLIB1.DLL 
***      Pass:
***    Return:
************************************************************************
FUNCTION GZipCompressString(lcString,lnCompressionLevel)
LOCAL lcOutput, lcOutFile,lcInFile, lnHandle

*** 1 - 9
IF EMPTY(lnCompressionLevel)
   lnCompressionLevel = -1  && Default
ENDIF

*** Must write to files
lcOutFile = SYS(2023) + SYS(2015) + ".gz"
lcInFile = lcOutFile + ".in"

*** Failure to write the file
IF !FILE2VAR(lcInFile,lcString)
   RETURN ""
ENDIF

IF !VARTYPE(_GZipLoaded) = "L"
	GzipLibraries()
ENDIF

TRY
   lnHandle = gzopen(lcOutFile,"wb")
   IF (lnHandle < 0)
      RETURN ""
   ENDIF

   *** Set the compression level
   gzsetparams(lnHandle,lnCompressionLevel,0)

   gzwrite(lnHandle,lcString,LEN(lcString))
   gzclose(lnHandle)
CATCH
   IF lnHandle > -1
      gzclose(lnHandle)
   ENDIF
ENDTRY

lcOutput = FILETOSTR(lcOutFile)

ERASE (lcOutFile)
ERASE (lcInFile)

RETURN lcOutput


************************************************************************
* wwAPI ::  GZipUncompressString
****************************************
***  Function: Uncompresses a GZip string
***    Assume: INCORRECT IMPLEMENTATION - ZLib Format
***      Pass:
***    Return:
************************************************************************
FUNCTION GZipUncompressString(lcCompressed,llIsFile)

lcOutFile = SYS(2023) + SYS(2015) + ".gz"
IF llIsFile
   lcInFile = lcCompressed
ELSE
   lcInFile = lcOutFile
   FILE2VAR(lcOutFile,lcCompressed)
ENDIF

IF !VARTYPE(_GZipLoaded) = "L"
	GzipLibraries()
ENDIF

lcOutput = ""
TRY
   lnHandle = gzopen(lcInFile,"rb")
   IF (lnHandle < 1)
      RETURN ""
   ENDIF

   lcOutput = ""
   DO WHILE .T.
      lcBuffer = SPACE(65535)
      lnResult = gzread(lnHandle,@lcBuffer,LEN(lcBuffer))
      IF lnResult < 1
         EXIT
      ENDIF
      lcOutput = lcOutput + LEFT(lcBuffer,lnResult)
   ENDDO
CATCH
   * Nothing
FINALLY
   gzclose(lnHandle)
ENDTRY

RETURN lcOutput
* eof GZipUncompressString

************************************************************************
* wwApi ::  GzipLibraries
****************************************
***  Function:
***    Assume:
***      Pass:
***    Return:
************************************************************************
FUNCTION GzipLibraries()

PUBLIC _GZipLoaded
_GZipLoaded=.T.

* Opens file for writing
DECLARE LONG gzopen IN zlib1.dll ;
   STRING @ zFile ,;
   STRING @ zMode

* Writes data from a compressed file - gzip
DECLARE LONG gzwrite IN zlib1.dll ;
   LONG FILE ,;
   STRING @ uncompr,;
   LONG uncomprLen

*** Set options on the compression
DECLARE LONG gzsetparams IN zlib1.DLL ;
   LONG  gzFile,;
   INTEGER LEVEL,;
   INTEGER strategy

DECLARE LONG gzread IN zlib1.dll  ;
   LONG gzFile,;
   STRING @ buf,;
   LONG LEN

* Closes the file
DECLARE LONG gzclose IN zlib1.dll ;
   LONG FILE

RETURN

