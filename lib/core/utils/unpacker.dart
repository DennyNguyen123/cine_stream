class JsUnpacker {
  static String? unpack(String code) {
    final RegExp evalRegex = RegExp(r"eval\(function\(p,a,c,k,e,[rd]\).*?return p}\('(.*?)',(\d+),(\d+),'([^']*)'\.split\('\|'\)\)\)");
    final match = evalRegex.firstMatch(code);
    
    if (match == null) return null;
    
    String p = match.group(1)!;
    final int a = int.parse(match.group(2)!);
    final int c = int.parse(match.group(3)!);
    final List<String> k = match.group(4)!.split('|');
    
    String e(int cValue) {
      String prefix = cValue < a ? '' : e((cValue ~/ a));
      int mod = cValue % a;
      String suffix = mod > 35 ? String.fromCharCode(mod + 29) : mod.toRadixString(36);
      return prefix + suffix;
    }
    
    for (int i = c - 1; i >= 0; i--) {
      if (i < k.length && k[i].isNotEmpty) {
        final replaceRegex = RegExp(r'\b' + e(i) + r'\b');
        p = p.replaceAll(replaceRegex, k[i]);
      }
    }
    
    return p;
  }
}
