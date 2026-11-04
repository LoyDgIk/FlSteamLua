// FlClash-styled application license browser.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'card.dart';
import 'localization.dart';
import 'loading.dart';
import 'scaffold.dart';
import 'typography.dart';

class AppLicensePage extends StatefulWidget {
  const AppLicensePage({super.key});

  @override
  State<AppLicensePage> createState() => _AppLicensePageState();
}

class _AppLicensePageState extends State<AppLicensePage> {
  late final Future<List<LicenseEntry>> _licenses = LicenseRegistry.licenses
      .toList();

  @override
  Widget build(BuildContext context) => CommonScaffold(
    title: context.l10n.openSourceLicenses,
    body: FutureBuilder<List<LicenseEntry>>(
      future: _licenses,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CommonCircleLoading.page());
        }
        final entries = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 88, 16, 24),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final text = entry.paragraphs
                .map((paragraph) => paragraph.text)
                .join('\n\n');
            return CommonCard(
              inert: true,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Text(
                  entry.packages.join(', '),
                  style: AppTextStyle.body.of(context),
                ),
                children: [
                  SelectableText(
                    text,
                    style: AppTextStyle.footnote.of(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
