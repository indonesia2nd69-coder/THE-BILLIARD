import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TheBilliardApp());
}

class TheBilliardApp extends StatelessWidget {
  const TheBilliardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'THE BILLIARD',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Booking {
  final String id;
  final int table;
  final String customer;
  final String phone;
  final DateTime start;
  final DateTime? end;
  final double rate;

  Booking({
    required this.id,
    required this.table,
    required this.customer,
    required this.phone,
    required this.start,
    required this.end,
    required this.rate,
  });

  Booking copyWith({DateTime? end}) {
    return Booking(
      id: id,
      table: table,
      customer: customer,
      phone: phone,
      start: start,
      end: end,
      rate: rate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table': table,
      'customer': customer,
      'phone': phone,
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'rate': rate,
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      table: json['table'],
      customer: json['customer'] ?? '',
      phone: json['phone'] ?? '',
      start: DateTime.parse(json['start']),
      end: json['end'] == null ? null : DateTime.parse(json['end']),
      rate: (json['rate'] as num).toDouble(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int tableCount = 6;

  double hourlyRate = 200;
  List<Booking> bookings = [];
  Timer? timer;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadData();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString('bookings');
    final savedRate = prefs.getDouble('hourlyRate');

    if (saved != null) {
      final List data = jsonDecode(saved);
      bookings = data
          .map((e) => Booking.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (savedRate != null) {
      hourlyRate = savedRate;
    }

    if (mounted) setState(() {});
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'bookings',
      jsonEncode(bookings.map((e) => e.toJson()).toList()),
    );

    await prefs.setDouble('hourlyRate', hourlyRate);
  }

  Booking? activeBooking(int table) {
    for (final booking in bookings) {
      if (booking.table == table && booking.end == null) {
        return booking;
      }
    }
    return null;
  }

  double calculateBill(Booking booking) {
    final end = booking.end ?? DateTime.now();
    final minutes = end.difference(booking.start).inMinutes;

    if (minutes <= 0) return 0;

    final hours = (minutes / 60).ceil();
    return hours * booking.rate;
  }

  String durationText(Booking booking) {
    final end = booking.end ?? DateTime.now();
    final duration = end.difference(booking.start);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }

    return '${minutes}m ${seconds}s';
  }

  String timeText(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  Future<void> checkIn(int table) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Table $table Check-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('CHECK IN'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final booking = Booking(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      table: table,
      customer: nameController.text.trim(),
      phone: phoneController.text.trim(),
      start: DateTime.now(),
      end: null,
      rate: hourlyRate,
    );

    setState(() {
      bookings.add(booking);
    });

    await saveData();
  }

  Future<void> checkout(Booking booking) async {
    final end = DateTime.now();

    final finished = booking.copyWith(end: end);
    final bill = calculateBill(finished);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CHECKOUT'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${booking.customer}'),
              Text('Table: ${booking.table}'),
              Text('Duration: ${durationText(booking)}'),
              const SizedBox(height: 12),
              Text(
                'TOTAL: ৳${bill.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONFIRM CHECKOUT'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      final index = bookings.indexWhere((b) => b.id == booking.id);

      if (index != -1) {
        bookings[index] = finished;
      }
    });

    await saveData();
  }

  Future<void> changeRate() async {
    final controller = TextEditingController(
      text: hourlyRate.toStringAsFixed(0),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hourly Rate'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixText: '৳ ',
              labelText: 'Price per hour',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text);

                if (value != null && value > 0) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    setState(() {
      hourlyRate = result;
    });

    await saveData();
  }

  int get activeCount {
    return bookings.where((b) => b.end == null).length;
  }

  double get totalIncome {
    double total = 0;

    for (final booking in bookings) {
      if (booking.end != null) {
        total += calculateBill(booking);
      }
    }

    return total;
  }

  double get todayIncome {
    double total = 0;
    final now = DateTime.now();

    for (final booking in bookings) {
      if (booking.end != null &&
          booking.end!.year == now.year &&
          booking.end!.month == now.month &&
          booking.end!.day == now.day) {
        total += calculateBill(booking);
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'THE BILLIARD',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: selectedTab,
        children: [
          buildTablesPage(),
          buildHistoryPage(),
          buildSettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.table_bar),
            label: 'Tables',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget buildTablesPage() {
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: summaryCard(
                  'AVAILABLE',
                  '${tableCount - activeCount}',
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: summaryCard(
                  'RUNNING',
                  '$activeCount',
                  Icons.timer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: summaryCard(
                  'TODAY',
                  '৳${todayIncome.toStringAsFixed(0)}',
                  Icons.payments,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: summaryCard(
                  'RATE',
                  '৳${hourlyRate.toStringAsFixed(0)}/h',
                  Icons.attach_money,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'POOL TABLES',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          for (int table = 1; table <= tableCount; table++)
            buildTableCard(table),
        ],
      ),
    );
  }

  Widget summaryCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTableCard(int table) {
    final booking = activeBooking(table);
    final isRunning = booking != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  child: Text(
                    '$table',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TABLE $table',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isRunning ? 'RUNNING' : 'AVAILABLE',
                        style: TextStyle(
                          color: isRunning
                              ? Colors.orangeAccent
                              : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isRunning ? Icons.play_circle : Icons.check_circle,
                  color: isRunning
                      ? Colors.orangeAccent
                      : Colors.greenAccent,
                  size: 30,
                ),
              ],
            ),
            if (isRunning) ...[
              const Divider(height: 28),
              Row(
                children: [
                  const Icon(Icons.person),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.customer,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '৳${calculateBill(booking).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(durationText(booking)),
                  const Spacer(),
                  Text('Start ${timeText(booking.start)}'),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => checkout(booking),
                  icon: const Icon(Icons.logout),
                  label: const Text('CHECKOUT'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => checkIn(table),
                  icon: const Icon(Icons.login),
                  label: const Text('CHECK IN'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildHistoryPage() {
    final finished = bookings.where((b) => b.end != null).toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, size: 35),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL INCOME'),
                    Text(
                      '৳${totalIncome.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'BOOKING HISTORY',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (finished.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text('No completed bookings yet.'),
            ),
          ),
        for (final booking in finished)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${booking.table}'),
              ),
              title: Text(
                booking.customer,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Table ${booking.table}\n'
                '${timeText(booking.start)} → ${timeText(booking.end!)}\n'
                'Duration: ${durationText(booking)}',
              ),
              isThreeLine: true,
              trailing: Text(
                '৳${calculateBill(booking).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments),
            title: const Text('Hourly Rate'),
            subtitle: Text(
              '৳${hourlyRate.toStringAsFixed(0)} per hour',
            ),
            trailing: const Icon(Icons.edit),
            onTap: changeRate,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.table_bar),
            title: const Text('Pool Tables'),
            subtitle: const Text('6 tables'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Local Storage'),
            subtitle: const Text(
              'Bookings are saved on this device',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Text(
                  'THE BILLIARD',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Pool & Billiards Management'),
                const SizedBox(height: 12),
                Text(
                  'Default rate: ৳200 / hour',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
