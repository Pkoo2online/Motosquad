import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rider.dart';
import '../providers/convoy_provider.dart';
import 'convoy_map_screen.dart';

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Alex Rider');
  final _callsignCtrl = TextEditingController(text: 'Viper-1');
  final _convoyCtrl = TextEditingController(text: 'RIDERS101');
  final _serverCtrl = TextEditingController(text: 'https://smart-panther-35.loca.lt');
  RiderRole _selectedRole = RiderRole.leader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101216),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.two_wheeler, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('MOTOSQUAD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join or Start Convoy',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect live GPS, walkie-talkie intercom, and separation alerts with your riding group.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Rider Name
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1B1E26),
                  prefixIcon: const Icon(Icons.person, color: Colors.orangeAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 16),

              // Callsign
              TextFormField(
                controller: _callsignCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Convoy Callsign (Radio Handle)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1B1E26),
                  prefixIcon: const Icon(Icons.badge, color: Colors.orangeAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Convoy Code
              TextFormField(
                controller: _convoyCtrl,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Convoy Code / Room',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1B1E26),
                  prefixIcon: const Icon(Icons.tag, color: Colors.orangeAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter convoy code' : null,
              ),
              const SizedBox(height: 20),

              // Role selector
              const Text(
                'Select Convoy Role',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1E26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RiderRole>(
                    value: _selectedRole,
                    dropdownColor: const Color(0xFF1B1E26),
                    isExpanded: true,
                    items: RiderRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          role.displayName,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (newRole) {
                      if (newRole != null) setState(() => _selectedRole = newRole);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Server URL
              TextFormField(
                controller: _serverCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Convoy Server URL',
                  hintText: 'e.g. https://... or Wi-Fi IP',
                  helperText: 'Public tunnel or Wi-Fi IP to link friends together',
                  helperStyle: const TextStyle(color: Colors.white38),
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1B1E26),
                  prefixIcon: const Icon(Icons.dns_outlined, color: Colors.cyanAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      Provider.of<ConvoyProvider>(context, listen: false).initializeRider(
                        name: _nameCtrl.text.trim(),
                        callsign: _callsignCtrl.text.trim(),
                        role: _selectedRole,
                        convoyCode: _convoyCtrl.text.trim(),
                        serverUrl: _serverCtrl.text.trim(),
                      );

                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const ConvoyMapScreen()),
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.directions_bike),
                      SizedBox(width: 10),
                      Text(
                        'START RIDING TOGETHER',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
