## 1.0.0

* **Breaking Change**: Substituição de flags booleanas `includePaired` e `includeActive` pelo enum tipado `BluetoothScanMode` no método `scan()`.
* **Modos de Busca Personalizados**: Adicionado suporte para configurar o comportamento do escaneamento de Bluetooth através de `BluetoothScanMode`:
  - `active` (padrão): Busca apenas novos dispositivos ativos e visíveis próximos.
  - `paired`: Retorna apenas os dispositivos Bluetooth já pareados no sistema operacional.
  - `all`: Combina ambos, retornando pareados e fazendo busca ativa.
* **Interface de Exemplo em Material 3**: Nova interface premium e moderna no aplicativo `/example` com `SegmentedButton` nativo do Material 3 para alternância de modos de busca em tempo real.
* **Permissões Refinadas no Android 12+**: Implementação robusta das permissões perigosas de Bluetooth no Android usando a flag `neverForLocation` no manifesto, permitindo buscas de impressoras sem requisição invasiva de localização física em dispositivos mais recentes.
* **Estabilidade Geral**: Correção de possíveis vazamentos de conexões e manipulação resiliente a exceções e falhas na inicialização do adaptador Bluetooth.

## 0.0.1

* Initial release of the `bluetooth_pos_printer` plugin.
* Supports sending RAW bytes in chunks to thermal POS printers to prevent buffer overflow.
* Supports Classic Bluetooth (SPP) on Android and Bluetooth Low Energy (BLE) on iOS.
* Reactive connection status stream (`statusStream`).
* Included a fully-featured example application.
