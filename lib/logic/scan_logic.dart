class AnalysisResult {
  final List<String> haramFound;
  final List<String> mushboohFound;
  final List<String> meatFound;

  AnalysisResult({
    required this.haramFound,
    required this.mushboohFound,
    required this.meatFound,
  });

  // helper to determine the overall status
  ScanStatus get status {
    if (haramFound.isNotEmpty) return ScanStatus.haram;
    if (meatFound.isNotEmpty) return ScanStatus.meatCheck;
    if (mushboohFound.isNotEmpty) return ScanStatus.mushbooh;
    return ScanStatus.safe;
  }
}

enum ScanStatus { safe, mushbooh, meatCheck, haram }

class ScanLogic {
  // ABSOLUTE HARAM (PORK, ALCOHOL, INSECTS)
  static const List<String> haramKeywords = [
    'PORK', 'LARD', 'BACON', 'HAM', 'GAMMON', 'SAUSAGE', 'PEPPERONI', 'PORCINE',
    'ALCOHOL', 'ETHANOL', 'WINE', 'BEER', 'RUM', 'BRANDY', 'WHISKEY', 'VODKA', 'GIN', 'TEQUILA', 'CIDER', 'LIQUEUR', 'SPIRIT', 'KIRSCH', 'SAKE', 'MIRIN',
    'E120', 'CARMINE', 'COCHINEAL', 'SHELLAC', 'E904',
    'E542', 'L-CYSTEINE', 'E920', // Human hair/bones
  ];

  //  MUSHBOOH (Doubtful - could be plant or pnimal)
  static const List<String> mushboohKeywords = [
    'E471', 'MONO- AND DIGLYCERIDES',
    'E472', 'E473', 'E474', 'E475',
    'E422', 'GLYCEROL', 'GLYCERIN',
    'GELATIN', 'GELATINE', 'E441', // Often Haram, but can be Halal (Fish/Zabiha)
    'MAGNESIUM STEARATE', 'STEARIC ACID',
    'RENNET', 'PEPSIN', 'ENZYME', 'ENZYMES', // Cheese enzymes
    'WHEY POWDER', // Rennet source matters
    'VANILLA EXTRACT', // Often contains alcohol, but some scholars allow
  ];

  // RITUAL SLAUGHTER CHECK (halal animal, but needs zabiha proof)
  static const List<String> meatKeywords = [
    'BEEF', 'CHICKEN', 'LAMB', 'MUTTON', 'DUCK', 'TURKEY',
    'POULTRY', 'MEAT', 'TALLOW', 'SUET', 'ANIMAL FAT',
    'COLLAGEN', 'BROTH', 'STOCK',
  ];

  static AnalysisResult analyzeText(String text) {
    List<String> haram = [];
    List<String> mushbooh = [];
    List<String> meat = [];

    String cleanedText = text.toUpperCase()
        .replaceAll(',', ' ')
        .replaceAll('.', ' ')
        .replaceAll(':', ' ')
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll('-', ' ');

    List<String> words = cleanedText.split(RegExp(r'\s+'));

    // Check Haram
    for (String k in haramKeywords) {
      if (_matches(k, words, cleanedText)) haram.add(k);
    }

    // Check Meat
    for (String k in meatKeywords) {
       if (_matches(k, words, cleanedText)) meat.add(k);
    }

    // Check Mushbooh
    for (String k in mushboohKeywords) {
       if (_matches(k, words, cleanedText)) mushbooh.add(k);
    }

    return AnalysisResult(
      haramFound: haram.toSet().toList(),
      mushboohFound: mushbooh.toSet().toList(),
      meatFound: meat.toSet().toList(),
    );
  }

  static bool _matches(String keyword, List<String> words, String fullText) {
    if (keyword.startsWith('E') && keyword.length <= 4) {
      return words.contains(keyword);
    }
    return fullText.contains(keyword) || words.contains(keyword);
  }
}