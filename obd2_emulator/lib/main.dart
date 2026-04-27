import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'emulator_engine.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ObdEmulatorEngine()),
      ],
      child: const ObdEmulatorApp(),
    ),
  );
}

class ObdEmulatorApp extends StatelessWidget {
  const ObdEmulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBD2 Emulator',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const EmulatorScreen(),
    );
  }
}

class EmulatorScreen extends StatefulWidget {
  const EmulatorScreen({super.key});

  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> {
  int _selectedIndex = 0;
  final TextEditingController _vinController = TextEditingController();
  final TextEditingController _dtcController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = Provider.of<ObdEmulatorEngine>(context, listen: false);
      _vinController.text = engine.vin;
    });
  }

  @override
  void dispose() {
    _vinController.dispose();
    _dtcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OBD2 BLE Emulator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<ObdEmulatorEngine>(
            builder: (context, engine, _) => Icon(
              engine.isAdvertising ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
              color: engine.isAdvertising ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildControlTab(),
          _buildPidValuesTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings_remote), label: 'Control'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'PID Values'),
        ],
      ),
    );
  }

  Widget _buildControlTab() {
    return Consumer<ObdEmulatorEngine>(
      builder: (context, engine, child) {
        return Column(
          children: [
            // Control Panel
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    engine.isAdvertising ? 'Advertising...' : 'Stopped',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: engine.isAdvertising ? Colors.green : Colors.red,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: engine.isAdvertising ? engine.stop : engine.start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: engine.isAdvertising ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(engine.isAdvertising ? 'STOP' : 'START'),
                  ),
                ],
              ),
            ),
            const Divider(),
            
            // Simulation Controls
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vehicle Identification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _vinController,
                      decoration: const InputDecoration(
                        labelText: 'VIN Number',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => engine.updateVin(val),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Sensor Simulation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildSlider(
                      icon: Icons.speed,
                      label: 'Speed: ${engine.speed} km/h',
                      value: engine.speed.toDouble(),
                      min: 0,
                      max: 255,
                      color: Colors.blue,
                      onChanged: (val) => engine.updateSpeed(val.toInt()),
                    ),
                    _buildSlider(
                      icon: Icons.settings,
                      label: 'Engine RPM: ${engine.rpm}',
                      value: engine.rpm.toDouble(),
                      min: 0,
                      max: 8000,
                      color: Colors.orange,
                      onChanged: (val) => engine.updateRpm(val.toInt()),
                    ),
                    _buildSlider(
                      icon: Icons.air,
                      label: 'MAF: ${engine.maf.toStringAsFixed(2)} g/s',
                      value: engine.maf,
                      min: 0,
                      max: 500,
                      color: Colors.cyan,
                      onChanged: (val) => engine.updateMaf(val),
                    ),
                    const SizedBox(height: 16),

                    const Text('DTC Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _dtcController,
                            decoration: const InputDecoration(
                              labelText: 'Add DTC (ex: P0101)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (_dtcController.text.isNotEmpty) {
                              engine.addStoredDtc(_dtcController.text.toUpperCase());
                              _dtcController.clear();
                            }
                          },
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: engine.storedDtcs.map((dtc) => Chip(
                        label: Text(dtc),
                        onDeleted: () => engine.removeStoredDtc(dtc),
                        deleteIconColor: Colors.red,
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            const Divider(),

            // Console Logs
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: engine.logs.length,
                  itemBuilder: (context, index) {
                    final log = engine.logs[index];
                    return Text(log, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 10));
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPidValuesTab() {
    return Consumer<ObdEmulatorEngine>(
      builder: (context, engine, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Current Simulated PID Values', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPidRow('09 02', 'VIN', engine.vin),
            _buildPidRow('01 0C', 'Engine RPM', '${engine.rpm} RPM'),
            _buildPidRow('01 0D', 'Vehicle Speed', '${engine.speed} km/h'),
            _buildPidRow('01 10', 'MAF Air Flow', '${engine.maf.toStringAsFixed(2)} g/s'),
            _buildPidRow('01 05', 'Coolant Temp', '90 °C (Fixed)'),
            _buildPidRow('03', 'Stored DTCs', engine.storedDtcs.isEmpty ? 'None' : engine.storedDtcs.join(', ')),
            _buildPidRow('07', 'Pending DTCs', engine.pendingDtcs.isEmpty ? 'None' : engine.pendingDtcs.join(', ')),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Note: All Mode 01 standard PIDs are acknowledged by the emulator.', 
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPidRow(String pid, String name, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Text(pid.split(' ').last, style: const TextStyle(fontSize: 10, color: Colors.white)),
        ),
        title: Text(name),
        subtitle: Text('PID: $pid'),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
      ),
    );
  }

  Widget _buildSlider({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
