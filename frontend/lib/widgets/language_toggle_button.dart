import 'package:flutter/material.dart';
import '../locale/locale_provider.dart';

class LanguageToggleButton extends StatelessWidget {
  final bool onGradient;

  const LanguageToggleButton({super.key, this.onGradient = false});

  static const _languages = [
    _LangOption(code: 'en', label: 'English', flag: '🇺🇸'),
    _LangOption(code: 'he', label: 'עברית',   flag: '🇮🇱'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor  = onGradient ? Colors.white : theme.colorScheme.primary;
    final bgColor    = onGradient
        ? Colors.white.withValues(alpha: 0.15)
        : theme.colorScheme.primary.withValues(alpha: 0.08);

    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleProvider.instance,
      builder: (context, locale, _) {
        final current = _languages.firstWhere(
          (l) => l.code == locale.languageCode,
          orElse: () => _languages.first,
        );

        return PopupMenuButton<String>(
          tooltip: 'Language',
          onSelected: (code) {
            if (code == 'he') {
              LocaleProvider.instance.switchToHebrew();
            } else {
              LocaleProvider.instance.switchToEnglish();
            }
          },
          itemBuilder: (_) => _languages
              .map((l) => PopupMenuItem<String>(
                    value: l.code,
                    child: Row(
                      children: [
                        Text(l.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text(
                          l.label,
                          style: TextStyle(
                            fontWeight: l.code == locale.languageCode
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (l.code == locale.languageCode) ...[
                          const Spacer(),
                          Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                  ))
              .toList(),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: onGradient
                    ? Colors.white.withValues(alpha: 0.4)
                    : theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current.flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  current.code.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, color: textColor, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LangOption {
  final String code;
  final String label;
  final String flag;
  const _LangOption({required this.code, required this.label, required this.flag});
}
