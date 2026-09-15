# Publicação na Google Play Store

O aplicativo usa o identificador definitivo `br.com.mierzva.romaneiotoras`.

## 1. Criar a chave de upload no Windows

No PowerShell, execute:

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\upload-keystore.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Guarde o arquivo `upload-keystore.jks` e suas senhas em local seguro. Sem eles, futuras atualizações do aplicativo podem ficar bloqueadas. Nunca envie a chave ou as senhas ao GitHub.

## 2. Configurar a assinatura

Copie `android/key.properties.example` para `android/key.properties` e substitua os valores de exemplo pelos dados reais da chave.

O arquivo real `android/key.properties` e arquivos de chave estão ignorados pelo Git.

## 3. Verificar o projeto

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
```

## 4. Gerar o Android App Bundle

```powershell
flutter build appbundle
```

O arquivo para enviar à Play Console será criado em:

```text
build\app\outputs\bundle\release\app.aab
```

Ative o Play App Signing ao criar a primeira versão na Play Console.
