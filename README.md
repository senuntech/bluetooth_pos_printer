# bluetooth_pos_printer

Um plugin Flutter robusto para comunicação com impressoras térmicas Bluetooth (POS). Compatível com as plataformas Android e iOS, projetado especificamente para envio de bytes brutos (RAW), tornando-o o parceiro ideal para bibliotecas de layout de recibos como a `flutter_esc_pos_utils`.

## Recursos

- **Suporte Multiplataforma**: Comunicação contínua via Bluetooth Classic (SPP) no Android e Bluetooth Low Energy (BLE) no iOS.
- **Transmissão Segura de Dados**: Envia bytes brutos em partes segmentadas (*chunks* de até 256 bytes) nativamente em Kotlin/Swift para evitar estouro de buffer (buffer overflow) em mini-impressoras mais antigas.
- **Gerenciamento de Estado**: Monitoramento reativo em tempo real através de Streams (`desconectado`, `conectando`, `conectado`).
- **Instância Singleton**: Gerenciamento global de dependência otimizado, permitindo chamadas de qualquer lugar no app (`BluetoothPosPrinter.instance`).

---

## Configuração de Permissões

Antes de usar o plugin, certifique-se de configurar as permissões nativas adequadas para cada plataforma.

### Android (`android/app/src/main/AndroidManifest.xml`)

Adicione as permissões a seguir dentro da tag `<manifest>`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" /> <!-- Obrigatório no Android antigo para o scan de dispositivos próximos -->

<!-- Regras adicionais necessárias para Android 12 (API 31) ou superior -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
```

### iOS (`ios/Runner/Info.plist`)

No ambiente iOS, a Apple exige descrições claras sobre o porquê de você estar pedindo permissões de uso do Bluetooth:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Este aplicativo precisa de acesso ao Bluetooth para conectar-se e imprimir recibos na sua impressora POS.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Este aplicativo precisa de acesso ao Bluetooth para conectar-se e imprimir recibos na sua impressora POS.</string>
```

---

## Como Usar

O pacote utiliza o padrão Singleton. Você pode acessá-lo usando `BluetoothPosPrinter.instance`.

### 1. Ouvir o Estado de Conexão

Ideal para atualizar sua interface do usuário em tempo real:

```dart
import 'package:bluetooth_pos_printer/bluetooth_pos_printer.dart';

BluetoothPosPrinter.instance.statusStream.listen((status) {
  if (status == PrinterStatus.connected) {
    print('Impressora Conectada!');
  } else if (status == PrinterStatus.connecting) {
    print('Conectando...');
  } else {
    print('Desconectado.');
  }
});
```

### 2. Buscar Impressoras Próximas (Scan)

O método `scan` permite buscar dispositivos disponíveis. Por padrão, ele realiza uma busca **apenas de dispositivos ativos e visíveis próximos**, o que evita poluir a lista de busca com dispositivos pareados que podem estar desligados.

Você pode configurar o modo de escaneamento usando o enum `BluetoothScanMode`:
- `BluetoothScanMode.active` (Padrão): Busca ativa apenas por aparelhos visíveis ao alcance.
- `BluetoothScanMode.paired`: Retorna apenas os aparelhos já previamente pareados no sistema operacional (Android).
- `BluetoothScanMode.all`: Retorna dispositivos pareados e também realiza a busca ativa por novos aparelhos.

```dart
// Escaneando apenas por dispositivos ativos por perto (padrão)
List<BluetoothPrinterDevice> devices = await BluetoothPosPrinter.instance.scan(
  mode: BluetoothScanMode.active,
);

for (var device in devices) {
  print('Nome: ${device.name}, Endereço/UUID: ${device.address}');
}
```

### 3. Conectar a um Dispositivo

Use a propriedade `address` retornada no escaneamento (Representa o Endereço MAC no Android e o UUID no iOS):

```dart
bool conectou = await BluetoothPosPrinter.instance.connect(device.address);
if (conectou) {
  print('A impressora agora está pronta para receber impressões.');
}
```

### 4. Desconectar

Para evitar vazamento de memória e garantir a conexão futura sem problemas, encerre a conexão ativamente:

```dart
await BluetoothPosPrinter.instance.disconnect();
```

### 5. Imprimir Recibos e Enviar Bytes Brutos (Raw)

Para imprimir layouts robustos, utilize a biblioteca aliada `flutter_esc_pos_utils` para formatar os dados visuais. O nosso plugin se encarrega exclusivamente da transmissão rápida e segura desses dados via canal nativo de Bluetooth:

```dart
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';

// Carrega as características básicas do papel
final profile = await CapabilityProfile.load();
final generator = Generator(PaperSize.mm58, profile);
List<int> bytes = [];

// Escreve as ordens de impressão no vetor de bytes
bytes += generator.text('Meu Recibo de Teste!', styles: const PosStyles(bold: true));
bytes += generator.feed(2);
bytes += generator.cut();

// Envia nativamente (o Kotlin/Swift fará a leitura fracionada em chunks de 256 bytes automaticamente)
await BluetoothPosPrinter.instance.printRawBytes(bytes);
```

---

## Projeto de Exemplo

Existe um laboratório completo de testes preparado na subpasta `/example/` demonstrando UI responsiva com pesquisa visual, controle de estado, conexão dinâmica e montagem do cupom. Verifique o arquivo `example/lib/main.dart` para um guia prático de integração.
