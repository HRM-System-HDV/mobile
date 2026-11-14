import 'package:flutter/material.dart';
import 'api_client.dart';

/// Keep stale list data out of detail views and surface 403/404/network errors.
Future<T?> loadApiDetail<T>(BuildContext context, Future<T> Function() load) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
          SizedBox(width: 16),
          Text('Đang tải chi tiết...'),
        ]),
      ),
    ),
  );
  navigator.push(route);
  try {
    return await load();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is ApiException ? error.message : 'Không tải được chi tiết. Vui lòng thử lại.'),
      ));
    }
    return null;
  } finally {
    if (navigator.mounted && route.isActive) navigator.removeRoute(route);
  }
}
