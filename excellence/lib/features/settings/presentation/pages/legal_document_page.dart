import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';

class LegalDocumentTexts {
  static const String termsOfService = '''
Last updated: February 2026

1. Acceptance of Terms
By accessing or using the Excellence Academy application, you agree to these Terms of Service. If you do not agree, do not use the app.

2. Description of Service
Excellence Academy provides an educational coaching management platform that includes class management, attendance tracking, fee management, student performance analytics, and communication tools.

3. User Accounts
- You must provide accurate information during registration
- You are responsible for keeping your account credentials confidential
- You must notify us immediately of any unauthorized use
- One account per individual; account sharing is not permitted

4. Acceptable Use
You agree not to:
- Use the service for any unlawful purpose
- Interfere with or disrupt the service
- Attempt to gain unauthorized access to other accounts
- Share copyrighted study materials without permission

5. Intellectual Property
All content, features, and functionality are owned by Excellence Academy and protected by copyright, trademark, and other laws.

6. Fee Payments
- All fees are due according to the schedule set by your coaching institute
- Refund policies are determined by individual institutes
- Payment processing is handled through secure third-party providers

7. Privacy
Your use of Excellence Academy is also governed by our Privacy Policy.

8. Limitation of Liability
Excellence Academy is not liable for indirect, incidental, special, or consequential damages to the extent permitted by law.

9. Changes to Terms
We may modify these terms at any time. Continued use means you accept the updated terms.

10. Contact
For questions about these Terms, contact the institute support team.
''';

  static const String privacyPolicy = '''
Last updated: February 2026

1. Information We Collect
- Personal information: name, email, phone number, profile photo
- Academic data: attendance records, test scores, performance metrics
- Usage data: app usage patterns and feature interactions
- Device information: device type, OS version, and app version

2. How We Use Your Information
- To provide and maintain the Excellence Academy service
- To manage your account and provide customer support
- To send notifications about classes, tests, and fees
- To generate performance analytics and reports
- To improve our app and services

3. Data Sharing
We do not sell your personal information. We may share data with:
- Your coaching institute administrators and teachers
- Parents or guardians, for student accounts as configured
- Service providers who assist in app operations
- Legal authorities when required by law

4. Data Security
- All data is encrypted in transit and at rest
- We use industry-standard security measures
- Regular security audits are performed
- Access to user data is restricted to authorized personnel

5. Data Retention
- Account data is retained while your account is active
- You can request data deletion at any time
- Deleted data is permanently removed within 30 days
- Anonymized analytics data may be retained longer

6. Your Rights
You have the right to:
- Access your personal data
- Correct inaccurate data
- Delete your account and data
- Export your data
- Opt out of non-essential communications

7. Children's Privacy
Excellence Academy is designed for students of all ages. For users under 13, parental consent is required during registration.

8. Cookies and Tracking
The app uses minimal analytics to improve user experience. No third-party advertising trackers are used.

9. Changes to Policy
We will notify you of significant changes via in-app notification or email.

10. Contact
For privacy concerns, contact the institute support team.
''';
}

class LegalDocumentPage extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: CT.cardDecor(context),
          child: SelectionArea(
            child: Text(
              content,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.7,
                color: CT.textS(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}