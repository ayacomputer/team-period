import 'package:flutter/material.dart';

/// Simple in-app localisation for English and Japanese.
///
/// Usage:
///   final t = AppLocalizations.of(context);
///   Text(t.home)
///
/// To add a new language: add a new entry to [_translations] and
/// add the locale to [supportedLocales].
class AppLocalizations {
  const AppLocalizations._(this._locale);

  final Locale _locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('ja'),
  ];

  /// Retrieves the [AppLocalizations] instance for the nearest [Localizations]
  /// ancestor. Throws if no instance is found.
  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(instance != null, 'No AppLocalizations found in widget tree');
    return instance!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _t(String key) => _translations[_locale.languageCode]?[key] ?? _translations['en']![key]!;

  // ── Strings ───────────────────────────────────────────────────────────────

  // Navigation
  String get navHome => _t('navHome');
  String get navCalendar => _t('navCalendar');
  String get navTemperature => _t('navTemperature');
  String get navHistory => _t('navHistory');

  // Home screen
  String get appTitle => _t('appTitle');
  String get settingsTitle => _t('settingsTitle');
  String get noCyclesYet => _t('noCyclesYet');
  String get noCyclesSubtitle => _t('noCyclesSubtitle');

  // Cycle stats
  String get avgCycle => _t('avgCycle');
  String get avgPeriod => _t('avgPeriod');
  String get days => _t('days');

  // Health insights
  String get healthInsights => _t('healthInsights');
  String get seeAll => _t('seeAll');
  String get noInsights => _t('noInsights');

  // Calendar
  String get calendarTitle => _t('calendarTitle');
  String get today => _t('today');
  String get noDayInfo => _t('noDayInfo');
  String get periodDay => _t('periodDay');
  String get predictedPeriod => _t('predictedPeriod');
  String get predictedOvulation => _t('predictedOvulation');
  String get fertilWindow => _t('fertilWindow');

  // Temperature
  String get temperatureTitle => _t('temperatureTitle');
  String get logTemp => _t('logTemp');
  String get noTempData => _t('noTempData');
  String get noTempSubtitle => _t('noTempSubtitle');
  String get tempCelsius => _t('tempCelsius');
  String get tempNote => _t('tempNote');
  String get tempNotePlaceholder => _t('tempNotePlaceholder');
  String get saveButton => _t('saveButton');
  String get dateLabel => _t('dateLabel');
  String get timeLabel => _t('timeLabel');
  String get deleteEntry => _t('deleteEntry');
  String get normalRange => _t('normalRange');

  // History
  String get historyTitle => _t('historyTitle');
  String get totalCycles => _t('totalCycles');
  String get startDate => _t('startDate');
  String get endDate => _t('endDate');
  String get duration => _t('duration');
  String get cycleGap => _t('cycleGap');
  String get ongoing => _t('ongoing');
  String get noCycleGap => _t('noCycleGap');

  // Settings
  String get partnerName => _t('partnerName');
  String get partnerNameHint => _t('partnerNameHint');
  String get avgCycleLength => _t('avgCycleLength');
  String get avgPeriodLength => _t('avgPeriodLength');
  String get partnerNotifications => _t('partnerNotifications');
  String get notificationsDesc => _t('notificationsDesc');
  String get coupleId => _t('coupleId');
  String get coupleIdDesc => _t('coupleIdDesc');
  String get coupleIdCopied => _t('coupleIdCopied');
  String get enterPartnerId => _t('enterPartnerId');
  String get partnerIdHint => _t('partnerIdHint');
  String get useButton => _t('useButton');
  String get saveSettings => _t('saveSettings');
  String get notificationDenied => _t('notificationDenied');
  String get coupleIdUpdated => _t('coupleIdUpdated');
  String get language => _t('language');
  String get languageEnglish => _t('languageEnglish');
  String get languageJapanese => _t('languageJapanese');

  // Period logger
  String get periodStarted => _t('periodStarted');
  String get periodEnded => _t('periodEnded');
  String get logMood => _t('logMood');
  String get moodGreat => _t('moodGreat');
  String get moodGood => _t('moodGood');
  String get moodOkay => _t('moodOkay');
  String get moodLow => _t('moodLow');
  String get moodRough => _t('moodRough');

  // Flow intensity
  String get logFlow => _t('logFlow');
  String get flowSpotting => _t('flowSpotting');
  String get flowLight => _t('flowLight');
  String get flowMedium => _t('flowMedium');
  String get flowHeavy => _t('flowHeavy');

  // Prediction confidence
  String get prediction => _t('prediction');
  String get confidenceHigh => _t('confidenceHigh');
  String get confidenceMedium => _t('confidenceMedium');
  String get confidenceLow => _t('confidenceLow');

  // Water tracker
  String get waterTracker => _t('waterTracker');
  String get waterPeriodReminder => _t('waterPeriodReminder');
  String get waterGoalMet => _t('waterGoalMet');
  String get addWater => _t('addWater');
  String get waterGoal => _t('waterGoal');

  // Sleep quality
  String get sleepQuality => _t('sleepQuality');
  String get sleepPoor => _t('sleepPoor');
  String get sleepFair => _t('sleepFair');
  String get sleepOkay => _t('sleepOkay');
  String get sleepGood => _t('sleepGood');
  String get sleepExcellent => _t('sleepExcellent');

  // Pill reminder (settings)
  String get pillReminder => _t('pillReminder');
  String get pillReminderDesc => _t('pillReminderDesc');
  String get pillReminderTime => _t('pillReminderTime');

  // History / CSV
  String get exportCsv => _t('exportCsv');
  String get sleepCol => _t('sleepCol');

  // Month names (abbreviated)
  List<String> get monthsShort => [
    _t('jan'), _t('feb'), _t('mar'), _t('apr'),
    _t('may'), _t('jun'), _t('jul'), _t('aug'),
    _t('sep'), _t('oct'), _t('nov'), _t('dec'),
  ];

  List<String> get monthsFull => [
    _t('january'), _t('february'), _t('march'), _t('april'),
    _t('mayFull'), _t('june'), _t('july'), _t('august'),
    _t('september'), _t('october'), _t('november'), _t('december'),
  ];

  List<String> get weekdaysShort => [
    _t('sun'), _t('mon'), _t('tue'), _t('wed'),
    _t('thu'), _t('fri'), _t('sat'),
  ];

  // ── Translation tables ────────────────────────────────────────────────────

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // Nav
      'navHome': 'Home',
      'navCalendar': 'Calendar',
      'navTemperature': 'Temperature',
      'navHistory': 'History',
      // Home
      'appTitle': 'teamPeriod',
      'settingsTitle': 'Settings',
      'noCyclesYet': 'No cycles logged yet',
      'noCyclesSubtitle': 'Tap "Period Started" to begin tracking',
      // Stats
      'avgCycle': 'Avg cycle',
      'avgPeriod': 'Avg period',
      'days': 'd',
      // Health
      'healthInsights': 'Health Insights',
      'seeAll': 'See all',
      'noInsights': 'No insights yet — keep logging!',
      // Calendar
      'calendarTitle': 'Calendar',
      'today': 'Today',
      'noDayInfo': 'No data for this day.',
      'periodDay': 'Period day',
      'predictedPeriod': 'Predicted period',
      'predictedOvulation': 'Predicted ovulation',
      'fertilWindow': 'Fertile window',
      // Temperature
      'temperatureTitle': 'Temperature',
      'logTemp': 'Log temperature',
      'noTempData': 'No temperatures logged',
      'noTempSubtitle': 'Tap + to log your basal body temperature',
      'tempCelsius': 'Temperature (°C)',
      'tempNote': 'Note (optional)',
      'tempNotePlaceholder': 'e.g. after waking, before getting up',
      'saveButton': 'Save',
      'dateLabel': 'Date',
      'timeLabel': 'Time',
      'deleteEntry': 'Delete entry',
      'normalRange': 'Normal BBT range',
      // History
      'historyTitle': 'Cycle History',
      'totalCycles': 'Cycles',
      'startDate': 'Start',
      'endDate': 'End',
      'duration': 'Duration',
      'cycleGap': 'Cycle gap',
      'ongoing': 'Ongoing',
      'noCycleGap': '—',
      // Settings
      'partnerName': 'Partner\'s name',
      'partnerNameHint': 'e.g. Alex',
      'avgCycleLength': 'Average cycle length',
      'avgPeriodLength': 'Average period length',
      'partnerNotifications': 'Partner notifications',
      'notificationsDesc': 'Notify your partner at key phases',
      'coupleId': 'Couple ID',
      'coupleIdDesc': 'Share this ID with your partner so you both see the same data.',
      'coupleIdCopied': 'Couple ID copied',
      'enterPartnerId': 'Enter partner\'s ID',
      'partnerIdHint': 'Paste partner\'s Couple ID',
      'useButton': 'Use',
      'saveSettings': 'Save settings',
      'notificationDenied': 'Notification permission denied',
      'coupleIdUpdated': 'Couple ID updated — reload to sync',
      'language': 'Language',
      'languageEnglish': 'English',
      'languageJapanese': '日本語',
      // Period logger
      'periodStarted': 'Period Started',
      'periodEnded': 'Period Ended',
      'logMood': 'Log Mood',
      'moodGreat': 'Great',
      'moodGood': 'Good',
      'moodOkay': 'Okay',
      'moodLow': 'Low',
      'moodRough': 'Rough',
      // Flow intensity
      'logFlow': 'Log Flow',
      'flowSpotting': 'Spotting',
      'flowLight': 'Light',
      'flowMedium': 'Medium',
      'flowHeavy': 'Heavy',
      // Prediction confidence
      'prediction': 'Prediction',
      'confidenceHigh': 'High',
      'confidenceMedium': 'Medium',
      'confidenceLow': 'Low',
      // Water tracker
      'waterTracker': 'Water Tracker',
      'waterPeriodReminder': 'Stay hydrated — it helps ease period discomfort',
      'waterGoalMet': 'Daily goal met! 🎉',
      'addWater': 'Tap + to add 250 ml',
      'waterGoal': 'Daily water goal',
      // Sleep quality
      'sleepQuality': 'Sleep Quality',
      'sleepPoor': 'Poor',
      'sleepFair': 'Fair',
      'sleepOkay': 'Okay',
      'sleepGood': 'Good',
      'sleepExcellent': 'Excellent',
      // Pill reminder
      'pillReminder': 'Medication reminder',
      'pillReminderDesc': 'Daily notification at a set time',
      'pillReminderTime': 'Reminder time',
      // History / CSV
      'exportCsv': 'Export CSV',
      'sleepCol': 'Sleep',
      // Months
      'jan': 'Jan', 'feb': 'Feb', 'mar': 'Mar', 'apr': 'Apr',
      'may': 'May', 'jun': 'Jun', 'jul': 'Jul', 'aug': 'Aug',
      'sep': 'Sep', 'oct': 'Oct', 'nov': 'Nov', 'dec': 'Dec',
      'january': 'January', 'february': 'February', 'march': 'March',
      'april': 'April', 'mayFull': 'May', 'june': 'June',
      'july': 'July', 'august': 'August', 'september': 'September',
      'october': 'October', 'november': 'November', 'december': 'December',
      // Weekdays
      'sun': 'Su', 'mon': 'Mo', 'tue': 'Tu', 'wed': 'We',
      'thu': 'Th', 'fri': 'Fr', 'sat': 'Sa',
    },
    'ja': {
      // Nav
      'navHome': 'ホーム',
      'navCalendar': 'カレンダー',
      'navTemperature': '体温',
      'navHistory': '履歴',
      // Home
      'appTitle': 'teamPeriod',
      'settingsTitle': '設定',
      'noCyclesYet': 'まだ記録がありません',
      'noCyclesSubtitle': '「生理開始」をタップして記録を始めましょう',
      // Stats
      'avgCycle': '平均周期',
      'avgPeriod': '平均期間',
      'days': '日',
      // Health
      'healthInsights': '健康インサイト',
      'seeAll': 'すべて見る',
      'noInsights': 'まだインサイトがありません — 記録を続けましょう！',
      // Calendar
      'calendarTitle': 'カレンダー',
      'today': '今日',
      'noDayInfo': 'この日のデータはありません。',
      'periodDay': '生理日',
      'predictedPeriod': '予測生理',
      'predictedOvulation': '予測排卵日',
      'fertilWindow': '妊娠可能期間',
      // Temperature
      'temperatureTitle': '体温',
      'logTemp': '体温を記録',
      'noTempData': '体温の記録がありません',
      'noTempSubtitle': '＋をタップして基礎体温を記録しましょう',
      'tempCelsius': '体温（°C）',
      'tempNote': 'メモ（任意）',
      'tempNotePlaceholder': '例：起床直後、起き上がる前',
      'saveButton': '保存',
      'dateLabel': '日付',
      'timeLabel': '時刻',
      'deleteEntry': '削除',
      'normalRange': '正常な基礎体温範囲',
      // History
      'historyTitle': '周期履歴',
      'totalCycles': '周期数',
      'startDate': '開始',
      'endDate': '終了',
      'duration': '日数',
      'cycleGap': '周期間隔',
      'ongoing': '継続中',
      'noCycleGap': '—',
      // Settings
      'partnerName': 'パートナーの名前',
      'partnerNameHint': '例：アレックス',
      'avgCycleLength': '平均周期の長さ',
      'avgPeriodLength': '平均生理期間',
      'partnerNotifications': 'パートナー通知',
      'notificationsDesc': '主要なフェーズでパートナーに通知する',
      'coupleId': 'カップルID',
      'coupleIdDesc': 'このIDをパートナーと共有して、同じデータを表示しましょう。',
      'coupleIdCopied': 'カップルIDをコピーしました',
      'enterPartnerId': 'パートナーのIDを入力',
      'partnerIdHint': 'パートナーのカップルIDを貼り付け',
      'useButton': '使用',
      'saveSettings': '設定を保存',
      'notificationDenied': '通知の許可が拒否されました',
      'coupleIdUpdated': 'カップルIDを更新しました — 再起動して同期してください',
      'language': '言語',
      'languageEnglish': 'English',
      'languageJapanese': '日本語',
      // Period logger
      'periodStarted': '生理開始',
      'periodEnded': '生理終了',
      'logMood': '気分を記録',
      'moodGreat': '最高',
      'moodGood': '良い',
      'moodOkay': '普通',
      'moodLow': '低め',
      'moodRough': '辛い',
      // Flow intensity
      'logFlow': '経血量を記録',
      'flowSpotting': '少量',
      'flowLight': '軽い',
      'flowMedium': '普通',
      'flowHeavy': '多い',
      // Prediction confidence
      'prediction': '予測精度',
      'confidenceHigh': '高',
      'confidenceMedium': '中',
      'confidenceLow': '低',
      // Water tracker
      'waterTracker': '水分補給',
      'waterPeriodReminder': '生理中は水分補給で不快感を和らげましょう',
      'waterGoalMet': '目標達成！🎉',
      'addWater': '＋をタップして250ml追加',
      'waterGoal': '1日の水分目標',
      // Sleep quality
      'sleepQuality': '睡眠の質',
      'sleepPoor': '悪い',
      'sleepFair': 'まあまあ',
      'sleepOkay': '普通',
      'sleepGood': '良い',
      'sleepExcellent': '最高',
      // Pill reminder
      'pillReminder': '服薬リマインダー',
      'pillReminderDesc': '毎日設定した時刻に通知',
      'pillReminderTime': 'リマインド時刻',
      // History / CSV
      'exportCsv': 'CSVエクスポート',
      'sleepCol': '睡眠',
      // Months
      'jan': '1月', 'feb': '2月', 'mar': '3月', 'apr': '4月',
      'may': '5月', 'jun': '6月', 'jul': '7月', 'aug': '8月',
      'sep': '9月', 'oct': '10月', 'nov': '11月', 'dec': '12月',
      'january': '1月', 'february': '2月', 'march': '3月',
      'april': '4月', 'mayFull': '5月', 'june': '6月',
      'july': '7月', 'august': '8月', 'september': '9月',
      'october': '10月', 'november': '11月', 'december': '12月',
      // Weekdays
      'sun': '日', 'mon': '月', 'tue': '火', 'wed': '水',
      'thu': '木', 'fri': '金', 'sat': '土',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations._(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
