import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/utility_facade_service.dart';
import '../controllers/fac_detail_edit_controller.dart';
import '../layout/overlay_layout_store.dart';
import '../widgets/fac_detail_body.dart';

class UtilityFacDetailScreen extends StatelessWidget {
  final String facId;
  final UtilityFacadeService service;

  const UtilityFacDetailScreen({
    super.key,
    required this.facId,
    required this.service,
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
      ],
      child: FacDetailBody(facId: facId),
    );
  }
}
