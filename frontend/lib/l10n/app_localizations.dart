import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isHebrew => locale.languageCode == 'he';

  // ── App ──
  String get appTitle => isHebrew ? 'פוקוס פלו' : 'FocusFlow';

  // ── Auth / Login ──
  String get productivitySanctuary =>
      isHebrew ? 'מקלט הפרודוקטיביות שלך.' : 'Your productivity sanctuary.';
  String get welcomeBack => isHebrew ? 'ברוכים השבים' : 'Welcome Back';
  String get email => isHebrew ? 'אימייל' : 'Email';
  String get password => isHebrew ? 'סיסמה' : 'Password';
  String get logIn => isHebrew ? 'כניסה' : 'LOG IN';
  String get forgotPassword => isHebrew ? 'שכחת סיסמה?' : 'Forgot password?';
  String get newHere => isHebrew ? 'חדש כאן? ' : 'New here? ';
  String get createAccount => isHebrew ? 'צור חשבון' : 'Create Account';
  String get emailAndPasswordRequired =>
      isHebrew ? 'נדרשים אימייל וסיסמה' : 'Email and password are required';
  String get unexpectedError =>
      isHebrew ? 'אירעה שגיאה בלתי צפויה' : 'Unexpected error occurred';
  String get welcomeBackSnackbar =>
      isHebrew ? 'ברוכים השבים ל-FOCUSFLOW!' : 'Welcome back to FOCUSFLOW!';

  // ── Signup ──
  String get joinFocusFlow => isHebrew ? 'הצטרף ל-FocusFlow' : 'Join FocusFlow';
  String get createYourSpace =>
      isHebrew ? 'צור את המרחב שלך. שלוט בזמנך.' : 'Create your space. Own your time.';
  String get fullName => isHebrew ? 'שם מלא' : 'Full Name';
  String get usernameUnique =>
      isHebrew ? 'שם משתמש (ייחודי)' : 'Username (Unique)';
  String get createAccountButton =>
      isHebrew ? 'צור חשבון' : 'CREATE ACCOUNT';
  String get alreadyHaveAccount =>
      isHebrew ? 'כבר יש לך חשבון? ' : 'Already have an account? ';
  String get logInLink => isHebrew ? 'התחבר' : 'Log in';
  String get signupFailed => isHebrew ? 'ההרשמה נכשלה' : 'Signup failed';

  // ── Home / Greetings ──
  String get goodMorning => isHebrew ? 'בוקר טוב' : 'Good morning';
  String get goodAfternoon =>
      isHebrew ? 'אחר הצהריים טובים' : 'Good afternoon';
  String get goodEvening => isHebrew ? 'ערב טוב' : 'Good evening';
  String get subtitleStudent =>
      isHebrew ? 'מוכן לסיים את היעדים שלך?' : 'Ready to ace your goals?';
  String get subtitleEmployee =>
      isHebrew ? 'בוא נסיים את המשימות שלך.' : "Let's crush your tasks.";
  String get subtitleFreelancer =>
      isHebrew ? 'העסק שלך, הזרימה שלך.' : 'Your business, your flow.';
  String get subtitleDefault =>
      isHebrew ? 'בוא נהיה פרודוקטיביים היום.' : "Let's be productive today.";
  String get quickAccess => isHebrew ? 'גישה מהירה' : 'QUICK ACCESS';
  String get aiInsight => isHebrew ? 'תובנת AI' : 'AI Insight';
  String get takeAction => isHebrew ? 'פעל עכשיו' : 'Take Action';
  String get tasksCompleted =>
      isHebrew ? 'משימות הושלמו' : 'Tasks Completed';
  String get addTask => isHebrew ? 'הוסף משימה' : 'Add Task';
  String get retry => isHebrew ? 'נסה שוב' : 'Retry';
  String get logoutFixAuth =>
      isHebrew ? 'התנתק (תקן אימות)' : 'Logout (Fix Auth)';
  String get newStudyInvites =>
      isHebrew ? 'הזמנות לימוד חדשות!' : 'New Study Invites!';
  String pendingInvitations(int count) =>
      isHebrew ? 'יש לך $count הזמנות ממתינות.' : 'You have $count pending invitations.';
  String get defaultInsightText =>
      isHebrew ? 'אתה מוכן. בחר משימה אחת והתחל בקטן.' : "You're ready. Pick one task and start small.";
  String get focusSessionLogged =>
      isHebrew ? 'סשן מיקוד נרשם! הנתונים עודכנו.' : 'Focus session logged! stats updated.';
  String delayedTask(String title, int hours) =>
      isHebrew ? 'המשימה "$title" נדחתה ב-${hours}ש׳' : "Delayed '$title' by ${hours}h";
  String get failedToDelay => isHebrew ? 'נכשל לדחות' : 'Failed to delay';

  // ── Grid Actions ──
  String get kanban => isHebrew ? 'קנבן' : 'Kanban';
  String get tasksSub => isHebrew ? 'משימות' : 'Tasks';
  String get calendarLabel => isHebrew ? 'לוח שנה' : 'Calendar';
  String get scheduleLabel => isHebrew ? 'לוח זמנים' : 'Schedule';
  String get focusZone => isHebrew ? 'אזור מיקוד' : 'Focus Zone';
  String get startFlow => isHebrew ? 'התחל זרימה' : 'Start Flow';
  String get studyTogether => isHebrew ? 'למד ביחד' : 'Study Together';
  String get joinRooms => isHebrew ? 'הצטרף לחדרים' : 'Join Rooms';
  String get smartPlan => isHebrew ? 'תכנון חכם' : 'Smart Plan';
  String get aiAssistant => isHebrew ? 'עוזר AI' : 'AI Assistant';
  String get analytics => isHebrew ? 'אנליטיקה' : 'Analytics';
  String get insightsLabel => isHebrew ? 'תובנות' : 'Insights';

  // ── Language ──
  String get language => isHebrew ? 'שפה' : 'Language';
  String get english => isHebrew ? 'אנגלית' : 'English';
  String get hebrew => isHebrew ? 'עברית' : 'Hebrew';

  // ── Profile / Settings ──
  String get profile => isHebrew ? 'פרופיל' : 'Profile';
  String get settings => isHebrew ? 'הגדרות' : 'Settings';
  String get logout => isHebrew ? 'התנתק' : 'Logout';
  String get save => isHebrew ? 'שמור' : 'Save';
  String get cancel => isHebrew ? 'ביטול' : 'Cancel';
  String get delete => isHebrew ? 'מחק' : 'Delete';
  String get notifications => isHebrew ? 'התראות' : 'Notifications';
  String get theme => isHebrew ? 'ערכת נושא' : 'Theme';
  String get pushNotifications => isHebrew ? 'התראות דחיפה' : 'Push Notifications';
  String get pushNotificationsDesc => isHebrew ? 'קבל התראות במכשיר שלך' : 'Receive alerts on your device';
  String get emailNotifications => isHebrew ? 'התראות אימייל' : 'Email Notifications';
  String get emailNotificationsDesc => isHebrew ? 'קבל עדכונים באימייל' : 'Get updates via email';
  String get dailySummary => isHebrew ? 'סיכום יומי' : 'Daily Summary';
  String get dailySummaryDesc => isHebrew ? 'תדרוך בוקר על המשימות שלך' : 'Morning briefing of your tasks';
  String get accountActions => isHebrew ? 'פעולות חשבון' : 'Account Actions';
  String get exportData => isHebrew ? 'ייצוא נתונים' : 'Export Data';
  String get exportDataDesc => isHebrew ? 'הורד דוח PDF/CSV' : 'Download PDF/CSV report';
  String get performance => isHebrew ? 'ביצועים' : 'Performance';

  // ── Chatbot ──
  String get chatbotTitle => isHebrew ? 'FocusFlow AI' : 'FocusFlow AI';
  String get chatbotSubtitle => isHebrew ? 'עוזר פרודוקטיביות' : 'Productivity assistant';
  String get chatbotWelcome => isHebrew
      ? 'היי! אני העוזר החכם של FocusFlow. אני יכול לעזור לך לנהל משימות, לשפר מיקוד ולענות על שאלות פרודוקטיביות.\n\nאיך אוכל לעזור לך היום?'
      : "Hi there! I'm your FocusFlow AI assistant. I can help you manage tasks, boost focus, and answer productivity questions.\n\nWhat can I help you with today?";
  String get chatbotHint => isHebrew ? 'שאל אותי כל דבר...' : 'Ask me anything...';
  String get chatbotClear => isHebrew ? 'נקה צ׳אט' : 'Clear chat';
  String get taskCreated => isHebrew ? 'משימה נוצרה' : 'TASK CREATED';
  String get suggestionPrioritize => isHebrew ? 'עזור לי לתעדף משימות' : 'Help me prioritize my tasks';
  String get suggestionCreate => isHebrew ? 'צור עבורי משימה' : 'Create a task for me';
  String get suggestionFocus => isHebrew ? 'על מה להתמקד היום?' : 'What should I focus on today?';
  String get suggestionTip => isHebrew ? 'תן לי טיפ פרודוקטיביות' : 'Give me a productivity tip';

  // ── Kanban ──
  String get kanbanBoard => isHebrew ? 'לוח קנבן' : 'Kanban Board';
  String get studyBoard => isHebrew ? 'לוח לימודים' : 'Study Board';
  String get workBoard => isHebrew ? 'לוח עבודה' : 'Work Board';
  String get projectsBoard => isHebrew ? 'לוח פרויקטים' : 'Projects Board';
  String get searchTasks => isHebrew ? 'חפש משימות...' : 'Search tasks...';
  String get filter => isHebrew ? 'סינון' : 'Filter';
  String get priority => isHebrew ? 'עדיפות' : 'Priority';
  String get toDo => isHebrew ? 'לביצוע' : 'To Do';
  String get inProgress => isHebrew ? 'בתהליך' : 'In Progress';
  String get done => isHebrew ? 'הושלם' : 'Done';
  String get deleteTask => isHebrew ? 'מחק משימה' : 'Delete Task';
  String get editTask => isHebrew ? 'ערוך משימה' : 'Edit Task';
  String get markAsDone => isHebrew ? 'סמן כהושלם' : 'Mark as Done';
  String get startFocusSession => isHebrew ? 'התחל סשן מיקוד' : 'Start Focus Session';
  String get failedToSaveStatus => isHebrew ? 'שמירת הסטטוס נכשלה' : 'Failed to save status';
  String get unableToLoadTasks => isHebrew ? 'לא ניתן לטעון משימות' : 'Unable to load tasks';

  // ── Calendar ──
  String get calendarTitle => isHebrew ? 'לוח שנה' : 'Calendar';
  String get noTasksForDay => isHebrew ? 'אין משימות ליום זה' : 'No tasks for this day';
  String get failedToDeleteTask => isHebrew ? 'מחיקת המשימה נכשלה' : 'Failed to delete task';
  String get failedToUpdateTask => isHebrew ? 'עדכון המשימה נכשל' : 'Failed to update task';
  String get failedToMoveTask => isHebrew ? 'העברת המשימה נכשלה' : 'Failed to move task';
  String get moveToAnotherDay => isHebrew ? 'העבר ליום אחר' : 'Move to Another Day';
  String get highPriority => isHebrew ? 'עדיפות גבוהה' : 'High Priority';
  String get focused => isHebrew ? 'ממוקד' : 'Focused';
  String get completed => isHebrew ? 'הושלם' : 'Completed';
  String tasksForDate(String date) => isHebrew ? 'משימות ל-$date' : 'Tasks for $date';
  String manageTask(String title) => isHebrew ? 'נהל "$title"' : "Manage '$title'";

  // ── Profile Screen ──
  String get myProfile => isHebrew ? 'הפרופיל שלי' : 'My Profile';
  String get manageYourAccount => isHebrew ? 'נהל את החשבון שלך' : 'Manage your account';
  String get couldNotLoadProfile => isHebrew ? 'לא ניתן לטעון את הפרופיל.' : 'Could not load profile.';
  String get profileSaved => isHebrew ? 'הפרופיל נשמר בהצלחה' : 'Profile saved successfully';
  String get failedToSaveProfile => isHebrew ? 'שמירה נכשלה' : 'Failed to save';
  String get editButton => isHebrew ? 'ערוך' : 'Edit';
  String get noEmail => isHebrew ? 'אין אימייל' : 'No email';
  String get quickStats => isHebrew ? 'סטטיסטיקות מהירות' : 'Quick Stats';
  String get goalsLabel => isHebrew ? 'יעדים' : 'Goals';
  String get focusStyleLabel => isHebrew ? 'סגנון מיקוד' : 'Focus Style';
  String get exportingDataSimulation => isHebrew ? 'מייצא נתונים ל-PDF... (סימולציה)' : 'Exporting data to PDF... (Simulation)';
  String get unknown => isHebrew ? 'לא ידוע' : 'Unknown';

  // ── Edit Profile Screen ──
  String get editProfile => isHebrew ? 'ערוך פרופיל' : 'Edit Profile';
  String get pleaseSelectUserType => isHebrew ? 'אנא בחר סוג משתמש' : 'Please select a user type';
  String get accountAndSecurity => isHebrew ? 'חשבון ואבטחה' : 'Account & Security';
  String get username => isHebrew ? 'שם משתמש' : 'Username';
  String get usernamePermanent => isHebrew ? 'שם המשתמש קבוע' : 'Username is permanent';
  String get usernameSetPermanent => isHebrew ? 'הגדר שם משתמש ייחודי (קבוע)' : 'Set your unique username (Permanent)';
  String get resetPasswordButton => isHebrew ? 'איפוס סיסמה' : 'Reset Password';
  String get iAmMainlyA => isHebrew ? 'אני בעיקר' : 'I am mainly a';
  String get myGoals => isHebrew ? 'היעדים שלי' : 'My goals';
  String get selectCategoryToExpand => isHebrew ? 'בחר קטגוריה להרחבה' : 'Select category to expand';
  String get focusStyleSection => isHebrew ? 'סגנון מיקוד' : 'Focus style';
  String get biggestStruggle => isHebrew ? 'האתגר הכי גדול' : 'Biggest struggle';
  String get bestTimeOfDayLabel => isHebrew ? 'הזמן הטוב ביום' : 'Best time of day';
  String get whatMotivatesYou => isHebrew ? 'מה מניע אותך' : 'What motivates you';
  String get themeStyle => isHebrew ? 'סגנון ערכת נושא' : 'Theme Style';
  String get themeStyleDesc => isHebrew ? "בחר 'מיקוד' או 'שלווה' לעקוף מצב רגיל." : "Select 'Focus' or 'Calm' to override standard mode.";
  String get baseAppearance => isHebrew ? 'מראה בסיסי' : 'Base Appearance';
  String get baseAppearanceDesc => isHebrew ? "חל כאשר סגנון הוא 'סטנדרטי'." : "Applies when Style is 'Standard'.";
  String get saveChanges => isHebrew ? 'שמור שינויים' : 'Save Changes';
  String passwordResetSentTo(String email) => isHebrew ? 'אימייל איפוס נשלח ל-$email' : 'Password reset email sent to $email';
  String get deleteAccountTitle => isHebrew ? 'מחק חשבון?' : 'Delete Account?';
  String get deleteAccountContent => isHebrew ? 'פעולה זו בלתי הפיכה. כל הנתונים, המשימות וההיסטוריה שלך ימחקו.\n\nאתה בטוח?' : 'This action is permanent. All your data, tasks, and history will be erased.\n\nAre you sure?';
  String get deletePermanently => isHebrew ? 'מחק לצמיתות' : 'Delete Permanently';
  String get deepFocus => isHebrew ? 'מיקוד עמוק' : 'Deep Focus';
  String get pomodoroLabel => isHebrew ? 'פומודורו' : 'Pomodoro';
  String get flexibleLabel => isHebrew ? 'גמיש' : 'Flexible';
  String get distractionsLabel => isHebrew ? 'הסחות דעת' : 'Distractions';
  String get procrastinationLabel => isHebrew ? 'דחיינות' : 'Procrastination';
  String get burnoutLabel => isHebrew ? 'שחיקה' : 'Burnout';
  String get morningLabel => isHebrew ? 'בוקר' : 'Morning';
  String get afternoonLabel => isHebrew ? 'צהריים' : 'Afternoon';
  String get nightLabel => isHebrew ? 'לילה' : 'Night';
  String get gradesLabel => isHebrew ? 'ציונים' : 'Grades';
  String get careerLabel => isHebrew ? 'קריירה' : 'Career';
  String get freedomLabel => isHebrew ? 'חופש' : 'Freedom';
  String get growthLabel => isHebrew ? 'צמיחה' : 'Growth';
  String get masteryLabel => isHebrew ? 'מומחיות' : 'Mastery';
  String get themeStandard => isHebrew ? 'סטנדרטי' : 'Standard';
  String get themeFocusDark => isHebrew ? 'מיקוד (כחול כהה)' : 'Focus (Dark Blue)';
  String get themeCalmBeige => isHebrew ? 'שלווה (בז׳ רך)' : 'Calm (Soft Beige)';
  String get appearanceSystem => isHebrew ? 'מערכת' : 'System';
  String get appearanceLight => isHebrew ? 'בהיר' : 'Light';
  String get appearanceDark => isHebrew ? 'כהה' : 'Dark';
  String get userTypeStudent => isHebrew ? 'סטודנט' : 'Student';
  String get userTypeEmployee => isHebrew ? 'עובד' : 'Employee';
  String get userTypeFreelancer => isHebrew ? 'עצמאי' : 'Freelancer';
  String get userTypeOther => isHebrew ? 'אחר' : 'Other';
  String get errorUpdatingUsername => isHebrew ? 'שגיאה בעדכון שם משתמש' : 'Error updating username';
  String get errorSavingProfile => isHebrew ? 'שגיאה בשמירה' : 'Error saving';
  String get deleteFailed => isHebrew ? 'מחיקה נכשלה' : 'Delete failed';

  // ── AI Planner Screen ──
  String get failedToGenerate => isHebrew ? 'יצירה נכשלה' : 'Failed to generate';
  String get failedToApplyPlan => isHebrew ? 'החלת התוכנית נכשלה' : 'Failed to apply plan';
  String get planSyncedSuccessfully => isHebrew ? 'התוכנית סונכרנה בהצלחה!' : 'Plan Synced Successfully!';
  String get planSyncedDesc => isHebrew ? 'המשימות עודכנו ונוספו ללוח השנה.' : 'Your tasks have been updated and added to the calendar.';
  String get viewInTaskList => isHebrew ? 'הצג ברשימת משימות' : 'View in Task List';
  String startFirstTask(String title) => isHebrew ? 'התחל משימה ראשונה: $title' : 'Start First Task: $title';
  String get smartPlanner => isHebrew ? 'מתכנן חכם' : 'Smart Planner';
  String get aiPowered => isHebrew ? 'מופעל על ידי AI' : 'AI-Powered';
  String get calendarSyncSettings => isHebrew ? 'הגדרות סנכרון לוח שנה' : 'Calendar Sync Settings';
  String get regenerate => isHebrew ? 'צור מחדש' : 'Regenerate';
  String get startTimeLabel => isHebrew ? 'שעת התחלה' : 'Start time';
  String durationMinutes(int m) => isHebrew ? 'משך: $m דקות' : 'Duration: $m min';
  String get generate => isHebrew ? 'צור' : 'Generate';
  String get focusCategoriesLabel => isHebrew ? 'קטגוריות מיקוד:' : 'Focus Categories:';
  String get readyToGenerate => isHebrew ? 'מוכן ליצור תוכנית.' : 'Ready to generate plan.';
  String get aiScheduleReady => isHebrew ? 'לוח זמנים מותאם AI מוכן.' : 'AI optimized schedule ready.';
  String plannedTimeLabel(int mins) => isHebrew ? 'זמן מתוכנן: $mins דקות' : 'Planned time: $mins min';
  String get noItemsReturned => isHebrew ? 'לא הוחזרו פריטים.' : 'No items returned.';
  String removedFromPlan(String title) => isHebrew ? '$title הוסר מהתוכנית' : 'Removed $title from plan';
  String get taskAcceptedAdded => isHebrew ? 'המשימה התקבלה ונוספה!' : 'Task accepted and added!';
  String get acceptPlan => isHebrew ? 'אשר תוכנית' : 'Accept Plan';
  String get acceptAndEdit => isHebrew ? 'אשר וערוך' : 'Accept & Edit';
  String get removeFromPlanLabel => isHebrew ? 'הסר מהתוכנית' : 'Remove from plan';
  String get scheduledLabel => isHebrew ? 'מתוזמן' : 'Scheduled';
  String get calendarIntegration => isHebrew ? 'אינטגרציה עם לוח שנה' : 'Calendar Integration';
  String get googleCalendar => isHebrew ? 'לוח שנה של Google' : 'Google Calendar';
  String get syncFromGoogle => isHebrew ? 'סנכרן אירועים מ-Google' : 'Sync events from Google';
  String get outlookCalendar => isHebrew ? 'לוח שנה של Outlook' : 'Outlook Calendar';
  String get syncFromOutlook => isHebrew ? 'סנכרן אירועים מ-Outlook' : 'Sync events from Outlook';
  String get saveAndRegenerate => isHebrew ? 'שמור וצור מחדש' : 'Save & Regenerate';
  String get settingsSavedRegenerating => isHebrew ? 'ההגדרות נשמרו. יוצר מחדש...' : 'Settings saved. Regenerating...';
  String minutesLabel(int m) => isHebrew ? '$m דקות' : '$m minutes';
  String workloadStatus(String status) => isHebrew ? 'עומס: ${status.toUpperCase()}' : 'Workload: ${status.toUpperCase()}';
  String tipLabel(String tip) => isHebrew ? 'טיפ: $tip' : 'Tip: $tip';

  // ── Analytics Screen ──
  String get yourAnalytics => isHebrew ? 'האנליטיקה שלך' : 'Your Analytics';
  String get trackYourProgress => isHebrew ? 'עקוב אחר ההתקדמות שלך' : 'Track Your Progress';
  String get checkingBurnoutRisk => isHebrew ? 'בודק סיכון שחיקה...' : 'Checking burnout risk...';
  String burnoutRiskLevel(String risk) => isHebrew ? 'שחיקה: ${risk[0].toUpperCase()}${risk.substring(1)} סיכון' : 'Burnout: ${risk[0].toUpperCase()}${risk.substring(1)} Risk';
  String get aiCoachReady => isHebrew ? 'מאמן ה-AI שלך מוכן לעזור.' : 'Your AI coach is ready to help.';
  String get coachLabel => isHebrew ? 'מאמן' : 'Coach';
  String get overviewLabel => isHebrew ? 'סקירה כללית' : 'Overview';
  String get focusLabel => isHebrew ? 'מיקוד' : 'Focus';
  String get totalTimeLabel => isHebrew ? 'זמן כולל' : 'Total time';
  String get keyMetricsLabel => isHebrew ? 'מדדים מרכזיים' : 'Key Metrics';
  String get todaysLoad => isHebrew ? 'עומס היום' : "Today's Load";
  String get understandYourLoad => isHebrew ? 'הבן את העומס שלך' : 'Understand Your Load';
  String get loadLightLabel => isHebrew ? 'קל' : 'Light';
  String get loadMediumLabel => isHebrew ? 'בינוני' : 'Medium';
  String get loadHighLabel => isHebrew ? 'כבד' : 'High';
  String get lightHoursRange => isHebrew ? '< 2 שעות' : '< 2 hours';
  String get mediumHoursRange => isHebrew ? '2 - 5 שעות' : '2 - 5 hours';
  String get highHoursRange => isHebrew ? '> 5 שעות' : '> 5 hours';
  String get lightLoadDesc => isHebrew ? 'יום נהדר לעסוק במשימות גדולות או לנוח.' : 'Great day to tackle huge tasks or rest.';
  String get mediumLoadDesc => isHebrew ? 'יום פרודוקטיבי ומוצלח.' : 'A solid, productive day.';
  String get highLoadDesc => isHebrew ? 'עומס כבד. שקול לדחות משימות.' : 'Heavy load. Consider postponing tasks.';
  String get lifeBalance => isHebrew ? 'איזון חיים' : 'Life Balance';
  String get focusTrendTitle => isHebrew ? 'מגמת מיקוד (7 ימים אחרונים)' : 'Focus Trend (Last 7 Days)';
  String get categoryPerformanceTitle => isHebrew ? 'ביצועים לפי קטגוריה' : 'Category Performance';
  String get advancedAnalytics => isHebrew ? 'אנליטיקה מתקדמת' : 'Advanced Analytics';
  String get todayFocusLabel => isHebrew ? 'מיקוד היום' : 'Today Focus';
  String get dailyAvgLabel => isHebrew ? 'ממוצע יומי' : 'Daily Avg';
  String get scoreLabel => isHebrew ? 'ציון' : 'Score';
  String get bestHourLabel => isHebrew ? 'שעה מיטבית' : 'Best Hour';
  String dayStreakLabel(int days) => isHebrew ? 'רצף $days ימים' : (days == 1 ? '1-day streak' : '$days-day streak');
  String get estimatedRemaining => isHebrew ? 'משוער נותר' : 'estimated remaining';
  String get tasksLabel => isHebrew ? 'משימות' : 'Tasks';

  // ── Focus Session Screen ──
  String get breakTime => isHebrew ? 'זמן הפסקה' : 'BREAK TIME';
  String get readyToStart => isHebrew ? 'מוכן להתחיל' : 'READY TO START';
  String get focusingStatus => isHebrew ? 'ממוקד' : 'FOCUSING';
  String get pausedStatus => isHebrew ? 'מושהה' : 'PAUSED';
  String get startBreak => isHebrew ? 'התחל הפסקה' : 'START BREAK';
  String get startFocus => isHebrew ? 'התחל מיקוד' : 'START FOCUS';
  String get enterDuration => isHebrew ? 'הזן משך (שש:דד)' : 'ENTER DURATION (HH:MM)';
  String get exitSession => isHebrew ? 'יציאה מסשן?' : 'Exit Session?';
  String get progressWillBeLost => isHebrew ? 'ההתקדמות תאבד.' : 'Progress will be lost.';
  String get exitButton => isHebrew ? 'יצא' : 'Exit';
  String get sessionComplete => isHebrew ? 'סשן הושלם' : 'Session Complete';
  String get breakComplete => isHebrew ? 'הפסקה הושלמה' : 'Break Complete';
  String get perfectFocus => isHebrew ? 'מיקוד מושלם!' : 'Perfect Focus!';
  String get greatJob => isHebrew ? 'עבודה נהדרת!' : 'Great Job!';
  String get goodEffort => isHebrew ? 'מאמץ טוב' : 'Good Effort';
  String get keepTrying => isHebrew ? 'המשך לנסות' : 'Keep Trying';
  String get efficiencyLabel => isHebrew ? 'יעילות' : 'Efficiency';
  String get takeABreak => isHebrew ? 'קח הפסקה' : 'Take a Break';
  String get doneButton => isHebrew ? 'סיום' : 'Done';
  String get plannedLabel => isHebrew ? 'מתוכנן' : 'Planned';
  String get focusedLabel => isHebrew ? 'ממוקד' : 'Focused';

  // ── Onboarding Screen ──
  String get setupProfile => isHebrew ? 'הגדרת פרופיל' : 'Setup Profile';
  String get pleaseChooseUserTypeGoal => isHebrew ? 'אנא בחר סוג משתמש ולפחות יעד אחד.' : 'Please choose user type and at least one goal.';
  String get pleaseFinishSetup => isHebrew ? 'אנא השלם את בחירות ההגדרה למטה.' : 'Please finish the quick setup choices below.';
  String welcomeName(String name) => isHebrew ? 'ברוך הבא, $name!' : 'Welcome, $name!';
  String get welcomeToFocusFlow => isHebrew ? 'ברוך הבא ל-FocusFlow!' : 'Welcome to FocusFlow!';
  String get iAmMostlyA => isHebrew ? 'אני בעיקר...' : 'I am mostly a...';
  String get myAreasOfFocus => isHebrew ? 'תחומי המיקוד שלי' : 'My areas of focus';
  String get selectCategoryOptions => isHebrew ? 'בחר קטגוריה לראות אפשרויות ספציפיות.' : 'Select a category to see specific options.';
  String get productivityPreferences => isHebrew ? 'העדפות פרודוקטיביות' : 'Productivity Preferences';
  String get focusStyleTitle => isHebrew ? 'סגנון מיקוד' : 'Focus Style';
  String get biggestStruggleTitle => isHebrew ? 'האתגר הכי גדול' : 'Biggest Struggle';
  String get bestTimeTitle => isHebrew ? 'הזמן הטוב ביותר' : 'Best Time';
  String get coreMotivation => isHebrew ? 'מוטיבציה מרכזית' : 'Core Motivation';
  String get appTheme => isHebrew ? 'ערכת נושא' : 'App Theme';
  String get startFocusFlowButton => isHebrew ? 'התחל FocusFlow' : 'Start FocusFlow';
  String get lightTheme => isHebrew ? 'בהיר' : 'Light';
  String get darkTheme => isHebrew ? 'כהה' : 'Dark';
  String get focusTheme => isHebrew ? 'מיקוד' : 'Focus';
  String get calmTheme => isHebrew ? 'שלווה' : 'Calm';

  // ── Add Task Screen ──
  String get createTask => isHebrew ? 'צור משימה' : 'Create Task';
  String get taskDetailsSection => isHebrew ? 'פרטי משימה' : 'Task Details';
  String get titleLabel => isHebrew ? 'כותרת' : 'Title';
  String get taskTitleHint => isHebrew ? 'מה צריך לעשות?' : 'What needs to be done?';
  String get descriptionLabel => isHebrew ? 'תיאור' : 'Description';
  String get taskDescHint => isHebrew ? 'הוסף פרטים...' : 'Add details...';
  String get categoryLabel => isHebrew ? 'קטגוריה' : 'Category';
  String get statusAndPriority => isHebrew ? 'סטטוס ועדיפות' : 'Status & Priority';
  String get recurrenceSection => isHebrew ? 'חזרה' : 'Recurrence';
  String get recurringTask => isHebrew ? 'משימה חוזרת' : 'Recurring Task';
  String get repeatLabel => isHebrew ? 'חזור' : 'Repeat';
  String get recurrenceDaily => isHebrew ? 'יומי' : 'Daily';
  String get recurrenceWeekly => isHebrew ? 'שבועי' : 'Weekly';
  String get recurrenceMonthly => isHebrew ? 'חודשי' : 'Monthly';
  String get intervalLabel => isHebrew ? 'מרווח' : 'Interval';
  String get timingReminders => isHebrew ? 'תזמון ותזכורות' : 'Timing & Reminders';
  String get estMinutesLabel => isHebrew ? 'דקות משוערות' : 'Est. Minutes';
  String get actualMinutesLabel => isHebrew ? 'דקות בפועל' : 'Actual Minutes';
  String get setDueDate => isHebrew ? 'הגדר תאריך יעד' : 'Set Due Date';
  String get setTimeLabel => isHebrew ? 'הגדר שעה' : 'Set Time';
  String get setReminder => isHebrew ? 'הגדר תזכורת' : 'Set Reminder';
  String get subtasksSection => isHebrew ? 'משימות משנה' : 'Subtasks';
  String get addSubtaskHint => isHebrew ? 'הוסף משימת משנה...' : 'Add a subtask...';
  String get noSubtasksYet => isHebrew ? 'אין משימות משנה עדיין' : 'No subtasks yet';
  String get errorSavingTask => isHebrew ? 'שגיאה בשמירת המשימה' : 'Error saving task';
  String get categoryGeneral => isHebrew ? 'כללי' : 'General';
  String get categoryWork => isHebrew ? 'עבודה' : 'Work';
  String get categoryPersonal => isHebrew ? 'אישי' : 'Personal';
  String get categoryStudy => isHebrew ? 'לימודים' : 'Study';
  String get categoryHealth => isHebrew ? 'בריאות' : 'Health';

  // ── Group Detail Screen ──
  String get groups => isHebrew ? 'קבוצות' : 'Groups';
  String get invite => isHebrew ? 'הזמן' : 'Invite';
  String get addMember => isHebrew ? 'הוסף חבר' : 'Add Member';
  String get inviteTitle => isHebrew ? 'הזמן חבר' : 'Invite Member';
  String get inviteSubtitle => isHebrew ? 'הזן את שם המשתמש המדויק כדי להזמין אותו לקבוצה' : 'Enter the exact username to invite them to the group';
  String get sendInviteButton => isHebrew ? 'שלח הזמנה' : 'Send Invite';
  String get totalTime => isHebrew ? 'זמן כולל' : 'Total Time';
  String get averageTime => isHebrew ? 'זמן ממוצע' : 'Average Time';
  String get sessionCount => isHebrew ? 'מספר סשנים' : 'Session Count';
  String get successRate => isHebrew ? 'שיעור הצלחה' : 'Success Rate';
  String get currentMembers => isHebrew ? 'חברים נוכחיים' : 'Current Members';
  String get chat => isHebrew ? "צ'אט" : 'Chat';
  String get members => isHebrew ? 'חברים' : 'Members';
  String get groupAnalytics => isHebrew ? 'ניתוח' : 'Analytics';
  String get leaveGroup => isHebrew ? 'עזוב את הקבוצה' : 'Leave Group';
  String get areYouSureLeave => isHebrew ? 'האם אתה בטוח שברצונך לעזוב את הקבוצה?' : 'Are you sure you want to leave the group?';
  String get leavingWillCauseDataLoss => isHebrew ? 'עזיבה תגרום לאיבוד נתונים שיתופיים.' : 'Leaving will cause loss of shared data.';
  String get yesLeave => isHebrew ? 'כן, עזוב' : 'Yes, Leave';
  String get noCancel => isHebrew ? 'לא, בטל' : 'No, Cancel';
  String get errorLeavingGroup => isHebrew ? 'שגיאה בעת עזיבת הקבוצה' : 'Error leaving group';
  String get inviteError => isHebrew ? 'שגיאה בהזמנת חבר' : 'Error inviting member';
  String get analyticsUnavailable => isHebrew ? 'ניתוח לא זמין' : 'Analytics unavailable';

  // ── Tasks Screen ──
  String get filterAll => isHebrew ? 'הכל' : 'All';
  String get manageLabel => isHebrew ? 'נהל' : 'Manage';
  String get myBoard => isHebrew ? 'הלוח שלי' : 'My Board';
  String workspaceOf(String type) => isHebrew ? 'סביבת עבודה של $type' : "$type's Workspace";
  String get aiPlannerLabel => isHebrew ? 'מתכנן AI' : 'AI Planner';
  String failedMoveTask(String e) => isHebrew ? 'שגיאה בהזזת משימה: $e' : 'Failed to move task: $e';
  String failedDeleteTask(String e) => isHebrew ? 'שגיאה במחיקת משימה: $e' : 'Failed to delete task: $e';

  // ── Reset Password Screen ──
  String get resetPasswordTitle => isHebrew ? 'איפוס סיסמה' : 'Reset Password';
  String get resetPasswordInstruction => isHebrew ? 'הכנס את האימייל שלך ונשלח לך קישור לאיפוס.' : "Enter your email and we'll send you a reset link.";
  String get resetEmailSentMessage => isHebrew ? 'אימייל איפוס נשלח. בדוק את תיבת הדואר שלך.' : 'Password reset email sent. Check your inbox.';
  String get failedToSendResetEmail => isHebrew ? 'שגיאה בשליחת אימייל האיפוס' : 'Failed to send reset email';
  String get sendResetEmail => isHebrew ? 'שלח אימייל איפוס' : 'Send reset email';

  // ── Reflection Screen ──
  String get dailyReflection => isHebrew ? 'רפלקציה יומית' : 'Daily Reflection';
  String get howWasYourDay => isHebrew ? 'איך היה יומך?' : 'How was your day?';
  String get moodSectionLabel => isHebrew ? 'מצב רוח' : 'Mood';
  String get whatWentWell => isHebrew ? 'מה הלך טוב היום?' : 'What went well today?';
  String get whatWentWellHint => isHebrew ? 'לדוגמה: סיימתי את המשימה הכי חשובה שלי.' : 'Example: I finished my most important task.';
  String get whatCouldImprove => isHebrew ? 'מה ניתן לשפר?' : 'What could be improved?';
  String get whatCouldImproveHint => isHebrew ? 'לדוגמה: פחות הסחות דעת אחר הצהריים.' : 'Example: Fewer distractions in the afternoon.';
  String get reflectionSaved => isHebrew ? 'רפלקציה נשמרה ✔' : 'Reflection saved ✔';
  String get saveReflection => isHebrew ? 'שמור רפלקציה' : 'Save Reflection';
  String get moodVeryLow => isHebrew ? 'מאוד נמוך 😞' : 'Very low 😞';
  String get moodLow => isHebrew ? 'נמוך 😕' : 'Low 😕';
  String get moodOkay => isHebrew ? 'בסדר 🙂' : 'Okay 🙂';
  String get moodGood => isHebrew ? 'טוב 😊' : 'Good 😊';
  String get moodGreat => isHebrew ? 'מצוין 😄' : 'Great 😄';

  // ── Study Together Screen ──
  String get studyGroups => isHebrew ? 'קבוצות לימוד' : 'Study Groups';
  String errorLoadingStudy(String e) => isHebrew ? 'שגיאה בטעינת נתוני לימוד: $e' : 'Error loading study data: $e';
  String get welcomeToGroupMessage => isHebrew ? 'ברוכים הבאים לקבוצה!' : 'Welcome to the group!';
  String get invitationDeclinedMessage => isHebrew ? 'ההזמנה נדחתה.' : 'Invitation declined.';
  String get createNewGroupTitle => isHebrew ? 'צור קבוצה חדשה' : 'Create New Group';
  String get groupNameInputLabel => isHebrew ? 'שם הקבוצה' : 'Group Name';
  String get groupNameHint => isHebrew ? 'לדוגמה: מתכנתי לילה' : 'e.g., Late Night Coders';
  String get descriptionOptionalLabel => isHebrew ? 'תיאור (אופציונלי)' : 'Description (Optional)';
  String get createButton => isHebrew ? 'צור' : 'Create';
  String get pendingInvitationsHeader => isHebrew ? 'הזמנות ממתינות' : 'Pending Invitations';
  String get myGroupsHeader => isHebrew ? 'הקבוצות שלי' : 'My Groups';
  String get createGroupTooltip => isHebrew ? 'צור קבוצה' : 'Create Group';
  String get noGroupsYetMessage => isHebrew ? 'אין קבוצות עדיין' : 'No groups yet';
  String get createOrWaitInvite => isHebrew ? 'צור אחת או המתן להזמנה!' : 'Create one or wait for an invite!';
  String get connectAndGrowLabel => isHebrew ? 'התחבר וצמח' : 'Connect & Grow';
  String get studyTogetherTagline => isHebrew ? 'הצטרף לקבוצות להגברת הפרודוקטיביות.' : 'Join groups to boost your productivity.';
  String invitationFromUser(String sender) => isHebrew ? 'הזמנה מ-$sender' : 'Invitation from $sender';
  String toJoinGroupLabel(String name) => isHebrew ? "להצטרף ל-'$name'" : "to join '$name'";
  String get declineButton => isHebrew ? 'דחה' : 'Decline';
  String get acceptButton => isHebrew ? 'קבל' : 'Accept';
  String get noDescriptionLabel => isHebrew ? 'אין תיאור' : 'No description';

  // ── Social Discovery Screen ──
  String get findStudyPartners => isHebrew ? 'מצא שותפים ללימוד' : 'Find Study Partners';
  String get searchByUsername => isHebrew ? 'חפש לפי שם משתמש...' : 'Search by username...';
  String get searchFailedMessage => isHebrew ? 'החיפוש נכשל' : 'Search failed';
  String get noUsersFound => isHebrew ? 'לא נמצאו משתמשים.' : 'No users found.';

  // ── Group Chat Screen ──
  String get groupChatSubtitle => isHebrew ? "צ'אט קבוצתי" : 'Group Chat';
  String get shareGoalTooltip => isHebrew ? 'שתף מטרה' : 'Share Goal';
  String get shareYourGoalTitle => isHebrew ? '🎯 שתף את המטרה שלך' : '🎯 Share Your Goal';
  String get shareGoalInstruction => isHebrew ? 'ספר לקבוצה מה אתה רוצה להשיג בסשן זה.' : 'Tell the group what you want to achieve in this session.';
  String get shareGoalHint => isHebrew ? 'לדוגמה: סיים פרק 3 בספר הלימוד' : 'e.g. Finish chapter 3 of the textbook';
  String get shareWithGroupButton => isHebrew ? 'שתף עם הקבוצה' : 'Share with Group';
  String get noMessagesYetMessage => isHebrew ? 'אין הודעות עדיין' : 'No messages yet';
  String get beFirstToSay => isHebrew ? 'היה הראשון לומר משהו!' : 'Be the first to say something!';
  String sharedAGoal(String name) => isHebrew ? '$name שיתף מטרה' : '$name shared a goal';
  String get messageGroupHint => isHebrew ? 'שלח הודעה לקבוצה...' : 'Message the group...';

  // ── Coach Screen ──
  String get aiCoachTitle => isHebrew ? 'מאמן AI' : 'AI Coach';
  String get analyzingProductivity => isHebrew ? 'מנתח את הפרודוקטיביות שלך...' : 'Analyzing your productivity...';
  String get couldNotLoadCoaching => isHebrew ? 'לא ניתן לטעון תובנת אימון' : 'Could not load coaching insight';
  String get yourWeekLabel => isHebrew ? 'השבוע שלך' : 'Your Week';
  String get keyInsightLabel => isHebrew ? 'תובנה מרכזית' : 'Key Insight';
  String get todaysActionLabel => isHebrew ? 'פעולת היום' : "Today's Action";
  String get chatWithAI => isHebrew ? "שוחח עם עוזר ה-AI" : 'Chat with AI Assistant';
  String get burnoutRiskHigh => isHebrew ? 'סיכון גבוה' : 'High Risk';
  String get burnoutRiskModerate => isHebrew ? 'בינוני' : 'Moderate';
  String get burnoutRiskLow => isHebrew ? 'סיכון נמוך' : 'Low Risk';
  String get burnoutManagingWell => isHebrew ? 'אתה מנהל את העומס שלך היטב.' : "You're managing your workload well.";
  String get burnoutWatchPace => isHebrew ? 'שים לב לקצב שלך — לחץ בינוני זוהה.' : 'Watch your pace — moderate stress detected.';
  String get burnoutTakeAction => isHebrew ? 'פעל עכשיו למניעת שחיקה מלאה.' : 'Take action now to prevent full burnout.';

  // ── Analytics Plus Screen ──
  String get dailyHeatmapLabel => isHebrew ? '4.1 מפת חום יומית' : '4.1 Daily Heatmap';
  String get weeklyProgressLabel => isHebrew ? '4.2 התקדמות שבועית' : '4.2 Weekly Progress';
  String get monthlyReportLabel => isHebrew ? '4.3 דוח חודשי' : '4.3 Monthly Report';
  String completedCount(int n) => isHebrew ? 'הושלמו: $n' : 'Completed: $n';
  String pendingCount(int n) => isHebrew ? 'ממתינות: $n' : 'Pending: $n';
  String get greatMonthMessage => isHebrew ? 'חודש מעולה! השלמת את רוב המשימות שלך 💪' : 'Great month! You completed most of your tasks 💪';
  String get challengingMonthMessage => isHebrew ? 'החודש היה מאתגר. נסה משימות קטנות יותר בחודש הבא.' : 'This month was challenging. Try smaller tasks next month.';

  // ── Focus Setup Screen ──
  String get getInTheZone => isHebrew ? 'כנס לאזור' : 'Get in the Zone';
  String get selectTaskToFocusOn => isHebrew ? 'בחר משימה להתמקד עליה' : 'Select Task to Focus On';
  String get tapToChangeTask => isHebrew ? 'לחץ לשינוי משימה' : 'Tap to change task';
  String get tapToSelectTask => isHebrew ? 'לחץ לבחירת משימה ספציפית' : 'Tap to select a specific task';
  String get startSessionChooseDuration => isHebrew ? 'התחל סשן לבחירת משך הזמן.' : 'Start session to choose duration.';
  String get startFocusLabel => isHebrew ? 'התחל מיקוד' : 'Start Focus';
  String focusedMinutesLabel(int m) => isHebrew ? 'ממוקד: $m דקות' : 'Focused: $m min';
  String get quickSession => isHebrew ? 'סשן מהיר' : 'Quick Session';

  // ── Group Detail Screen (extended) ──
  String get groupMembersLabel => isHebrew ? 'חברי הקבוצה' : 'GROUP MEMBERS';
  String inviteToGroupLabel(String name) => isHebrew ? "הכנס שם משתמש מדויק להזמנה ל-'$name'" : "Enter the exact username to invite them to '$name'";
  String get sendInvitation => isHebrew ? 'שלח הזמנה' : 'Send Invitation';
  String get invitationSent => isHebrew ? 'ההזמנה נשלחה!' : 'Invitation sent!';
  String get groupChatTooltip => isHebrew ? "צ'אט קבוצתי" : 'Group Chat';
  String get inviteMemberTooltip => isHebrew ? 'הזמן חבר' : 'Invite Member';
  String get sendAlertMenuItem => isHebrew ? 'שלח התראה' : 'Send Alert';
  String get leaveGroupMenuItem => isHebrew ? 'עזוב קבוצה' : 'Leave Group';
  String get deleteGroupMenuItem => isHebrew ? 'מחק קבוצה' : 'Delete Group';
  String get leaveGroupDialogTitle => isHebrew ? 'לעזוב קבוצה?' : 'Leave Group?';
  String get leaveGroupDialogContent => isHebrew ? 'האם אתה בטוח שברצונך לעזוב? תצטרך הזמנה כדי להצטרף מחדש.' : 'Are you sure you want to leave? You will need an invite to rejoin.';
  String get leaveButton => isHebrew ? 'עזוב' : 'Leave';
  String get youLeftGroup => isHebrew ? 'עזבת את הקבוצה' : 'You left the group';
  String get deleteGroupDialogTitle => isHebrew ? 'מחק קבוצה?' : 'Delete Group?';
  String get deleteGroupDialogContent => isHebrew ? 'לא ניתן לבטל פעולה זו. כל ההיסטוריה והנתונים יאבדו.' : 'This action cannot be undone. All history and data will be lost.';
  String get deleteButtonText => isHebrew ? 'מחק' : 'DELETE';
  String get groupDeletedMessage => isHebrew ? 'הקבוצה נמחקה' : 'Group deleted';
  String get groupAlertTitle => isHebrew ? '📣 התראת קבוצה' : '📣 Group Alert';
  String get groupAlertInstruction => isHebrew ? 'שלח עידוד מוטיבציוני לכל החברים.' : 'Send a motivational nudge to all members.';
  String get sendAlertButton => isHebrew ? 'שלח התראה' : 'Send Alert';
  String get alertSentToGroup => isHebrew ? 'ההתראה נשלחה לקבוצה!' : 'Alert sent to group!';
  String get editGroupDialogTitle => isHebrew ? 'ערוך קבוצה' : 'Edit Group';
  String get groupUpdatedMessage => isHebrew ? 'הקבוצה עודכנה!' : 'Group updated!';
  String get startSessionButton => isHebrew ? 'התחל סשן' : 'Start Session';
  String get totalFocusedLabel => isHebrew ? 'סה"כ מיקוד' : 'Total Focused';
  String get activeLearnersLabel => isHebrew ? 'לומדים פעילים' : 'Active Learners';
  String get viewDetailedAnalytics => isHebrew ? 'הצג ניתוח מפורט' : 'View Detailed Analytics';
  String get leaderboardLabel => isHebrew ? 'לוח מובילים' : 'LEADERBOARD';
  String get detailedAnalyticsTitle => isHebrew ? 'ניתוח מפורט' : 'Detailed Analytics';
  String get weeklyActivityLabel => isHebrew ? 'פעילות שבועית' : 'WEEKLY ACTIVITY';
  String get recentSessionsLabel => isHebrew ? 'סשנים אחרונים' : 'RECENT SESSIONS';
  String get noRecentSessionsYet => isHebrew ? 'אין סשנים אחרונים עדיין' : 'No recent sessions yet';
  String focusedForMinutes(int m) => isHebrew ? 'התמקד $m דקות' : 'Focused for $m min';
  String get studyingTogetherDefault => isHebrew ? 'לומדים יחד' : 'Studying together';
  String memberCountLabel(int n) => isHebrew ? '$n חברים' : '$n Members';
  String sinceDateLabel(String date) => isHebrew ? 'מאז $date' : 'Since $date';
  String get focusingBadge => isHebrew ? '🔥 מתמקד...' : '🔥 Focusing...';
  String joinedDateLabel(String date) => isHebrew ? 'הצטרף $date' : 'Joined $date';
  String get adminBadge => isHebrew ? 'מנהל' : 'ADMIN';

  // ── Private Chat Screen ──
  String get privateMessageSubtitle => isHebrew ? 'הודעה פרטית' : 'Private Message';
  String get startPrivateConversation => isHebrew ? 'התחל שיחה פרטית!' : 'Start a private conversation!';
  String get sendAMessage => isHebrew ? 'שלח הודעה...' : 'Send a message...';

  // ── Public Profile Screen ──
  String get focusedStatLabel => isHebrew ? 'מיקוד' : 'Focused';
  String get inviteToFocusGroup => isHebrew ? 'הזמן לקבוצת מיקוד' : 'Invite to Focus Group';
  String get invitesComingSoon => isHebrew ? 'הזמנות בקרוב!' : 'Invites coming soon!';

  // ── Minutes abbreviation ──
  String get minsAbbr => isHebrew ? 'ד׳' : 'm';

  // ── Date labels (card / calendar) ──
  String get noDate => isHebrew ? 'ללא תאריך' : 'No Date';
  String get todayLabel => isHebrew ? 'היום' : 'Today';
  String get tomorrowLabel => isHebrew ? 'מחר' : 'Tomorrow';
  String get yesterdayLabel => isHebrew ? 'אתמול' : 'Yesterday';
  String taskCount(int n) => isHebrew ? '$n משימות' : '$n Tasks';
  String deleteTaskConfirm(String title) =>
      isHebrew ? 'האם אתה בטוח שברצונך למחוק "$title"?' : 'Are you sure you want to delete "$title"?';

  // ── Kanban filter / sort UI ──
  String get filterTasksTitle => isHebrew ? 'סינון משימות' : 'Filter Tasks';
  String get categoryFilterLabel => isHebrew ? 'קטגוריה' : 'Category';
  String get priorityFilterLabel => isHebrew ? 'עדיפות' : 'Priority';
  String get dueDateFilterLabel => isHebrew ? 'תאריך יעד' : 'Due Date';
  String get applyFilters => isHebrew ? 'החל סינונים' : 'Apply Filters';
  String get clearLabel => isHebrew ? 'נקה' : 'Clear';
  String get sortPriority => isHebrew ? 'עדיפות' : 'Priority';
  String get sortDueDate => isHebrew ? 'תאריך יעד' : 'Due Date';
  String get sortCreated => isHebrew ? 'נוצר' : 'Created';
  String filterActiveCount(int n) => isHebrew ? 'סינונים ($n)' : 'Filters ($n)';

  // ── Priority display ──
  String get priorityHigh => isHebrew ? 'גבוהה' : 'High';
  String get priorityMedium => isHebrew ? 'בינונית' : 'Medium';
  String get priorityLow => isHebrew ? 'נמוכה' : 'Low';
  String get priorityHighAbbr => isHebrew ? "ג'" : 'HIGH';
  String get priorityMedAbbr => isHebrew ? "ב'" : 'MED';
  String get priorityLowAbbr => isHebrew ? "נ'" : 'LOW';

  // ── Due-date filter options ──
  String get dueTodayOption => isHebrew ? 'היום' : 'Today';
  String get dueThisWeekOption => isHebrew ? 'השבוע' : 'This Week';
  String get dueOverdueOption => isHebrew ? 'בפיגור' : 'Overdue';

  // ── Category: Finance (others reuse Add Task Screen keys) ──
  String get categoryFinance => isHebrew ? 'כספים' : 'Finance';

  // ── AI Insight strings ──
  String aiInsightManyTasks(int n) =>
      isHebrew ? 'יש לך $n משימות לא גמורות. תכנון היום שלך יכול להפחית עומס.' : 'You have $n unfinished tasks. Planning your day could reduce overload.';
  String aiInsightOverdue(int n) =>
      isHebrew ? 'דחית $n משימות. רוצה להדביק פיגור עם סשן מיקוד?' : 'You postponed $n task(s). Want to catch up with a focus session?';
  String aiInsightRemaining(int n) =>
      isHebrew ? 'יש לך $n משימות לביצוע. מוכן להתמקד?' : 'You have $n tasks to do. Ready to focus?';
  String get aiInsightHeavyWorkload =>
      isHebrew ? 'עומס העבודה שלך כבד היום. שקול להתחיל סשן מיקוד עכשיו.' : 'Your remaining workload is heavy today. Consider starting a focused session now.';
  String get aiInsightStudent =>
      isHebrew ? 'סטודנטים מתמקדים טוב בסשנים קצרים. נסה בלוק לימוד ממוקד עכשיו.' : 'Students often focus best in short sessions. Try a focused study block now.';
  String get aiInsightDoingWell =>
      isHebrew ? 'אתה עושה טוב. המשך לשמור על המומנטום.' : "You're doing well. Keep the momentum going.";

  // ── Performance Stats widget ──
  String get completionLabel => isHebrew ? 'השלמה' : 'Completion';
  String get tasksDoneLabel => isHebrew ? 'משימות שהושלמו' : 'Tasks Done';
  String get focusTimeLabel => isHebrew ? 'זמן מיקוד' : 'Focus Time';
  String get last7DaysLabel => isHebrew ? '7 ימים אחרונים' : 'Last 7 Days';
  String get weeklyActivityTitle => isHebrew ? 'פעילות שבועית' : 'Weekly Activity';
  List<String> get weekDayAbbrs => isHebrew
      ? ['ב', 'ג', 'ד', 'ה', 'ו', 'ש', 'א']
      : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // ── Member Profile Screen ──
  String get sessionsLabel => isHebrew ? 'סשנים' : 'Sessions';
  String get avgSessionLabel => isHebrew ? 'ממוצע סשן' : 'Avg Session';
  String get currentlyFocusing => isHebrew ? '🔥 ממוקד כרגע' : '🔥 Currently Focusing';
  String messageUser(String name) => isHebrew ? 'שלח הודעה ל-$name' : 'Message $name';

  // ── Goal primary categories (beyond task categories) ──
  String get goalProjects => isHebrew ? 'פרויקטים' : 'Projects';
  String get goalFreelance => isHebrew ? 'פרילנס' : 'Freelance';

  // ── Sub-goals ──
  String get subGoalExams => isHebrew ? 'מבחנים' : 'Exams';
  String get subGoalAssignments => isHebrew ? 'שיעורי בית' : 'Assignments';
  String get subGoalLectures => isHebrew ? 'הרצאות' : 'Lectures';
  String get subGoalReading => isHebrew ? 'קריאה' : 'Reading';
  String get subGoalMeetings => isHebrew ? 'פגישות' : 'Meetings';
  String get subGoalDeepWork => isHebrew ? 'עבודה עמוקה' : 'Deep Work';
  String get subGoalEmails => isHebrew ? 'אימיילים' : 'Emails';
  String get subGoalCoding => isHebrew ? 'קידוד' : 'Coding';
  String get subGoalGym => isHebrew ? 'חדר כושר' : 'Gym';
  String get subGoalWalking => isHebrew ? 'הליכה' : 'Walking';
  String get subGoalSleep => isHebrew ? 'שינה' : 'Sleep';
  String get subGoalNutrition => isHebrew ? 'תזונה' : 'Nutrition';
  String get subGoalFamily => isHebrew ? 'משפחה' : 'Family';
  String get subGoalHome => isHebrew ? 'בית' : 'Home';
  String get subGoalShopping => isHebrew ? 'קניות' : 'Shopping';
  String get subGoalSelfCare => isHebrew ? 'טיפוח עצמי' : 'Self-care';
  String get subGoalPlanning => isHebrew ? 'תכנון' : 'Planning';
  String get subGoalImplementation => isHebrew ? 'יישום' : 'Implementation';
  String get subGoalTesting => isHebrew ? 'בדיקות' : 'Testing';
  String get subGoalDelivery => isHebrew ? 'מסירה' : 'Delivery';
  String get subGoalClientWork => isHebrew ? 'עבודת לקוח' : 'Client Work';
  String get subGoalAdmin => isHebrew ? 'ניהול' : 'Admin';
  String get subGoalMarketing => isHebrew ? 'שיווק' : 'Marketing';
  String get subGoalLearning => isHebrew ? 'למידה' : 'Learning';

  // ── Focus Plant & Forest ──
  String get chooseYourPlant => isHebrew ? 'בחר את הצמח שלך' : 'CHOOSE YOUR PLANT';
  String get myForest => isHebrew ? 'היער שלי' : 'My Forest';
  String get emptyForest => isHebrew ? 'היער שלך ריק.\nהתחל סשן פוקוס כדי לגדל צמח!' : 'Your forest is empty.\nStart a focus session to grow a plant!';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'he'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
