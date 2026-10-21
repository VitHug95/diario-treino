// Driver padrão do integration_test, usado por `flutter drive` para executar os
// testes em `integration_test/` num navegador real (Chrome via ChromeDriver no
// CI). Boilerplate fixo — a lógica do teste vive em integration_test/.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
