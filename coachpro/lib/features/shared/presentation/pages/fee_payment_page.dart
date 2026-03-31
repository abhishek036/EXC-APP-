import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class FeePaymentPage extends StatefulWidget {
  const FeePaymentPage({super.key});

  @override
  State<FeePaymentPage> createState() => _FeePaymentPageState();
}

class _FeePaymentPageState extends State<FeePaymentPage> {
  String _selectedMethod = 'UPI';

  @override
  Widget build(BuildContext context) {
    final primary = CT.textH(context);
    final borderColor = CT.border(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          'SECURE CHECKOUT',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.5,
            color: CT.textH(context),
          ),
        ),
        centerTitle: true,
        backgroundColor: CT.bg(context),
        elevation: 0,
        foregroundColor: CT.textH(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.pagePaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // NEO-BRUTALIST BILL CARD
                  Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: CT.success(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor,
                              offset: const Offset(5, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'INSTALLMENT #2',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    color: CT.elevated(context),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: CT.elevated(context),
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '₹12,500.00',
                              style: GoogleFonts.sora(
                                fontSize: 36,
                                color: CT.elevated(context),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    color: CT.elevated(context),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'DUE BY 15 AUG, 2026',
                                    style: GoogleFonts.sora(
                                      fontSize: 11,
                                      color: CT.elevated(context),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.05, end: 0),

                  const SizedBox(height: 40),

                  Text(
                    'SELECT GATEWAY',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CT.textH(context),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Methods
                  _buildPaymentOption(
                    'UPI',
                    'VPA / QR SCANNER',
                    Icons.qr_code_scanner,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    'CARD',
                    'CREDIT / DEBIT',
                    Icons.credit_card,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    'NET BANKING',
                    'INSTANT BANK TRANSFER',
                    Icons.account_balance,
                  ),

                  const SizedBox(height: 32),

                  // Dynamic Form Area
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedMethod == 'CARD'
                        ? Column(
                            key: const ValueKey('card'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARD INFORMATION',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: CT.textS(context),
                                ),
                              ).animate().fadeIn(),
                              const SizedBox(height: 16),
                              const CustomTextField(
                                label: 'CARD NUMBER',
                                hint: '•••• •••• •••• ••••',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Expanded(
                                    child: CustomTextField(
                                      label: 'EXPIRY',
                                      hint: 'MM/YY',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: CustomTextField(
                                      label: 'CVV',
                                      hint: '•••',
                                      obscureText: true,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : _selectedMethod == 'UPI'
                        ? Container(
                            key: const ValueKey('upi'),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: CT.card(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.05),
                                  offset: const Offset(4, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: CT.isDark(context)
                                        ? CT
                                              .elevated(context)
                                              .withValues(alpha: 0.05)
                                        : primary.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 120,
                                    color: CT.textH(context),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'SCAN OR ENTER ID',
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: CT.textS(context),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const CustomTextField(hint: 'id_handle@bank'),
                              ],
                            ),
                          ).animate().fadeIn().scaleXY(begin: 0.98)
                        : const SizedBox(height: 100),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),

          // Fixed Action Block
          Container(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            decoration: BoxDecoration(
              color: CT.bg(context),
              border: Border(
                top: BorderSide(color: CT.border(context), width: 1),
              ),
            ),
            child: SafeArea(
              child: CPPressable(
                onTap: () => HapticFeedback.heavyImpact(),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: borderColor, offset: const Offset(4, 4)),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security,
                          color: CT.elevated(context),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'PAY ₹12,500 SECURELY',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: CT.elevated(context),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 0.5, end: 0, delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String title, String subtitle, IconData icon) {
    final isSelected = _selectedMethod == title;
    final primary = CT.textH(context);
    final borderColor = CT.border(context);
    final accent = CT.accent(context);

    return CPPressable(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedMethod = title);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.1) : CT.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : borderColor,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: borderColor, offset: const Offset(3, 3))]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.2)
                    : primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? accent : CT.textS(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CT.textH(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CT.textM(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_box, color: accent, size: 24)
            else
              Icon(
                Icons.check_box_outline_blank,
                color: CT.textS(context).withValues(alpha: 0.2),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
