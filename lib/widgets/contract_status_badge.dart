import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../models/contract_model.dart';

class ContractStatusBadge extends StatelessWidget {
  const ContractStatusBadge({super.key, required this.status});

  final ContractStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.compactBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          status.displayName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color get _backgroundColor {
    return switch (status) {
      ContractStatus.editing => AppColors.neutralSection,
      ContractStatus.waitingAgreement => AppColors.sectionBackground,
      ContractStatus.active => AppColors.highlight,
    };
  }
}
