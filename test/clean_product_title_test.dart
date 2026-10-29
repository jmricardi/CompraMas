import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/data/repositories/price_search_utils.dart';

void main() {
  test('cleanProductTitle tests', () {
    expect(
      PriceSearchUtils.cleanProductTitle('Leche Condensada NESTLÉ Organica x395g BRK-395-gr.'),
      equals('Leche Condensada Nestlé Orgánica 395g'),
    );
    expect(
      PriceSearchUtils.cleanProductTitle('LECHE CONDENSADA CARREFOUR TETRA X 395 GRS'),
      equals('Leche Condensada Carrefour 395g'),
    );
    expect(
      PriceSearchUtils.cleanProductTitle('Leche Condensada NESTLE Light Org x395g BRK-395-gr.'),
      equals('Leche Condensada Nestlé Light Orgánica 395g'),
    );
    expect(
      PriceSearchUtils.cleanProductTitle('LECHE CONDENSADA LIMON NESTLE TETRA X 395 GRS'),
      equals('Leche Condensada Limón Nestlé 395g'),
    );
  });
}
