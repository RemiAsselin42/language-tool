# languagetool-local

Serveur LanguageTool natif + démarrage auto avec Zen.

## Installation (nouvelle machine)
1. `winget install -e --id EclipseAdoptium.Temurin.21.JRE`
2. Télécharger https://languagetool.org/download/LanguageTool-stable.zip
   et dézipper son contenu directement dans `server/` (le jar à `server/languagetool-server.jar`)
3. `curl.exe -L -o fasttext/lid.176.bin https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin`
4. Créer `server.properties` (chemins absolus locaux, doubles backslashes) :
   fasttextBinary=...\\fasttext\\fasttext.exe
   fasttextModel=...\\fasttext\\lid.176.bin
5. Raccourci vers `lt-watch.vbs` dans `shell:startup` (Win+R)
6. Extension LanguageTool : cocher "Serveur local"
