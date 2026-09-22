import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/polling/polling_coordinator.dart';
import '../api/utility_facade_service.dart';
import '../controllers/fac_detail_edit_controller.dart';
import '../layout/overlay_layout_store.dart';
import '../widgets/fac_detail_body.dart';

class UtilityFacDetailScreen extends StatelessWidget {
  final String facId;
  final UtilityFacadeService service;
  final PollingCoordinator pollingCoordinator;

  const UtilityFacDetailScreen({
    super.key,
    required this.facId,
    required this.service,
    required this.pollingCoordinator,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            return OverlayGroupLayoutStore(service)..loadGroups(facId);
          },
        ),
        ChangeNotifierProvider(create: (_) => FacDetailEditController()),
        Provider<PollingCoordinator>.value(value: pollingCoordinator),
      ],
      child: FacDetailBody(facId: facId),
    );
  }
}
