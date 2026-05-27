import 'dart:math';

class InviteService {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _random = Random.secure();

  static String generateCode() {
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(_chars[_random.nextInt(_chars.length)]);
    }
    return buf.toString();
  }

  static bool isValidCode(String code) {
    if (code.length != 6) return false;
    return code.split('').every((c) => _chars.contains(c.toUpperCase()));
  }
}
