class NlpResult {
  final double? amount;
  final DateTime? date;
  final String? categoryHint;
  final int? type; // 0=expense, 1=income
  final String note;
  final double confidence;

  const NlpResult({
    this.amount,
    this.date,
    this.categoryHint,
    this.type,
    this.note = '',
    this.confidence = 0,
  });

  bool get hasAmount => amount != null;
}

class NlpParser {
  static const _catKeywords = {
    '餐饮': ['饭', '餐', '吃', '外卖', '食堂', '午饭', '晚饭', '早餐', '午餐', '晚餐', '夜宵', '零食', '奶茶', '咖啡', '饮料', '水果', '菜', '烧烤', '火锅', '面', '食材', '肯德基', '麦当劳', '饿了么', '美团外卖', '早点', '下午茶', '小吃', '自助', '麻辣烫'],
    '交通': ['地铁', '公交', '打车', '交通', '加油', '油', '高铁', '火车', '飞机', '机票', '停车', '过路费', '共享单车', '滴滴', '出租车', '骑行', '摩拜', '单程', '往返', '通行', '高速', 'etc', 'ETC'],
    '购物': ['买', '购', '淘宝', '京东', '拼多多', '衣服', '鞋', '超市', '日用品', '数码', '电器', '化妆品', '包', '裤子', '裙子', '帽子', '手表', '眼镜', '家具', '家电', '手机', '电脑', '配件', '键盘', '鼠标', '零食', '饮料', '烟酒'],
    '娱乐': ['电影', '游戏', '旅游', 'KTV', '玩', '健身', '运动', '门票', '演出', '音乐会', '酒吧', '游乐场', '景点', '游泳', '瑜伽', '打球', '台球', '篮球', '足球', '跑步', '骑行', '爬山', '聚会', '聚餐', '轰趴'],
    '居住': ['房租', '水电', '物业', '房贷', '煤气', '暖气', '宽带', '维修', '电费', '水费', '天然气', '液化气', '热水器', '空调', '洗衣机', '冰箱', '装修', '家具', '搬家', '通马桶', '开锁'],
    '医疗': ['药', '医院', '看病', '体检', '挂号', '诊所', '牙医', '眼科', '手术', '住院', '检查', '药费', '检查费', '治疗', '中医', '西医', '急诊'],
    '教育': ['书', '学费', '培训', '考试', '课程', '文具', '教材', '网课', '报名', '考证', '考研', '留学', '辅导', '家教', '图书馆', '书籍', '资料'],
    '通讯': ['话费', '流量', '电话', '网费', '手机费', '宽带费', '手机', '上网'],
    '日用': ['洗发水', '沐浴露', '纸巾', '洗衣', '毛巾', '牙膏', '牙刷', '卫生', '垃圾袋', '生活', '日用', '家居', '厨房', '厕所', '拖把', '扫帚'],
    '人情': ['份子', '红包', '送礼', '婚礼', '生日', '聚会', '请客', '礼物', '压岁钱', '彩礼', '随礼', '回礼'],
  };

  static const _incomeKeywords = [
    '工资', '奖金', '收入', '到账', '发薪', '报销', '兼职', '副业', '外快', '稿费', '投资', '理财', '股票', '基金', '分红', '利息', '收益', '退款', '返现', '红包', '收款', '进账',
  ];

  static Map<String, List<String>> get catKeywords => _catKeywords;
  static List<String> get incomeKeywords => _incomeKeywords;

  /// Match merchant text against category keyword dictionary.
  /// Returns best-matching category name and type (0=expense, 1=income).
  static ({String categoryName, int type}) matchCategoryFromText(String text) {
    // Check income keywords first
    for (final kw in _incomeKeywords) {
      if (text.contains(kw)) {
        return (categoryName: '其他', type: 1);
      }
    }

    // Match expense categories
    int bestScore = 0;
    String bestCategory = '其他';
    for (final entry in _catKeywords.entries) {
      for (final kw in entry.value) {
        if (text.contains(kw)) {
          if (kw.length > bestScore) {
            bestScore = kw.length;
            bestCategory = entry.key;
          }
        }
      }
    }
    return (categoryName: bestCategory, type: 0);
  }

  static NlpResult parse(String input) {
    if (input.trim().isEmpty) return const NlpResult();
    double confidence = 0;

    // Step 1: Extract amount
    final amountMatches = RegExp(r'(\d+\.?\d{0,2})').allMatches(input).toList();
    double? amount;
    String remaining = input;
    if (amountMatches.isNotEmpty) {
      amount = double.tryParse(amountMatches.last.group(0)!);
      if (amount != null && amount > 0) {
        confidence += 0.4;
        remaining = remaining.replaceFirst(amountMatches.last.group(0)!, '', amountMatches.last.start);
      }
    }

    // Step 2: Extract date
    DateTime? date;
    String dateStr = '';

    // Specific date: 3月5日, 3月5号
    final dateMatch1 = RegExp(r'(\d{1,2})月(\d{1,2})[日号]?').firstMatch(remaining);
    if (dateMatch1 != null) {
      final m = int.parse(dateMatch1.group(1)!);
      final d = int.parse(dateMatch1.group(2)!);
      if (m >= 1 && m <= 12) {
        final now = DateTime.now();
        int y = now.year;
        final lastDay = DateTime(y, m + 1, 0).day;
        final safeD = d.clamp(1, lastDay);
        if (DateTime(y, m, safeD).isAfter(now)) y--; // future → last year
        date = DateTime(y, m, safeD);
        dateStr = dateMatch1.group(0)!;
        confidence += 0.2;
      }
    }

    // Full date: 2024年3月5日 or 2024-03-05
    if (date == null) {
      final dateMatch2 = RegExp(r'(\d{4})[-年](\d{1,2})[-月](\d{1,2})日?').firstMatch(remaining);
      if (dateMatch2 != null) {
        final m2 = int.parse(dateMatch2.group(2)!);
        final d2 = int.parse(dateMatch2.group(3)!);
        if (m2 >= 1 && m2 <= 12) {
          final y2 = int.parse(dateMatch2.group(1)!);
          final lastDay2 = DateTime(y2, m2 + 1, 0).day;
          date = DateTime(y2, m2, d2.clamp(1, lastDay2));
          dateStr = dateMatch2.group(0)!;
          confidence += 0.2;
        }
      }
    }

    // Day of week: 周一, 星期二
    if (date == null) {
      final dowMatch = RegExp(r'周([一二三四五六日天])|星期([一二三四五六日天])').firstMatch(remaining);
      if (dowMatch != null) {
        final ch = dowMatch.group(1) ?? dowMatch.group(2)!;
        final dowMap = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
        final target = dowMap[ch] ?? 1;
        final now = DateTime.now();
        final todayDow = now.weekday;
        final diff = target - todayDow;
        date = now.add(Duration(days: diff <= 0 ? diff + 7 : diff));
        dateStr = dowMatch.group(0)!;
        confidence += 0.15;
      }
    }

    // Relative: 今天/昨天/前天/明天/后天
    if (date == null) {
      final relMatch = RegExp(r'(今天|昨天|前天|明天|后天)').firstMatch(remaining);
      if (relMatch != null) {
        final now = DateTime.now();
        switch (relMatch.group(1)!) {
          case '昨天': date = now.subtract(const Duration(days: 1)); break;
          case '前天': date = now.subtract(const Duration(days: 2)); break;
          case '明天': date = now.add(const Duration(days: 1)); break;
          case '后天': date = now.add(const Duration(days: 2)); break;
          default: date = now;
        }
        dateStr = relMatch.group(0)!;
        confidence += 0.15;
      }
    }

    // Default: today
    date ??= DateTime.now();

    // Remove date string from remaining
    if (dateStr.isNotEmpty) {
      remaining = remaining.replaceFirst(dateStr, '');
    }

    // Step 3: Category hint
    String? categoryHint;
    int? type;
    for (final entry in _catKeywords.entries) {
      for (final kw in entry.value) {
        if (remaining.contains(kw)) {
          categoryHint = entry.key;
          remaining = remaining.replaceFirst(kw, '');
          confidence += 0.3;
          break;
        }
      }
      if (categoryHint != null) break;
    }

    // Step 4: Type detection
    if (categoryHint != null) {
      type = 0; // default expense (categories defined are expense)
    }
    for (final kw in _incomeKeywords) {
      if (remaining.contains(kw) || input.contains(kw)) {
        type = 1;
        if (categoryHint == null) confidence += 0.1;
        break;
      }
    }
    type ??= 0;

    // Step 5: Extract note from remaining
    final note = remaining
        .replaceAll(RegExp(r'[元块¥]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (note.isNotEmpty && note.length < remaining.length ~/ 2 + 1) {
      confidence += 0.1;
    }

    confidence = confidence.clamp(0.0, 1.0);

    return NlpResult(
      amount: amount,
      date: date,
      categoryHint: categoryHint,
      type: type,
      note: note,
      confidence: confidence,
    );
  }
}
