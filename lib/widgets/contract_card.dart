import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../models/contract_model.dart';
import 'contract_status_badge.dart';

class ContractCard extends StatelessWidget {
  const ContractCard({
    super.key,
    required this.contract,
    required this.currentUserUid,
    this.onTap,
    this.onLongPress,
  });

  final ContractModel contract;
  final String currentUserUid;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isBorrower = contract.isBorrower(currentUserUid);
    final roleText = isBorrower ? '빌림' : '빌려줌';

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppDimensions.defaultBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.sectionBackground,
            borderRadius: BorderRadius.circular(
              AppDimensions.defaultBorderRadius,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      contract.otherPartyName(currentUserUid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.itemSpacing),
                  ContractStatusBadge(status: contract.status),
                ],
              ),
              const SizedBox(height: AppDimensions.itemSpacing),
              Text(
                '$roleText · ${formatWon(contract.totalRepaymentAmount)}',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatKoreanDate(contract.dueDate)}까지',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 정수 금액을 천 단위 구분 기호가 포함된 원화 문자열로 변환한다.
String formatWon(int amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = amount.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }

  return '$sign${buffer.toString()}원';
}

// 날짜를 사용자가 읽기 쉬운 한국어 형식으로 변환한다.
String formatKoreanDate(DateTime date) {
  final localDate = date.toLocal();
  return '${localDate.year}년 ${localDate.month}월 ${localDate.day}일';
}
