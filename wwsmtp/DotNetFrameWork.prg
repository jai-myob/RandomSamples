FUNCTION DotNetFramework
* Returns the path to the .NET Framework directory 
* on the user's system.

* Where more than one version of .NET is installed, 
* returns the highest. If both 32- and 64-bit versions 
* are present, returns the highest overall version. 
* If no version of .NET is installed, returns an empty 
* string.

LOCAL lcWinDir, lcFr32, lcVer32, lcFr64, lcVer64

* Path to Windows directory
lcWinDir = GETENV("windir")

* Path to 32-bit parent framework directory
lcFr32 = ADDBS(lcWinDir) + "Microsoft.NET\Framework"

* Path to highest 32-bit framework version
lcVer32 = HighestDir(lcFr32)

* Path to 64-bit parent framework directory
lcFr64 = lcFr32 + "64"

* Path to highest 64-bit framework version
lcVer64 = HighestDir(lcFr64)

* Return whichever of the two (32-bit or 
* 64-bit path) has the higher verion (for this
* purpose, disregard anything after the second dot)
RETURN IIF(VAL(SUBSTR(JUSTFNAME(lcVer32), 2)) > ;
   VAL(SUBSTR(JUSTFNAME(lcVer64),2)), ;
    lcVer32, lcVer64)

FUNCTION HighestDir
* Given the path to the Microsoft.NET\Framework directory,
* return the path to the directory below it which contains
* the highest Framework version number, or an empty string 
* if none present.
LPARAMETERS tcPath

LOCAL lnCount, lcHighestDir, lnHighestVer
LOCAL lcName, lnVer, lnI
LOCAL ARRAY laFolders(1)

* Get contents of the passed-in directory 
* (including sub-directories) into an array
lnCount = ADIR(laFolders, ADDBS(tcPath) + "*.*", "D")

lcHighestDir = ""
lnHighestVer = 0

FOR lnI = 1 TO lnCount
  IF AT("D", laFolders(lnI, 5)) > 0
    * Array element is a directory name

      * Look for directories whose name starts with "v" 
      * followed by a digit and contains at least one dot
      lcName = LOWER(laFolders(lnI, 1))
      IF LEFT(lcName, 1) = "v" AND ;
        ISDIGIT(SUBSTR(lcName,2,1)) AND AT(".", lcName) > 0
        * Extract its version number (for this purpose, 
        * disregard anything after the second dot)
        lnVer = VAL(SUBSTR(lcName, 2))
        IF lnVer > lnHighestVer
          lnHighestVer = lnVer
          lcHighestDir = lcName
        ENDIF
      ENDIF
  ENDIF
ENDFOR

RETURN ;
  IIF(lnHighestVer=0, "", FORCEPATH(lcHighestDir, tcPath))

*If you only want to know the version number, you can parse it out from the value returned from the function, like so:
*lcFrameworkFolder = DotNetFramework()
*lcVersion = SUBSTR(JUSTFNAME(lcFrameworkFolder), 2)