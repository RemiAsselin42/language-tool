// Starts lt-watch.bat with no window; run at login by the Startup shortcut that setup.ps1 creates.
// Windows Script Host JScript, not VBScript: Windows is retiring VBScript.
var dir = WScript.ScriptFullName.replace(/[^\\]*$/, "");
new ActiveXObject("WScript.Shell").Run('"' + dir + 'lt-watch.bat"', 0, false);
