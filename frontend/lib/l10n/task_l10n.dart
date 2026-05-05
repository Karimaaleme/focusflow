import 'app_localizations.dart';

class TaskL10n {
  static String status(String status, AppLocalizations l) {
    switch (status.toLowerCase()) {
      case 'todo': return l.toDo;
      case 'in_progress': return l.inProgress;
      case 'done': return l.done;
      default: return status;
    }
  }

  static String priority(String priority, AppLocalizations l) {
    switch (priority.toLowerCase()) {
      case 'high': return l.priorityHigh;
      case 'medium': return l.priorityMedium;
      case 'low': return l.priorityLow;
      default: return priority;
    }
  }

  static String priorityAbbr(String priority, AppLocalizations l) {
    switch (priority.toLowerCase()) {
      case 'high': return l.priorityHighAbbr;
      case 'medium': return l.priorityMedAbbr;
      case 'low': return l.priorityLowAbbr;
      default: return priority.toUpperCase();
    }
  }

  static String category(String category, AppLocalizations l) {
    switch (category.toLowerCase()) {
      case 'work': return l.categoryWork;
      case 'study': return l.categoryStudy;
      case 'personal': return l.categoryPersonal;
      case 'health': return l.categoryHealth;
      case 'finance': return l.categoryFinance;
      default: return l.categoryGeneral;
    }
  }

  static String dueFilter(String filter, AppLocalizations l) {
    switch (filter) {
      case '': return l.filterAll;
      case 'Today': return l.dueTodayOption;
      case 'This Week': return l.dueThisWeekOption;
      case 'Overdue': return l.dueOverdueOption;
      default: return filter;
    }
  }
}
