import 'package:flutter/material.dart';

import 'penkrowd_card.dart';

class DetailHeaderCard extends StatelessWidget {
  const DetailHeaderCard({
    super.key,
    required this.title,
    this.subtitle,
    this.statusChip,
    this.avatarUrl,
    this.fallbackLetter = '?',
    this.accentColor,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? statusChip;
  final String? avatarUrl;
  final String fallbackLetter;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PenkrowdCard(
      onTap: onTap,
      accentColor: accentColor,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty) ? NetworkImage(avatarUrl!) : null,
        child: (avatarUrl == null || avatarUrl!.isEmpty)
            ? Text(
                fallbackLetter.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
              )
            : null,
      ),
      title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
      subtitle: (subtitle == null || subtitle!.trim().isEmpty)
          ? null
          : Text(subtitle!.trim(), overflow: TextOverflow.ellipsis, maxLines: 2),
      trailing: statusChip,
    );
  }
}

