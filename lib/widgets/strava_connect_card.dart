import 'package:flutter/material.dart';

import 'package:pltuapp/helpers/strava_helper.dart';

const Color stravaOrange = Color(0xFFFC4C02);

class StravaConnectCard extends StatelessWidget {
  final StravaStatus? status;
  final bool isBusy;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const StravaConnectCard({
    Key? key,
    required this.status,
    this.isBusy = false,
    this.onConnect,
    this.onDisconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connected = status?.connected == true;
    final configured = status?.configured != false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: stravaOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_run, color: stravaOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Strava', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      !configured
                          ? 'Integrasi belum dikonfigurasi'
                          : connected
                              ? (status?.athleteName != null ? 'Terhubung sebagai ${status!.athleteName}' : 'Akun sudah terhubung')
                              : 'Hubungkan akun untuk memilih aktivitas',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: connected
                ? OutlinedButton(
                    onPressed: isBusy ? null : onDisconnect,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Putuskan Strava', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                  )
                : ElevatedButton(
                    onPressed: !configured || isBusy ? null : onConnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: stravaOrange,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Hubungkan dengan Strava', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
    );
  }
}
