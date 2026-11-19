# Digital Shelf — Rastreador de Promoções & Backlog Gamer

Aplicativo Flutter (`digital_shelf`, versão `1.0.0+1`) em português (PT-BR) construído com a arquitetura **MVVM** para buscar promoções reais de jogos de PC na API pública **CheapShark** e gerenciar a estante/backlog pessoal vinculada à conta do jogador.

---

## 1. Arquitetura MVVM e Estrutura de Pastas

O fluxo de dependências respeita rigorosamente a direção `View -> ViewModel -> Repository -> Service`:

```text
lib/
├── core/
│   ├── errors/app_exception.dart        # Exceções de domínio tipadas (timeout, rede, servidor, permissão, auth)
│   ├── state/ui_state.dart              # sealed class UiState<T>: Loading, Success, Empty, Error
│   └── theme/app_theme.dart             # Tema escuro Material 3 (grafite profundo, roxo escuro e âmbar/dourado)
├── data/
│   ├── models/
│   │   ├── deal_model.dart              # Modelo das ofertas CheapShark
│   │   └── backlog_game_model.dart      # Modelo da estante (status: Quero jogar, Jogando, Zerado)
│   ├── services/
│   │   ├── cheapshark_service.dart      # Cliente HTTP com timeout de 4s para api/1.0/deals
│   │   ├── local_cache_service.dart     # Persistência JSON em SharedPreferences + timestamp de sincronização
│   │   ├── auth_service.dart            # Wrapper Firebase Auth + fallback InMemoryAuthService
│   │   ├── firestore_service.dart       # CRUD na coleção backlog_games filtrado por ownerId == uid
│   │   └── media_service.dart           # Captura nativa com compressão (800px, q=75) e sem EXIF/GPS
│   └── repositories/
│       ├── deals_repository.dart        # Coordena busca online e fallback para cache offline
│       ├── backlog_repository.dart      # Coordena CRUD no Firestore e cache local isolado por usuário
│       └── auth_repository.dart         # Validação de credenciais e gestão de sessão
├── ui/
│   ├── viewmodels/
│   │   ├── auth_viewmodel.dart
│   │   ├── deals_viewmodel.dart
│   │   └── backlog_viewmodel.dart
│   ├── widgets/
│   │   └── state_view_widget.dart       # Renderização padrão de Loading, Error, Empty e Success
│   └── views/
│       ├── auth_gate.dart               # Roteamento reativo entre LoginScreen e HomeScreen
│       ├── login_screen.dart
│       ├── register_screen.dart
│       ├── home_screen.dart             # Navegação por abas, logout e badge Online / Offline (Cache)
│       ├── deals_tab.dart               # Busca na CheapShark, banner offline e salvar na estante
│       ├── backlog_tab.dart             # Filtro por status, edição e exclusão com confirmação
│       └── game_form_screen.dart        # Formulário CRUD + câmera/galeria com fallback seguro
└── main.dart                            # Bootstrap, suporte ao Firebase Emulator e MultiProvider
```

---

## 2. Como Executar o Projeto

### Pré-requisitos
- Flutter SDK (`3.x` / Dart `3.x`)
- Android SDK configurado

### Passo a passo
1. Clone o repositório e acesse a pasta do projeto:
   ```bash
   git clone https://github.com/joaosantv/digital-shelf.git
   cd digital-shelf
   ```
2. Instale as dependências:
   ```bash
   flutter pub get
   ```
3. Execute o app no dispositivo ou emulador:
   ```bash
   flutter run
   ```
   > **Fallback local automático:** caso `android/app/google-services.json` não esteja presente localmente, `main.dart` ativa os serviços em memória (`InMemoryAuthService` — basta criar uma conta pela tela *Criar Conta* — e `InMemoryFirestoreService`).

### Executando com Firebase Emulator Suite
1. Inicie os emuladores locais de Auth (`9099`) e Firestore (`8080`) com as regras de `firestore.rules`:
   ```bash
   firebase emulators:start --only auth,firestore
   ```
2. Coloque o arquivo `android/app/google-services.json` localmente (ignorado no Git pelo `.gitignore`). O plugin `com.google.gms.google-services`, `.firebaserc` e `firebase.json` já estão configurados no projeto.
3. Execute o app apontando Auth para `10.0.2.2:9099` e Firestore para `10.0.2.2:8080`:
   ```bash
   flutter run --dart-define=USE_FIREBASE_EMULATOR=true
   ```

---

## 3. Segurança do Firestore (`firestore.rules`)

O arquivo `firestore.rules` na raiz do projeto isola os documentos da coleção `backlog_games`:
- `read` e `delete`: permitidos apenas quando `request.auth != null && request.auth.uid == resource.data.ownerId`.
- `create`: permitido apenas quando `request.auth != null && request.resource.data.ownerId == request.auth.uid` e os campos obrigatórios (`ownerId`, `title`, `status`) respeitam os tipos e valores permitidos (`Quero jogar`, `Jogando`, `Zerado`).
- `update`: exige o mesmo proprietário sem alteração de `ownerId`.

---

## 4. Qualidade de Código e Testes

### Formatação e Análise Estática
```bash
dart format .
flutter analyze
```

### Suíte Automatizada
- **Testes unitários e de widget:**
  ```bash
  flutter test
  ```
  - `test/unit/deals_viewmodel_test.dart`: transições `Loading -> Success`, `Loading -> Empty`, `Loading -> Error`, cache offline e recuperação com `retry()`.
  - `test/unit/backlog_repository_test.dart`: sincronização remota, fallback para cache local e atualização de cache no CRUD.
  - `test/widget/login_screen_test.dart`: validação de campos e estado de carregamento do botão *Entrar*.
  - `test/widget/state_view_widget_test.dart`: estados `Loading`, `Empty`, `Error` (botão *Tentar novamente*) e `Success`.
- **Teste de integração (fluxo completo em memória):**
  ```bash
  # Execução headless sem emulador Android:
  flutter test -d flutter-tester integration_test/app_flow_test.dart

  # Ou com dispositivo/emulador Android conectado:
  flutter test integration_test/app_flow_test.dart
  ```

---

## 5. Build de Release (APK e AAB)

Para assinar com sua chave de produção sem versionar segredos:
1. Crie localmente o arquivo `android/key.properties` (não commitado) contendo `storePassword`, `keyPassword`, `keyAlias` e `storeFile`.
2. Quando `android/key.properties` não estiver presente, o Gradle utiliza a assinatura `debug` apenas para permitir validação local dos artefatos.

Gere os pacotes de distribuição:
```bash
flutter build apk --release
flutter build appbundle --release
```

Artefatos gerados:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`
