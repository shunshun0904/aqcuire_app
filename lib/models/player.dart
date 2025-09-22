class Player {
  final String name;
  int cash;
  Map<String, int> stocks = {};

  Player({required this.name, required this.cash});

  bool buyStock(String hotel, int quantity, int pricePerStock) {
    int totalCost = quantity * pricePerStock;
    if (cash >= totalCost) {
      cash -= totalCost;
      stocks[hotel] = (stocks[hotel] ?? 0) + quantity;
      return true;
    }
    return false;
  }

  int stockCount(String hotel) {
    return stocks[hotel] ?? 0;
  }
}
