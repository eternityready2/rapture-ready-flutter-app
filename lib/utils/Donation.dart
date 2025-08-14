import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../global/Constants.dart';

Future<bool> openDonation(String url) async {
  if (DONATION_URLS.any((donationUrl) => url.contains(donationUrl))) {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  }
  return false;
}
