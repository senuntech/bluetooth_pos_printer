## 1.1.0

* **Novidade: Classificação de Tipo de Dispositivo**: Adicionada a propriedade `type` à classe `BluetoothPrinterDevice` para categorizar dispositivos mapeando-os como `'printer'`, `'phone'`, `'computer'`, `'audio'`, `'peripheral'` ou `'unknown'`.
* **Mapeamento no Android**: Implementada leitura nativa do `BluetoothClass` do dispositivo pareado ou descoberto na busca para classificar os tipos usando APIs oficiais do sistema operacional.
* **Mapeamento no iOS**: Desenvolvida heurística de detecção no Swift baseada em chaves de nomes conhecidos (como "mtp", "mpt", "print", "buds", etc.) e serviços anunciados (ex: checagem de UUID de serviço de impressão `18F0`).
* **Visual Premium no Exemplo**: O aplicativo de exemplo agora exibe ícones representativos e coloridos na lista de busca de acordo com o tipo do dispositivo detectado.

## 1.0.1

* **Novidade: Verificação de Estado do Bluetooth**: Adicionado o método `isBluetoothEnabled()` em ambas as plataformas (Android e iOS) permitindo verificar se o Bluetooth está ativo antes de tentar fazer a busca de dispositivos.
* **Correção no iOS (Condição de Corrida & Travamentos)**: Implementado enfileiramento seguro baseado em classes (`PendingAction`) para chamadas iniciais enquanto o `CBCentralManager` é inicializado assincronamente no iOS. Isso resolve de vez o erro `"Bluetooth is not powered on"` e impede travamentos infinitos da interface.
* **Aumento do Timeout de Inicialização (15s)**: O tempo limite da fila de inicialização no iOS foi expandido para 15 segundos, dando margem confortável para o usuário aceitar o diálogo de permissão do sistema sem cancelar o escaneamento por timeout.
* **Nomes de Dispositivos BLE corrigidos no iOS**: Agora o plugin lê a chave `CBAdvertisementDataLocalNameKey` dos dados de anúncio caso o periférico venha com nome nulo inicialmente, evitando mostrar dispositivos como "Unknown" na busca.
* **Ajuste de Permissões no Exemplo**: Adicionadas as chaves obrigatórias `NSBluetoothAlwaysUsageDescription` e `NSBluetoothPeripheralUsageDescription` no `Info.plist` do aplicativo de exemplo.

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
