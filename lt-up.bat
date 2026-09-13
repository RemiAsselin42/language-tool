@echo off
cd /d "%~dp0"

rem Serveur deja lance ?
curl -s -o NUL http://localhost:8081/v2/languages && exit

rem Demarre LanguageTool en natif (javaw = invisible)
start "" javaw -Xms128m -Xmx512m -XX:+UseSerialGC -cp "%~dp0server\languagetool-server.jar" org.languagetool.server.HTTPServer --port 8081 --allow-origin --config "%~dp0server.properties"
exit
