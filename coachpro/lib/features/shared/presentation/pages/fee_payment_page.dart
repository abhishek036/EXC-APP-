import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/custom_button.dart';
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
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text('Pay Fees', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Summary Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 20)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Installment 2', style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('₹ 12,500.00', style: GoogleFonts.sora(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Due Date', style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white70)),
                    Text('15 Aug, 2026', style: GoogleFonts.sora(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
              
              const SizedBox(height: 32),
              
              Text('Payment Method', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(height: 16),
              
              // Payment Methods
              _buildPaymentOption('UPI', 'Google Pay, PhonePe, Paytm', Icons.qr_code_scanner),
              const SizedBox(height: 12),
              _buildPaymentOption('Card', 'Credit or Debit Card', Icons.credit_card),
              const SizedBox(height: 12),
              _buildPaymentOption('Net Banking', 'All major banks supported', Icons.account_balance),
              
              const SizedBox(height: 32),
              
              // Conditional Form logic based on selected method
              if (_selectedMethod == 'Card') ...[
                Text('Card Details', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)).animate().fadeIn(),
                const SizedBox(height: 16),
                const CustomTextField(label: 'Card Number', hint: '0000 0000 0000 0000', keyboardType: TextInputType.number).animate().fadeIn().slideY(begin: 0.05),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: const CustomTextField(label: 'Expiry', hint: 'MM/YY').animate().fadeIn().slideY(begin: 0.05)),
                  const SizedBox(width: 16),
                  Expanded(child: const CustomTextField(label: 'CVV', hint: '123', obscureText: true, keyboardType: TextInputType.number).animate().fadeIn().slideY(begin: 0.05)),
                ]),
              ] else if (_selectedMethod == 'UPI') ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: CT.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: CT.textM(context))),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.qr_code, size: 100, color: CT.textH(context)),
                        const SizedBox(height: 16),
                        Text('Scan with any UPI app to pay', style: GoogleFonts.dmSans(fontSize: 14, color: CT.textS(context))),
                        const SizedBox(height: 24),
                        const CustomTextField(hint: 'Or enter UPI ID (e.g. name@okhdfcbank)'),
                      ],
                    ),
                  ),
                ).animate().fadeIn().scaleXY(begin: 0.95),
              ],
              
              const SizedBox(height: 48), // Padding for scroll bottom
            ]),
          ),
        ),
        
        // Fixed Bottom Pay Now button
        Container(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
          decoration: BoxDecoration(color: CT.card(context), boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, -4))]),
          child: CustomButton(
            text: 'Pay ₹12,500 securely',
            icon: Icons.lock_outline,
            onPressed: () {},
          ),
        ),
      ]),
    );
  }

  Widget _buildPaymentOption(String title, String subtitle, IconData icon) {
    final isSelected = _selectedMethod == title;
    
    return CPPressable(
      onTap: () => setState(() => _selectedMethod = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : CT.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : CT.textM(context), width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: isSelected ? AppColors.primary : CT.textS(context), size: 28),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: CT.textH(context))),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.dmSans(fontSize: 13, color: CT.textM(context))),
          ])),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppColors.primary)
          else
            Icon(Icons.circle_outlined, color: CT.textM(context)),
        ]),
      ).animate(target: isSelected ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.02, 1.02), curve: Curves.easeOut),
    );
  }
}
